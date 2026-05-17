import SwiftUI

// In-app branded feedback form. Posts to /api/send-feedback on the website,
// which delivers the email to ADMIN_EMAIL via Resend.
struct FeedbackView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    // Production base URL for the website's API. Hardcoded since the iOS
    // app currently has no other HTTP-to-website calls and no env config.
    private let endpoint = URL(string: "https://alumni.ytchaim.com/api/send-feedback")!

    private let categories = ["General", "Bug Report", "Feature Request", "Content / Shiur", "Account / Login"]

    @State private var category: String = "General"
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private var userEmail: String {
        authManager.user?.email ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Branded header — same navy block + serif headline used by Events / Contacts
                VStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.gold)

                    Text("Send Feedback")
                        .font(.serifHeadline())
                        .foregroundColor(.cream)

                    Text("Questions, ideas, or bugs — we read every one.")
                        .font(.subheadline)
                        .foregroundColor(.cream.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.navy)

                VStack(spacing: 20) {
                    // Category
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.navy)

                        Menu {
                            ForEach(categories, id: \.self) { option in
                                Button(option) { category = option }
                            }
                        } label: {
                            HStack {
                                Text(category)
                                    .foregroundColor(.navy)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.navy.opacity(0.4))
                                    .font(.caption.weight(.semibold))
                            }
                            .customTextField()
                        }
                    }

                    // Subject (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Subject")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.navy)
                            Text("(Optional)")
                                .font(.caption)
                                .foregroundColor(.navy.opacity(0.5))
                        }
                        TextField("Briefly, what's this about?", text: $subject)
                            .customTextField()
                    }

                    // Message
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Message")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.navy)

                        TextEditor(text: $message)
                            .frame(minHeight: 160)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Reply-to (read-only signed-in email)
                    if !userEmail.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.gold)
                            Text("Replies will go to \(userEmail)")
                                .font(.caption)
                                .foregroundColor(.navy.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Submit
                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .cream))
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "paperplane.fill")
                            Text(isSubmitting ? "Sending..." : "Send Feedback")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: !canSubmit))
                    .disabled(!canSubmit)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                .padding(16)
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundColor(.navy)
            }
        }
        .alert("Feedback Sent", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Thanks — your feedback was sent. We'll get back to you if a reply is needed.")
        }
        .alert("Couldn't send", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await sendFeedback()
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func sendFeedback() async throws {
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let versionString = "\(appVersion) (\(build))"

        let payload: [String: Any] = [
            "category": category,
            "subject": subject.trimmingCharacters(in: .whitespacesAndNewlines),
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "submittedBy": userEmail,
            "source": "ios",
            "appVersion": versionString,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Try to surface the server's error message if it sent one.
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = body["error"] as? String {
                throw NSError(domain: "FeedbackView", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: err])
            }
            throw NSError(domain: "FeedbackView", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Server returned an error. Please try again."])
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
            .environmentObject(AuthManager())
    }
}
