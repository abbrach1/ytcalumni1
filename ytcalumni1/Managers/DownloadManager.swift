import Foundation
import Combine

/// Persisted record of a downloaded shiur. Stored in the on-disk manifest so
/// the Downloads list can render even with no network and before any Firestore
/// fetch resolves. Keeping the full Shiur lets the UI build cards/rows from
/// the manifest without needing the live shiurim list.
struct DownloadedShiur: Codable, Identifiable {
    let shiur: Shiur
    let fileName: String              // relative path inside the downloads directory
    let downloadedAt: Date
    let sizeBytes: Int64

    var id: String { shiur.id ?? fileName }
}

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)   // 0.0 ... 1.0
    case downloaded
    case failed(String)
}

/// Manages background audio downloads and the on-disk manifest of downloaded
/// shiurim. Files go in `Application Support/Downloads/<shiurId>.audio`; the
/// manifest at `Application Support/Downloads/manifest.json` survives app
/// relaunch and is the source of truth for the "Downloaded" filter.
///
/// Uses a background `URLSession` so a long shiur keeps downloading even if
/// the user backgrounds or quits the app. `AppDelegate.application(_:handle…)`
/// calls into `handleEventsForBackgroundURLSession` so iOS can hand back
/// completion callbacks after relaunch.
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloads: [String: DownloadedShiur] = [:]
    @Published private(set) var states: [String: DownloadState] = [:]

    private let backgroundIdentifier = "com.ytcalumni.downloads"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// shiurId → URLSessionDownloadTask, so we can cancel by shiur.
    private var tasksByShiurId: [String: URLSessionDownloadTask] = [:]
    /// Reverse lookup keyed by the task's identifier for delegate callbacks.
    private var shiurIdByTask: [Int: String] = [:]
    /// Cached metadata for an in-flight task so the manifest entry can be
    /// written when the task completes (the delegate only gets a URL + task).
    /// Persisted to `pending.json` so a background download that finishes while
    /// the app is killed can still be matched to its Shiur after relaunch.
    private var pendingShiurs: [String: Shiur] = [:]

    /// Set by the AppDelegate when iOS resumes the app to deliver background
    /// download events; we call it after `urlSessionDidFinishEvents`.
    var backgroundCompletionHandler: (() -> Void)?

    private override init() {
        super.init()
        ensureDownloadsDirectoryExists()
        loadManifest()
        loadPendingManifest()
        reconcileManifest()
        // Re-attach to any background tasks still running after a relaunch so
        // the UI shows in-progress state, cancel works, and we don't start a
        // duplicate download. Touching `session` also wires up the delegate so
        // in-flight tasks re-emit their completion.
        session.getAllTasks { tasks in
            Task { @MainActor in
                for case let task as URLSessionDownloadTask in tasks {
                    guard let shiurId = task.taskDescription else { continue }
                    self.tasksByShiurId[shiurId] = task
                    self.shiurIdByTask[task.taskIdentifier] = shiurId
                    if self.states[shiurId] == nil {
                        self.states[shiurId] = .downloading(progress: 0)
                    }
                }
            }
        }
    }

    // MARK: - Public API

    func state(for shiurId: String) -> DownloadState {
        if let s = states[shiurId] { return s }
        return downloads[shiurId] != nil ? .downloaded : .idle
    }

    func isDownloaded(_ shiurId: String) -> Bool {
        downloads[shiurId] != nil
    }

    /// Returns the local file URL for a downloaded shiur, or nil if missing.
    /// Read-only: a transient false-negative fileExists check must NOT prune
    /// the manifest entry (that would permanently drop the entry + its metadata
    /// on a single filesystem hiccup). Pruning happens only at launch in
    /// reconcileManifest() and via deleteDownload().
    func localURL(for shiurId: String) -> URL? {
        guard let entry = downloads[shiurId] else { return nil }
        let url = downloadsDirectory.appendingPathComponent(entry.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ shiur: Shiur) {
        guard let shiurId = shiur.id,
              let audioUrlString = shiur.audioUrl,
              let url = URL(string: processAudioUrl(audioUrlString)) else { return }

        if isDownloaded(shiurId) { return }
        if tasksByShiurId[shiurId] != nil { return }

        let task = session.downloadTask(with: url)
        task.taskDescription = shiurId
        tasksByShiurId[shiurId] = task
        shiurIdByTask[task.taskIdentifier] = shiurId
        pendingShiurs[shiurId] = shiur
        savePendingManifest()
        states[shiurId] = .downloading(progress: 0)
        task.resume()
    }

    func cancelDownload(_ shiurId: String) {
        if let task = tasksByShiurId[shiurId] {
            task.cancel()
            tasksByShiurId.removeValue(forKey: shiurId)
            shiurIdByTask.removeValue(forKey: task.taskIdentifier)
        }
        pendingShiurs.removeValue(forKey: shiurId)
        savePendingManifest()
        states[shiurId] = .idle
    }

    func deleteDownload(_ shiurId: String) {
        guard let entry = downloads[shiurId] else { return }
        let url = downloadsDirectory.appendingPathComponent(entry.fileName)
        try? FileManager.default.removeItem(at: url)
        downloads.removeValue(forKey: shiurId)
        states[shiurId] = .idle
        saveManifest()
    }

    func totalDownloadedBytes() -> Int64 {
        downloads.values.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Storage

    private var downloadsDirectory: URL {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    private var manifestURL: URL {
        downloadsDirectory.appendingPathComponent("manifest.json")
    }

    private var pendingManifestURL: URL {
        downloadsDirectory.appendingPathComponent("pending.json")
    }

    private func ensureDownloadsDirectoryExists() {
        let dir = downloadsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Don't back up downloaded audio to iCloud — it's reproducible content.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var dirCopy = dir
        try? dirCopy.setResourceValues(values)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([DownloadedShiur].self, from: data)
            downloads = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
                entry.shiur.id.map { ($0, entry) }
            })
        } catch {
            print("[downloads] Failed to load manifest: \(error)")
        }
    }

    private func saveManifest() {
        let entries = Array(downloads.values)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            print("[downloads] Failed to save manifest: \(error)")
        }
    }

    /// Persisted in-flight metadata. Without this, a background download that
    /// completes while the app is killed has no Shiur to attach on relaunch,
    /// and the completed file was previously discarded.
    private func savePendingManifest() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Array(pendingShiurs.values))
            try data.write(to: pendingManifestURL, options: .atomic)
        } catch {
            print("[downloads] Failed to save pending manifest: \(error)")
        }
    }

    private func loadPendingManifest() {
        guard let data = try? Data(contentsOf: pendingManifestURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let shiurs = try? decoder.decode([Shiur].self, from: data) {
            pendingShiurs = Dictionary(uniqueKeysWithValues: shiurs.compactMap { s in s.id.map { ($0, s) } })
        }
    }

    /// Drops manifest entries whose backing file is gone. Skips entirely if the
    /// Downloads directory itself isn't reachable, so a transient outage (e.g.
    /// mid-restore from backup) never prunes valid entries.
    private func reconcileManifest() {
        let dir = downloadsDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        let missing = downloads.filter {
            !FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.value.fileName).path)
        }
        guard !missing.isEmpty else { return }
        for id in missing.keys { downloads.removeValue(forKey: id) }
        saveManifest()
    }

    // MARK: - URL processing (matches AudioPlayerManager so downloads use
    // the same resolved URL as streaming).
    private func processAudioUrl(_ url: String) -> String {
        if url.contains("drive.google.com") {
            if let fileId = extractGoogleDriveFileId(from: url) {
                return "https://drive.google.com/uc?export=download&id=\(fileId)"
            }
        }
        return url
    }

    private func extractGoogleDriveFileId(from url: String) -> String? {
        if let range = url.range(of: "/file/d/") {
            let startIndex = range.upperBound
            let remaining = url[startIndex...]
            if let endIndex = remaining.firstIndex(of: "/") {
                return String(remaining[..<endIndex])
            }
            return String(remaining)
        }
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
}

