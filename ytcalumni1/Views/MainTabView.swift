import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @StateObject private var audioPlayer = AudioPlayerManager()
    @ObservedObject private var firebase = FirebaseService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                
                NavigationStack {
                    ShiurimView()
                }
                .tag(1)
                .tabItem {
                    Label("Shiurim", systemImage: "headphones")
                }
                
                NavigationStack {
                    EventsView()
                }
                .tag(2)
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
                
                NavigationStack {
                    ContactsView()
                }
                .tag(3)
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
            }
            .tint(.gold)
            
            // Mini Player Overlay
            if audioPlayer.currentShiur != nil {
                MiniPlayerView()
                    .environmentObject(audioPlayer)
                    .padding(.bottom, 49) // Tab bar height
            }

            // Offline banner — shows when fetchShiurim is reading from the
            // disk cache because Firestore was unreachable.
            if firebase.isOfflineFallback {
                OfflineBanner()
                    .padding(.bottom, audioPlayer.currentShiur != nil ? 109 : 49)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: firebase.isOfflineFallback)
        .environmentObject(audioPlayer)
    }
}

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing last saved list")
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.cream)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.navy.opacity(0.9))
        .cornerRadius(20)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
