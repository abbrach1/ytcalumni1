import SwiftUI

struct RequestAccessView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(.gold)
            }
            
            // Title and Description
            VStack(spacing: 12) {
                Text("Access Pending")
                    .font(.serifHeadline())
                    .foregroundColor(.navy)
                
                Text("Your account has been created and is awaiting approval from an administrator.")
                    .font(.body)
                    .foregroundColor(.navy.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Info Box
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.gold)
                    Text("You will receive an email once your account is approved")
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.8))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.gold)
                    Text("Questions? Contact alumni@ytchaim.com")
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.8))
                }
            }
            .padding(20)
            .background(Color.navy.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button(action: refreshStatus) {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cream))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRefreshing ? "Checking..." : "Check Status")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: isRefreshing))
                .disabled(isRefreshing)
                .padding(.horizontal, 24)
                
                Button(action: {
                    authManager.signOut()
                }) {
                    Text("Sign Out")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy.opacity(0.7))
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.cream.ignoresSafeArea())
    }
    
    private func refreshStatus() {
        isRefreshing = true
        
        Task {
            await authManager.refreshUserStatus()
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

#Preview {
    RequestAccessView()
        .environmentObject(AuthManager())
}
