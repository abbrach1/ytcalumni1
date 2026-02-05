import SwiftUI

// MARK: - Shiur Card (for Home page)
struct ShiurCard: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    let shiur: Shiur
    let showFullDetails: Bool
    
    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentShiur?.id == shiur.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(shiur.title)
                        .font(.headline)
                        .foregroundColor(.navy)
                    
                    Text(shiur.rebbe)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Playing")
                            .font(.caption)
                            .foregroundColor(.navy.opacity(0.6))
                    }
                }
            }
            
            // Date and tags
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.gold)
                        .font(.caption)
                    
                    Text(shiur.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                }
                
                if !shiur.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(shiur.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.gold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gold.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            // Audio player section - only if there's audio
            if shiur.audioUrl != nil {
                Divider()
                    .background(Color.navy.opacity(0.1))
                
                HStack(spacing: 12) {
                    // Play button
                    Button(action: {
                        if isCurrentlyPlaying {
                            audioPlayer.togglePlayPause()
                        } else {
                            Task {
                                await audioPlayer.play(shiur: shiur)
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isCurrentlyPlaying && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.body)
                            
                            Text(isCurrentlyPlaying && audioPlayer.isPlaying ? "Pause" : "Play")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.cream)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.navy)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // PDF button - ONLY show if pdfUrl exists and is not empty
                    if let pdfUrl = shiur.pdfUrl, !pdfUrl.isEmpty {
                        Button(action: {
                            if let url = URL(string: pdfUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                Text("Mareh Mekomos")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(.navy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.gold.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Browse all button
            if showFullDetails {
                NavigationLink(destination: ShiurimView()) {
                    HStack {
                        Text("Browse All Shiurim")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.navy)
                    .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

// MARK: - Mini Player View
struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var showFullPlayer = false
    
    var body: some View {
        if let shiur = audioPlayer.currentShiur {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.navy.opacity(0.3))
                        
                        Rectangle()
                            .fill(Color.gold)
                            .frame(width: audioPlayer.duration > 0 ?
                                   geometry.size.width * (audioPlayer.currentTime / audioPlayer.duration) : 0)
                    }
                }
                .frame(height: 3)
                
                // Player content
                HStack(spacing: 12) {
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shiur.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.cream)
                            .lineLimit(1)
                        
                        Text(shiur.rebbe)
                            .font(.caption)
                            .foregroundColor(.cream.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Time
                    Text(audioPlayer.formatTime(audioPlayer.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cream.opacity(0.7))
                    
                    // Controls
                    HStack(spacing: 16) {
                        Button(action: { audioPlayer.skipBackward() }) {
                            Image(systemName: "gobackward.15")
                                .font(.body)
                                .foregroundColor(.cream)
                        }
                        
                        Button(action: { audioPlayer.togglePlayPause() }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .foregroundColor(.navy)
                                .frame(width: 40, height: 40)
                                .background(Color.gold)
                                .clipShape(Circle())
                        }
                        
                        Button(action: { audioPlayer.skipForward() }) {
                            Image(systemName: "goforward.15")
                                .font(.body)
                                .foregroundColor(.cream)
                        }
                        
                        Button(action: { audioPlayer.stop() }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.cream.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.navy)
            .onTapGesture {
                showFullPlayer = true
            }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView()
                    .environmentObject(audioPlayer)
            }
        }
    }
}

// MARK: - Full Player View
struct FullPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    @State private var showSpeedMenu = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Album art / Logo
                ZStack {
                    Circle()
                        .fill(Color.navy.opacity(0.1))
                        .frame(width: 200, height: 200)
                    
                    Image("yeshiva-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                }
                
                // Shiur info
                if let shiur = audioPlayer.currentShiur {
                    VStack(spacing: 8) {
                        Text(shiur.title)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.navy)
                            .multilineTextAlignment(.center)
                        
                        Text(shiur.rebbe)
                            .font(.body)
                            .foregroundColor(.navy.opacity(0.7))
                        
                        Text(shiur.shortDate)
                            .font(.caption)
                            .foregroundColor(.navy.opacity(0.5))
                    }
                    .padding(.horizontal)
                }
                
                // Progress slider
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayer.duration, 1)
                    )
                    .tint(.gold)
                    
                    HStack {
                        Text(audioPlayer.formatTime(audioPlayer.currentTime))
                        Spacer()
                        Text(audioPlayer.formatTime(audioPlayer.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.navy.opacity(0.6))
                }
                .padding(.horizontal, 24)
                
                // Main controls
                HStack(spacing: 40) {
                    Button(action: { audioPlayer.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                            .foregroundColor(.navy)
                    }
                    
                    Button(action: { audioPlayer.togglePlayPause() }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.cream)
                            .frame(width: 72, height: 72)
                            .background(Color.navy)
                            .clipShape(Circle())
                    }
                    
                    Button(action: { audioPlayer.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.title)
                            .foregroundColor(.navy)
                    }
                }
                
                // Speed control
                HStack(spacing: 24) {
                    Menu {
                        ForEach(audioPlayer.speedOptions, id: \.self) { speed in
                            Button(action: { audioPlayer.setSpeed(speed) }) {
                                HStack {
                                    Text("\(speed, specifier: "%.2g")x")
                                    if audioPlayer.playbackSpeed == speed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                            Text("\(audioPlayer.playbackSpeed, specifier: "%.2g")x")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.navy.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    // Volume slider
                    HStack(spacing: 8) {
                        Image(systemName: audioPlayer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundColor(.navy.opacity(0.6))
                            .font(.caption)
                        
                        Slider(
                            value: Binding(
                                get: { Double(audioPlayer.volume) },
                                set: { audioPlayer.setVolume(Float($0)) }
                            ),
                            in: 0...1
                        )
                        .tint(.gold)
                        .frame(width: 100)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.navy)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { audioPlayer.stop(); dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.navy.opacity(0.5))
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
            .environmentObject(AudioPlayerManager())
    }
}
