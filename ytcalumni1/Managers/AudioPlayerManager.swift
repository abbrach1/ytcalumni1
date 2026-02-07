import Foundation
import AVFoundation
import Combine
import MediaPlayer
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AudioPlayerManager: ObservableObject {
    @Published var currentShiur: Shiur?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var playbackSpeed: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var error: String?
    
    private var player: AVPlayer?
    private var playerItemObserver: AnyCancellable?
    private var timeObserver: Any?
    private var playedShiurimIds: Set<String> = []
    
    let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    func play(shiur: Shiur) async {
        guard let audioUrlString = shiur.audioUrl,
              let audioUrl = URL(string: processAudioUrl(audioUrlString)) else {
            error = "Invalid audio URL"
            return
        }
        
        // Stop current playback
        stop()
        
        currentShiur = shiur
        isLoading = true
        error = nil
        
        let playerItem = AVPlayerItem(url: audioUrl)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        player?.rate = playbackSpeed
        
        // Observe duration
        playerItemObserver = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.duration = playerItem.duration.seconds.isNaN ? 0 : playerItem.duration.seconds
                    self?.isLoading = false
                    self?.restorePlaybackPosition(for: shiur)
                    self?.player?.play()
                    self?.isPlaying = true
                    self?.updateNowPlayingInfo()
                    
                    // Track play count
                    if let id = shiur.id, !(self?.playedShiurimIds.contains(id) ?? true) {
                        self?.playedShiurimIds.insert(id)
                        Task {
                            try? await FirebaseService.shared.incrementPlayCount(shiurId: id)
                        }
                    }
                } else if status == .failed {
                    self?.error = "Failed to load audio"
                    self?.isLoading = false
                }
            }
        
        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds.isNaN ? 0 : time.seconds
            self?.savePlaybackPosition()
            self?.updateNowPlayingInfo()
        }
        
        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.currentTime = 0
            self?.clearPlaybackPosition()
        }
    }
    
    func play() {
        player?.play()
        player?.rate = playbackSpeed
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        player?.pause()
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player = nil
        playerItemObserver = nil
        timeObserver = nil
        currentShiur = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        currentTime = time
    }
    
    func skipForward(seconds: TimeInterval = 15) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }
    
    // MARK: - Playback Position Persistence (Firebase synced)
    // Website structure: /users/{uid}/preferences/playbackPositions
    // { positions: { "shiur_001": 245, "shiur_042": 1820 }, lastUpdated, syncedAt }
    
    private func savePlaybackPosition() {
        guard let shiur = currentShiur, let id = shiur.id else { return }
        
        // Save locally for immediate access
        UserDefaults.standard.set(currentTime, forKey: "playback_position_\(id)")
        
        // Save to Firebase for cross-device sync (matches website structure)
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let docRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("preferences")
            .document("playbackPositions")
        
        // First check if document exists, then update or create
        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            let now = Date().timeIntervalSince1970 * 1000 // milliseconds like website
            
            if let snapshot = snapshot, snapshot.exists {
                // Document exists - use updateData with dot notation for nested field
                docRef.updateData([
                    "positions.\(id)": self.currentTime,
                    "lastUpdated": now,
                    "syncedAt": now
                ]) { error in
                    if let error = error {
                        print("❌ Error updating playback position: \(error)")
                    } else {
                        print("✅ Updated playback position for \(id): \(self.currentTime)s")
                    }
                }
            } else {
                // Document doesn't exist - create it with setData
                docRef.setData([
                    "positions": [id: self.currentTime],
                    "lastUpdated": now,
                    "syncedAt": now
                ]) { error in
                    if let error = error {
                        print("❌ Error creating playback positions doc: \(error)")
                    } else {
                        print("✅ Created playback positions doc with \(id): \(self.currentTime)s")
                    }
                }
            }
        }
    }
    
    private func restorePlaybackPosition(for shiur: Shiur) {
        guard let id = shiur.id else { return }
        
        // First try local storage for quick access
        let localPosition = UserDefaults.standard.double(forKey: "playback_position_\(id)")
        
        // Then check Firebase for synced position
        guard let userId = Auth.auth().currentUser?.uid else {
            if localPosition > 0 && localPosition < duration - 5 {
                seek(to: localPosition)
            }
            return
        }
        
        Task {
            do {
                let doc = try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .collection("preferences")
                    .document("playbackPositions")
                    .getDocument()
                
                if let data = doc.data(),
                   let positions = data["positions"] as? [String: Any],
                   let position = positions[id] as? Double {
                    // Use Firebase position
                    if position > 0 && position < duration - 5 {
                        await MainActor.run {
                            seek(to: position)
                        }
                    }
                } else if localPosition > 0 && localPosition < duration - 5 {
                    // Fall back to local position
                    await MainActor.run {
                        seek(to: localPosition)
                    }
                }
            } catch {
                // Fall back to local position on error
                if localPosition > 0 && localPosition < duration - 5 {
                    await MainActor.run {
                        seek(to: localPosition)
                    }
                }
            }
        }
    }
    
    private func clearPlaybackPosition() {
        guard let shiur = currentShiur, let id = shiur.id else { return }
        
        // Clear local
        UserDefaults.standard.removeObject(forKey: "playback_position_\(id)")
        
        // Clear from Firebase (remove from positions map)
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let docRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("preferences")
            .document("playbackPositions")
        
        docRef.updateData([
            "positions.\(id)": FieldValue.delete(),
            "lastUpdated": Date().timeIntervalSince1970 * 1000,
            "syncedAt": Date().timeIntervalSince1970 * 1000
        ]) { error in
            if let error = error {
                print("❌ Error clearing playback position: \(error)")
            } else {
                print("✅ Cleared playback position for \(id)")
            }
        }
    }
    
    /// Get saved playback position for a shiur (checks both local and Firebase)
    func getSavedPosition(for shiurId: String) -> TimeInterval {
        // Return local position for immediate UI updates
        // Firebase position will be loaded when actually playing
        return UserDefaults.standard.double(forKey: "playback_position_\(shiurId)")
    }
    
    /// Fetch saved position from Firebase (async)
    func fetchSavedPosition(for shiurId: String) async -> TimeInterval {
        guard let userId = Auth.auth().currentUser?.uid else {
            return UserDefaults.standard.double(forKey: "playback_position_\(shiurId)")
        }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("preferences")
                .document("playbackPositions")
                .getDocument()
            
            if let data = doc.data(),
               let positions = data["positions"] as? [String: Any],
               let position = positions[shiurId] as? Double {
                // Update local cache
                UserDefaults.standard.set(position, forKey: "playback_position_\(shiurId)")
                return position
            }
        } catch {
            print("Error fetching playback position: \(error)")
        }
        
        return UserDefaults.standard.double(forKey: "playback_position_\(shiurId)")
    }
    
    /// Fetch all playback positions from Firebase (for syncing on app load)
    func fetchAllPlaybackPositions() async -> [String: Double] {
        guard let userId = Auth.auth().currentUser?.uid else { return [:] }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("preferences")
                .document("playbackPositions")
                .getDocument()
            
            if let data = doc.data(),
               let positions = data["positions"] as? [String: Any] {
                var result: [String: Double] = [:]
                for (key, value) in positions {
                    if let position = value as? Double {
                        result[key] = position
                        // Update local cache
                        UserDefaults.standard.set(position, forKey: "playback_position_\(key)")
                    }
                }
                print("✅ Synced \(result.count) playback positions from Firebase")
                return result
            }
        } catch {
            print("Error fetching all playback positions: \(error)")
        }
        
        return [:]
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let shiur = currentShiur else { return }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: shiur.title,
            MPMediaItemPropertyArtist: shiur.rebbe,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0
        ]
        
        // Add artwork if available
        if let image = UIImage(named: "yeshiva-logo") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - URL Processing
    private func processAudioUrl(_ url: String) -> String {
        // Handle Google Drive URLs
        if url.contains("drive.google.com") {
            if let fileId = extractGoogleDriveFileId(from: url) {
                return "https://drive.google.com/uc?export=download&id=\(fileId)"
            }
        }
        return url
    }
    
    private func extractGoogleDriveFileId(from url: String) -> String? {
        // Pattern: /file/d/{fileId}
        if let range = url.range(of: "/file/d/") {
            let startIndex = range.upperBound
            let remaining = url[startIndex...]
            if let endIndex = remaining.firstIndex(of: "/") {
                return String(remaining[..<endIndex])
            }
            return String(remaining)
        }
        
        // Pattern: ?id={fileId}
        if let range = url.range(of: "id=") {
            let startIndex = range.upperBound
            let remaining = url[startIndex...]
            if let endIndex = remaining.firstIndex(of: "&") {
                return String(remaining[..<endIndex])
            }
            return String(remaining)
        }
        
        return nil
    }
    
    // MARK: - Helper
    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