// MARK: - URLSession Delegates
// These are called on URLSession's background queue, so we hop to the main
// actor before touching any @Published state.
extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        let taskId = downloadTask.taskIdentifier
        let descriptionId = downloadTask.taskDescription
        Task { @MainActor in
            let shiurId = self.shiurIdByTask[taskId] ?? descriptionId
            if let shiurId = shiurId {
                self.states[shiurId] = .downloading(progress: progress)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // We must move the file synchronously here — the temp file is deleted
        // as soon as this delegate returns. Hop to main after the move.
        let taskId = downloadTask.taskIdentifier
        let descriptionId = downloadTask.taskDescription

        // Validate the HTTP response BEFORE recording success. Google Drive
        // serves a virus-scan/confirmation page (HTTP 200, Content-Type
        // text/html) for large files; that HTML must never be saved as audio
        // (it would "succeed", then fail to play and suppress the network path).
        let http = downloadTask.response as? HTTPURLResponse
        let statusOK = http.map { (200..<300).contains($0.statusCode) } ?? true
        let contentType = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        let looksLikeHTML = contentType.contains("text/html")

        guard statusOK, !looksLikeHTML else {
            let status = http?.statusCode ?? -1
            // Don't move the temp file — letting this delegate return deletes it.
            Task { @MainActor in
                let shiurId = self.shiurIdByTask[taskId] ?? descriptionId
                guard let shiurId = shiurId else { return }
                self.tasksByShiurId.removeValue(forKey: shiurId)
                self.shiurIdByTask.removeValue(forKey: taskId)
                self.pendingShiurs.removeValue(forKey: shiurId)
                self.savePendingManifest()
                self.states[shiurId] = .failed(
                    looksLikeHTML ? "Source returned a web page, not audio" : "Download failed (HTTP \(status))"
                )
            }
            return
        }

        // Resolve where to put the file. Doing this off-actor — only touches
        // filesystem APIs, not @Published state.
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Downloads", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Use the shiurId as filename when known; fall back to a UUID so we
        // never drop the bytes on the floor.
        let fileName = (descriptionId ?? UUID().uuidString) + ".audio"
        let destination = dir.appendingPathComponent(fileName)
        try? fm.removeItem(at: destination)

        var moveError: Error?
        var sizeBytes: Int64 = 0
        do {
            try fm.moveItem(at: location, to: destination)
            // Reproducible content — keep out of iCloud/iTunes backups. The
            // per-directory exclusion doesn't propagate to files created later,
            // so set it per file here.
            var dest = destination
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dest.setResourceValues(values)
            let attrs = try fm.attributesOfItem(atPath: destination.path)
            sizeBytes = (attrs[.size] as? Int64) ?? 0
        } catch {
            moveError = error
        }

        Task { @MainActor in
            let shiurId = self.shiurIdByTask[taskId] ?? descriptionId
            guard let shiurId = shiurId else { return }
            self.tasksByShiurId.removeValue(forKey: shiurId)
            self.shiurIdByTask.removeValue(forKey: taskId)

            if let moveError = moveError {
                self.states[shiurId] = .failed(moveError.localizedDescription)
                self.pendingShiurs.removeValue(forKey: shiurId)
                self.savePendingManifest()
                return
            }

            // `wasPending` distinguishes a genuinely new, user-initiated
            // download (count it in analytics) from a background replay.
            let wasPending = self.pendingShiurs.removeValue(forKey: shiurId)
            self.savePendingManifest()

            if let shiur = wasPending ?? self.downloads[shiurId]?.shiur {
                let entry = DownloadedShiur(
                    shiur: shiur,
                    fileName: fileName,
                    downloadedAt: Date(),
                    sizeBytes: sizeBytes
                )
                self.downloads[shiurId] = entry
                self.states[shiurId] = .downloaded
                self.saveManifest()
                if wasPending != nil {
                    Task { await AnalyticsService.shared.trackDownload(shiurId: shiurId) }
                }
            } else {
                // Metadata unavailable (very rare now that pending is persisted).
                // NEVER delete the completed file — record a minimal entry so it
                // stays playable; metadata can be refreshed on a later download.
                let placeholder = Shiur(
                    id: shiurId,
                    title: "Downloaded Shiur",
                    rebbe: "",
                    date: "",
                    tags: [],
                    audioUrl: nil,
                    pdfUrl: nil,
                    description: nil,
                    playCount: nil,
                    downloadCount: nil,
                    series: nil
                )
                let entry = DownloadedShiur(
                    shiur: placeholder,
                    fileName: fileName,
                    downloadedAt: Date(),
                    sizeBytes: sizeBytes
                )
                self.downloads[shiurId] = entry
                self.states[shiurId] = .downloaded
                self.saveManifest()
                print("[downloads] Completed \(shiurId) with missing metadata; saved minimal entry, retained file \(fileName)")
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        let descriptionId = task.taskDescription
        Task { @MainActor in
            let shiurId = self.shiurIdByTask[taskId] ?? descriptionId
            guard let shiurId = shiurId else { return }
            self.tasksByShiurId.removeValue(forKey: shiurId)
            self.shiurIdByTask.removeValue(forKey: taskId)
            self.pendingShiurs.removeValue(forKey: shiurId)
            self.savePendingManifest()
            // Cancellation already cleared state to .idle in cancelDownload;
            // don't overwrite it with a "failed" label.
            if case .downloading = self.states[shiurId] ?? .idle {
                self.states[shiurId] = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
