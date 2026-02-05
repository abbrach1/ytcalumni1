import SwiftUI

struct CollectionDetailView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    let collection: ShiurCollection
    
    @State private var shiurim: [Shiur] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gold)
                    
                    Text(collection.name)
                        .font(.serifHeadline())
                        .foregroundColor(.cream)
                        .multilineTextAlignment(.center)
                    
                    Text(collection.description)
                        .font(.subheadline)
                        .foregroundColor(.cream.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("\(shiurim.count) Shiurim")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gold.opacity(0.2))
                        .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal)
                .background(Color.navy)
                
                // Shiurim List
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(.navy)
                            .padding(.top, 60)
                    }
                } else if shiurim.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "headphones")
                            .font(.system(size: 40))
                            .foregroundColor(.navy.opacity(0.3))
                        
                        Text("No shiurim in this collection")
                            .font(.headline)
                            .foregroundColor(.navy.opacity(0.6))
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(shiurim) { shiur in
                            CollectionShiurRow(shiur: shiur)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, audioPlayer.currentShiur != nil ? 80 : 0)
                }
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadShiurim()
        }
    }
    
    private func loadShiurim() async {
        isLoading = true
        
        do {
            let allShiurim = try await FirebaseService.shared.fetchShiurim()
            
            if let shiurIds = collection.shiurIds {
                shiurim = allShiurim.filter { shiur in
                    guard let id = shiur.id else { return false }
                    return shiurIds.contains(id)
                }
            } else {
                shiurim = []
            }
        } catch {
            print("Error loading collection shiurim: \(error)")
        }
        
        isLoading = false
    }
}

struct CollectionShiurRow: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    let shiur: Shiur
    
    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentShiur?.id == shiur.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shiur.title)
                        .font(.headline)
                        .foregroundColor(.navy)
                    
                    Text(shiur.rebbe)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                    
                    Text(shiur.shortDate)
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Playing")
                            .font(.caption2)
                            .foregroundColor(.navy.opacity(0.6))
                    }
                }
            }
            
            // Tags
            if !shiur.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(shiur.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.navy.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.navy.opacity(0.08))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Play button
            if shiur.audioUrl != nil {
                Button(action: {
                    if isCurrentlyPlaying {
                        audioPlayer.togglePlayPause()
                    } else {
                        Task {
                            await audioPlayer.play(shiur: shiur)
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isCurrentlyPlaying && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        Text(isCurrentlyPlaying && audioPlayer.isPlaying ? "Pause" : "Play")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isCurrentlyPlaying ? Color.gold : Color.navy)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collection: ShiurCollection(
            id: "1",
            name: "Sample Collection",
            description: "A collection of great shiurim",
            isActive: true,
            shiurIds: []
        ))
        .environmentObject(AudioPlayerManager())
    }
}
