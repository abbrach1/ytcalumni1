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
    private var pendingShiurs: [String: Shiur] = [:]

    /// Set by the AppDelegate when iOS resumes the app to deliver background
    /// download events; we call it after `urlSessionDidFinishEvents`.
    var backgroundCompletionHandler: (() -> Void)?

    private override init() {
        super.init()
        ensureDownloadsDirectoryExists()
        loadManifest()
        // Touch the session so the delegate is wired up at launch and any
        // in-flight tasks (started before a kill) re-emit their completion.
        _ = session
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
    /// Verifies the file is still on disk — a manifest entry without a file
    /// (rare, e.g. user cleared storage) is dropped here.
    func localURL(for shiurId: String) -> URL? {
        guard let entry = downloads[shiurId] else { return nil }
        let url = downloadsDirectory.appendingPathComponent(entry.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        downloads.removeValue(forKey: shiurId)
        saveManifest()
        return nil
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
                return
            }

            if let shiur = self.pendingShiurs.removeValue(forKey: shiurId)
                ?? self.downloads[shiurId]?.shiur {
                let entry = DownloadedShiur(
                    shiur: shiur,
                    fileName: fileName,
                    downloadedAt: Date(),
                    sizeBytes: sizeBytes
                )
                self.downloads[shiurId] = entry
                self.states[shiurId] = .downloaded
                self.saveManifest()
            } else {
                // No metadata available (shouldn't happen — be defensive).
                self.states[shiurId] = .failed("Missing metadata")
                try? FileManager.default.removeItem(at: destination)
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
