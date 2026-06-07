import SwiftUI
import UIKit
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
        .appUpdateGate()
    }
}

// MARK: - App Update Gate
// Checks settings/appUpdate on launch and each time the app returns to the
// foreground. If the installed version is older than the admin-set latest
// version, it shows either a dismissable prompt (optional) or a full-screen
// blocker (forced) that links to the App Store. Mirrors the website admin's
// "App Update Prompt" controls.
struct AppUpdateGateModifier: ViewModifier {
    @State private var config: AppUpdateConfig?
    @State private var showOptional = false
    @State private var dismissedOptional = false

    func body(content: Content) -> some View {
        content
            .task { await check() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await check() }
            }
            // Forced update: a blocker drawn over everything else.
            .overlay {
                if let config, config.updateAvailable, config.forceUpdate {
                    ForcedUpdateView(config: config)
                        .transition(.opacity)
                }
            }
            // Optional update: a dismissable alert.
            .alert(config?.title ?? "Update Available", isPresented: $showOptional) {
                if let urlString = config?.appStoreUrl, let url = URL(string: urlString) {
                    Button("Update Now") { UIApplication.shared.open(url) }
                }
                Button("Later", role: .cancel) { dismissedOptional = true }
            } message: {
                Text(config?.message ?? "")
            }
    }

    private func check() async {
        let cfg = try? await FirebaseService.shared.fetchAppUpdateConfig()
        await MainActor.run {
            config = cfg
            // Only auto-raise the optional prompt once per app run.
            if let cfg, cfg.updateAvailable, !cfg.forceUpdate, !dismissedOptional {
                showOptional = true
            }
        }
    }
}

extension View {
    func appUpdateGate() -> some View { modifier(AppUpdateGateModifier()) }
}

struct ForcedUpdateView: View {
    let config: AppUpdateConfig

    var body: some View {
        ZStack {
            Color.navy.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.gold)
                Text(config.title)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.cream)
                    .multilineTextAlignment(.center)
                Text(config.message)
                    .font(.subheadline)
                    .foregroundColor(.cream.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !config.appStoreUrl.isEmpty, let url = URL(string: config.appStoreUrl) {
                    Button(action: { UIApplication.shared.open(url) }) {
                        Text("Update Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gold)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(32)
        }
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
