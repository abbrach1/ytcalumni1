import SwiftUI

/// Lists shiurim the user has downloaded for offline playback. Lets them tap
/// to play, swipe to remove, or clear all at once. Total storage at the top
/// gives a quick read on how much device space the downloads are using.
struct DownloadsView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss

    @State private var showClearAllConfirm = false

    private var downloads: [DownloadedShiur] {
        downloadManager.downloads.values
            .sorted { $0.downloadedAt > $1.downloadedAt }
    }

    private var totalSizeText: String {
        let bytes = downloadManager.totalDownloadedBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        Group {
            if downloads.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !downloads.isEmpty {
                    Button(role: .destructive) {
                        showClearAllConfirm = true
                    } label: {
                        Text("Clear All")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "Remove all downloads?",
            isPresented: $showClearAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove \(downloads.count) Downloads", role: .destructive) {
                for entry in downloads {
                    if let id = entry.shiur.id {
                        downloadManager.deleteDownload(id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(totalSizeText) of storage. You can re-download anytime.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.navy.opacity(0.3))
            Text("No downloads yet")
                .font(.headline)
                .foregroundColor(.navy)
            Text("Tap the download button on any shiur to save it for offline listening.")
                .font(.subheadline)
                .foregroundColor(.navy.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Storage usage summary
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.gold)
                    Text("\(downloads.count) shiur\(downloads.count == 1 ? "" : "im") · \(totalSizeText)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVStack(spacing: 10) {
                    ForEach(downloads) { entry in
                        DownloadRow(entry: entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, audioPlayer.currentShiur != nil ? 100 : 20)
            }
        }
    }
}

private struct DownloadRow: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var downloadManager: DownloadManager

    let entry: DownloadedShiur

    private var sizeText: String {
        ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file)
    }

    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentShiur?.id == entry.shiur.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: {
                if isCurrentlyPlaying {
                    audioPlayer.togglePlayPause()
                } else {
                    Task { await audioPlayer.play(shiur: entry.shiur) }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isCurrentlyPlaying ? Color.gold : Color.navy)
                        .frame(width: 40, height: 40)
                    Image(systemName: isCurrentlyPlaying && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(isCurrentlyPlaying ? .navy : .cream)
                        .font(.subheadline)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.shiur.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                    .lineLimit(2)
                Text(entry.shiur.rebbe)
                    .font(.caption)
                    .foregroundColor(.navy.opacity(0.7))
                Text(sizeText)
                    .font(.caption2)
                    .foregroundColor(.navy.opacity(0.5))
            }

            Spacer()

            Button(action: {
                if let id = entry.shiur.id {
                    downloadManager.deleteDownload(id)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 1)
    }
}

#Preview {
    NavigationStack {
        DownloadsView()
            .environmentObject(AudioPlayerManager())
            .environmentObject(DownloadManager.shared)
    }
}
