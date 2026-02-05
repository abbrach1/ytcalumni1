import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @StateObject private var audioPlayer = AudioPlayerManager()
    
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
        }
        .environmentObject(audioPlayer)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
