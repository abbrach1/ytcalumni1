import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit
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

    /// Seconds left on the sleep timer, or nil when no timer is running.
    /// `endOfShiur` mode is encoded as nil here and surfaced via
    /// `sleepTimerMode` so the FullPlayer can show the right label.
    @Published var sleepTimerRemaining: TimeInterval?
    @Published var sleepTimerMode: SleepTimerMode = .off

    enum SleepTimerMode: Equatable {
        case off
        case minutes(Int)
        case endOfShiur
    }

    private var player: AVPlayer?
    private var playerItemObserver: AnyCancellable?
    private var timeObserver: Any?
    private var endOfTrackObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var sleepTimer: Timer?
    private var playedShiurimIds: Set<String> = []

    // Firestore write throttling for playback position sync
    private var lastFirestoreSync: Date?
    private var positionsDocExists: Bool?
    private let firestoreSyncInterval: TimeInterval = 10

    // Position-save gating. We must NOT persist a position until the saved
    // position has been restored (otherwise the first ~0s tick clobbers the
    // saved cloud/local value), and we must stop saving once a track has
    // finished (otherwise a straggler tick resurrects the cleared position).
    private var hasRestored = false
    private var playbackEnded = false

    // Whether playback was active when an audio-session interruption began, so
    // we only auto-resume on .ended if the user hadn't manually paused.
    private var wasPlayingBeforeInterruption = false

    // Stored remote-command targets so they can be removed in deinit.
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

    let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupInterruptionHandling()
        setupRouteChangeHandling()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = endOfTrackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        sleepTimer?.invalidate()
        // Mirror stop()'s player teardown so the periodic time observer is
        // removed per AVFoundation's contract and the player/Combine sink are
        // released deterministically. Do NOT call stop() here — it kicks off
        // async Firestore work capturing a deallocating self.
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        playerItemObserver = nil
        player?.pause()
        player = nil
        for (command, token) in remoteCommandTargets {
            command.removeTarget(token)
        }
    }

    private func setupAudioSession() {
        // Set the category at launch but DON'T activate yet — activating a
        // non-mixable .playback session would preempt other apps' audio before
        // the user even plays anything. We activate on demand in play().
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Each handler no-ops (returning .noSuchContent) when no media is
        // loaded, so an idle instance hands the event back to the system
        // instead of swallowing it.
        let playToken = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.play()
            return .success
        }
        remoteCommandTargets.append((commandCenter.playCommand, playToken))

        let pauseToken = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.pause()
            return .success
        }
        remoteCommandTargets.append((commandCenter.pauseCommand, pauseToken))

        commandCenter.skipForwardCommand.preferredIntervals = [15]
        let skipFwdToken = commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.skipForward()
            return .success
        }
        remoteCommandTargets.append((commandCenter.skipForwardCommand, skipFwdToken))

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        let skipBackToken = commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.skipBackward()
            return .success
        }
        remoteCommandTargets.append((commandCenter.skipBackwardCommand, skipBackToken))

        let posToken = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, self.player != nil,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
        remoteCommandTargets.append((commandCenter.changePlaybackPositionCommand, posToken))
    }

    func play(shiur: Shiur) async {
        // Prefer the on-disk copy when the shiur has been downloaded — this
        // also keeps playback working with no network.
        let resolvedUrl: URL? = {
            if let id = shiur.id, let local = DownloadManager.shared.localURL(for: id) {
                return local
            }
            if let audioUrlString = shiur.audioUrl {
                return URL(string: processAudioUrl(audioUrlString))
            }
            return nil
        }()

        guard let audioUrl = resolvedUrl else {
            error = "Invalid audio URL"
            return
        }

        // Stop current playback (flushes the previous shiur's position first).
        stop()
        // stop() resets hasRestored/playbackEnded; activate the session now that
        // we're about to play.
        activateSession()

        currentShiur = shiur
        isLoading = true
        error = nil

        let playerItem = AVPlayerItem(url: audioUrl)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume

        // Observe status. We restore the saved position and only THEN start
        // playback, so the listener never hears a moment of audio from 0:00
        // before the seek lands.
        playerItemObserver = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .readyToPlay {
                    self.duration = playerItem.duration.seconds.isNaN ? 0 : playerItem.duration.seconds
                    self.isLoading = false
                    Task { @MainActor in
                        await self.restorePlaybackPosition(for: shiur)
                        self.player?.play()
                        self.player?.rate = self.playbackSpeed
                        self.isPlaying = true
                        // Arm the throttle so the first periodic tick doesn't
                        // immediately flush — the next remote write waits out
                        // firestoreSyncInterval.
                        self.lastFirestoreSync = Date()
                        self.updateNowPlayingInfo()

                        // Track play (server increments shiurim/{id}.playCount and
                        // logs to shiurPlays so this shows up in admin Analytics)
                        if let id = shiur.id, !self.playedShiurimIds.contains(id) {
                            self.playedShiurimIds.insert(id)
                            await AnalyticsService.shared.trackPlay(shiurId: id)
                        }
                    }
                } else if status == .failed {
                    self.error = "Failed to load audio"
                    self.isLoading = false
                }
            }

        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds.isNaN ? 0 : time.seconds
            // Refresh duration once AVFoundation learns it (streamed sources
            // often report NaN/indefinite at .readyToPlay), so the scrubber,
            // skip-forward clamp, and end-of-shiur label recover.
            if self.duration <= 0,
               let itemDuration = self.player?.currentItem?.duration.seconds,
               itemDuration.isFinite, itemDuration > 0 {
                self.duration = itemDuration
            }
            self.savePlaybackPosition()
            self.updateNowPlayingInfo()
            self.tickEndOfShiurTimer()
        }

        // Observe when playback ends. Keep the token so it's removed in stop()
        // — without this, every play(shiur:) accumulated another observer that
        // fired stale callbacks on subsequent items.
        endOfTrackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Mark ended BEFORE clearing so a straggler save tick can't
                // resurrect the cleared position.
                self.playbackEnded = true
                self.isPlaying = false
                self.currentTime = 0
                self.clearPlaybackPosition()
                self.cancelSleepTimer()
            }
        }
    }

    func play() {
        activateSession()
        player?.play()
        player?.rate = playbackSpeed
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        savePlaybackPosition(forceRemote: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        // Flush final position before tearing down so currentShiur/currentTime are still valid
        savePlaybackPosition(forceRemote: true)

        player?.pause()
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let observer = endOfTrackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfTrackObserver = nil
        }
        player = nil
        playerItemObserver = nil
        timeObserver = nil
        currentShiur = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        lastFirestoreSync = nil
        hasRestored = false
        playbackEnded = false
        cancelSleepTimer()
        // Let other apps (Spotify/podcasts) know they may resume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        guard let player = player, time.isFinite else { return }
        let target = duration > 0 ? min(max(0, time), duration) : max(0, time)
        // Optimistic UI update; reconciled to the engine's actual time in the
        // completion handler. Also refresh Now Playing so a lock-screen scrub
        // (which can happen while paused, when the periodic observer is idle)
        // doesn't snap back.
        currentTime = target
        updateNowPlayingInfo()
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                guard let self = self, let p = self.player else { return }
                let actual = p.currentTime().seconds
                self.currentTime = actual.isNaN ? target : actual
                self.updateNowPlayingInfo()
            }
        }
    }

    func skipForward(seconds: TimeInterval = 15) {
        // When duration is unknown (0), don't clamp to 0 — that would seek to
        // the start. Use an effectively-unbounded upper limit; AVPlayer clamps
        // an over-seek to the real media end.
        let upper = duration > 0 ? duration : .greatestFiniteMagnitude
        let newTime = min(currentTime + seconds, upper)
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

    /// Whether a saved position is worth restoring. When duration is unknown
    /// (0 — common for streamed sources at .readyToPlay) we allow the restore
    /// rather than silently dropping it; AVPlayer clamps an over-seek.
    private func shouldRestore(_ position: TimeInterval) -> Bool {
        guard position > 1 else { return false }
        if duration.isFinite && duration > 0 {
            return position < duration - 5
        }
        return true
    }

    private func savePlaybackPosition(forceRemote: Bool = false) {
        // Don't save before the saved position has been restored (avoids
        // clobbering the saved value with ~0), after the track ended (avoids
        // resurrecting a cleared position), or for a meaningless ~0 position.
        guard !playbackEnded, hasRestored, currentTime > 1 else { return }
        guard let shiur = currentShiur, let id = shiur.id else { return }

        // Local save runs every tick — cheap and supports offline resume
        UserDefaults.standard.set(currentTime, forKey: "playback_position_\(id)")

        // Throttle Firestore writes; the 0.5s time observer calls this every tick
        if !forceRemote, let last = lastFirestoreSync,
           Date().timeIntervalSince(last) < firestoreSyncInterval {
            return
        }
        flushPlaybackPositionToFirebase(shiurId: id, position: currentTime)
    }

    /// Force the most recent playback position to Firestore immediately,
    /// wrapped in a background task so the async write can finish if the app is
    /// heading to the background / about to be suspended. Call from the App's
    /// didEnterBackground hook.
    func flushPlaybackPosition() {
        guard currentShiur?.id != nil else { return }
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "FlushPlaybackPosition") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        savePlaybackPosition(forceRemote: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
    }

    private func flushPlaybackPositionToFirebase(shiurId: String, position: TimeInterval) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        lastFirestoreSync = Date()

        let docRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("preferences")
            .document("playbackPositions")

        let now = Date().timeIntervalSince1970 * 1000 // milliseconds, matches website

        // Once we know the doc exists we skip the getDocument round-trip
        if positionsDocExists == true {
            docRef.updateData([
                "positions.\(shiurId)": position,
                "lastUpdated": now,
                "syncedAt": now
            ])
            return
        }

        docRef.getDocument { [weak self] snapshot, _ in
            // If the track ended while this round-trip was in flight, don't
            // re-create the position the end-of-track clear just deleted.
            guard let self = self, !self.playbackEnded else { return }
            if let snapshot = snapshot, snapshot.exists {
                self.positionsDocExists = true
                docRef.updateData([
                    "positions.\(shiurId)": position,
                    "lastUpdated": now,
                    "syncedAt": now
                ])
            } else {
                docRef.setData([
                    "positions": [shiurId: position],
                    "lastUpdated": now,
                    "syncedAt": now
                ]) { error in
                    if error == nil { self.positionsDocExists = true }
                }
            }
        }
    }

    private func restorePlaybackPosition(for shiur: Shiur) async {
        guard let id = shiur.id else {
            hasRestored = true
            return
        }

        // First try local storage for quick access
        let localPosition = UserDefaults.standard.double(forKey: "playback_position_\(id)")

        // Then check Firebase for synced position
        guard let userId = Auth.auth().currentUser?.uid else {
            if shouldRestore(localPosition) {
                seek(to: localPosition)
            }
            hasRestored = true
            return
        }

        // Capture the player we started for, so a fast A→B track switch can't
        // make this async completion seek the wrong (now-current) player.
        let startedPlayer = self.player
        func safeSeek(_ position: TimeInterval) {
            guard currentShiur?.id == id, player === startedPlayer else { return }
            if shouldRestore(position) {
                seek(to: position)
            }
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
               let position = positions[id] as? Double {
                safeSeek(position)
            } else {
                safeSeek(localPosition)
            }
        } catch {
            safeSeek(localPosition)
        }

        hasRestored = true
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

    // MARK: - Interruption Handling
    // When a phone call / Siri / another audio app preempts us, iOS posts
    // .began (we mirror to isPlaying=false so UI stays accurate) and later
    // .ended. The .shouldResume option means iOS thinks it's safe to pick
    // back up — honor it ONLY if we were actually playing before, so a
    // manually-paused shiur doesn't start blasting after a call.
    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Flush the latest position before a (possibly app-killing) interruption.
            savePlaybackPosition(forceRemote: true)
            wasPlayingBeforeInterruption = isPlaying
            player?.pause()
            isPlaying = false
            updateNowPlayingInfo()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume) && wasPlayingBeforeInterruption && player != nil
            // Reset unconditionally so a stale true can't leak into a later interruption.
            wasPlayingBeforeInterruption = false
            if shouldResume {
                try? AVAudioSession.sharedInstance().setActive(true)
                play()
            }
        @unknown default:
            break
        }
    }

    // MARK: - Route Change Handling
    // Pause when the user pulls out headphones / disconnects AirPods so the
    // shiur doesn't start blasting through the speaker mid-sentence.
    private func setupRouteChangeHandling() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }

    // MARK: - Sleep Timer
    func setSleepTimer(_ mode: SleepTimerMode) {
        cancelSleepTimer()
        sleepTimerMode = mode

        switch mode {
        case .off:
            sleepTimerRemaining = nil
        case .minutes(let minutes):
            startCountdownTimer(seconds: TimeInterval(minutes * 60))
        case .endOfShiur:
            // No countdown — the existing time observer checks this each tick.
            sleepTimerRemaining = max(duration - currentTime, 0)
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerMode = .off
        sleepTimerRemaining = nil
    }

    private func startCountdownTimer(seconds: TimeInterval) {
        sleepTimerRemaining = seconds
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { return }
                guard let remaining = self.sleepTimerRemaining else {
                    timer.invalidate()
                    return
                }
                let next = remaining - 1
                if next <= 0 {
                    timer.invalidate()
                    self.sleepTimer = nil
                    self.sleepTimerRemaining = nil
                    self.sleepTimerMode = .off
                    self.pause()
                } else {
                    self.sleepTimerRemaining = next
                }
            }
        }
    }

    /// Called from the periodic time observer when in `.endOfShiur` mode so
    /// the remaining-time label tracks position changes (seeks, speed).
    private func tickEndOfShiurTimer() {
        guard case .endOfShiur = sleepTimerMode else { return }
        sleepTimerRemaining = max(duration - currentTime, 0)
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
