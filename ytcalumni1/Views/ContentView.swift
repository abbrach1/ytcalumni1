import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.user == nil {
                LoginView()
            } else if !authManager.isApproved {
                RequestAccessView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.user?.uid)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("yeshiva-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                ProgressView()
                    .tint(.navy)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
