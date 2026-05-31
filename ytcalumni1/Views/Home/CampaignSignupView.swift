import SwiftUI
import UIKit
import FirebaseAuth

// Home-screen call-to-action for the alumni fundraiser. Mirrors the website's
// component: shows when settings/fundraiserCampaign.enabled, opens a form that
// writes to campaignSignups + emails the office, and confirms re-submission if
// the user already created a page.
struct CampaignBanner: View {
    let campaign: FundraiserCampaign
    @State private var showForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !campaign.campaignName.isEmpty {
                Text(campaign.campaignName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundColor(.gold)
            }

            Text(campaign.headline)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(.cream)
                .fixedSize(horizontal: false, vertical: true)

            if !campaign.description.isEmpty {
                Text(campaign.description)
                    .font(.subheadline)
                    .foregroundColor(.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let deadline = campaign.formattedDeadline {
                Text("Campaign ends \(deadline)")
                    .font(.caption)
                    .foregroundColor(.cream.opacity(0.6))
            }

            Button(action: { showForm = true }) {
                Text("Create Your Page")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gold)
                    .cornerRadius(10)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.navy)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
        .sheet(isPresented: $showForm) {
            CampaignFormView(campaign: campaign)
        }
    }
}

struct CampaignFormView: View {
    let campaign: FundraiserCampaign
    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var pageTitle = ""
    @State private var goalAmount = ""
    @State private var message = ""

    init(campaign: FundraiserCampaign) {
        self.campaign = campaign
        // Pre-fill the goal + message from the admin-configured defaults.
        _goalAmount = State(initialValue: campaign.defaultGoal)
        _message = State(initialValue: campaign.defaultMessage)
    }

    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var alreadySubmitted = false
    @State private var showResubmitConfirm = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !goalAmount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    successView
                } else {
                    formView
                }
            }
            .background(Color.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.navy)
                }
            }
            .task { await prefill() }
            .confirmationDialog(
                "You've already created a page",
                isPresented: $showResubmitConfirm,
                titleVisibility: .visible
            ) {
                Button("Create Another") { Task { await submit() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to create another fundraising page?")
            }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create Your Fundraising Page")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.navy)
                Text("Tell us a few details and we'll set up your personal campaign page.")
                    .font(.subheadline)
                    .foregroundColor(.navy.opacity(0.7))

                field("Full Name", text: $fullName)
                field("Email", text: $email, keyboard: .emailAddress)
                field("Phone (optional)", text: $phone, keyboard: .phonePad)
                field("Page / Team Title (optional)", text: $pageTitle)
                field("Fundraising Goal", text: $goalAmount)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Personal Message (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    TextEditor(text: $message)
                        .frame(height: 90)
                        .padding(6)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.navy.opacity(0.15))
                        )
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button(action: attemptSubmit) {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView().tint(.cream)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? Color.navy : Color.navy.opacity(0.4))
                    .cornerRadius(10)
                }
                .disabled(!canSubmit || isSubmitting)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text("Your page has been created!")
                .font(.title3.weight(.semibold))
                .foregroundColor(.navy)
                .multilineTextAlignment(.center)
            Text("You'll get an email with all the info when the campaign goes live.")
                .font(.subheadline)
                .foregroundColor(.navy.opacity(0.7))
                .multilineTextAlignment(.center)

            if !campaign.campaignUrl.isEmpty, let url = URL(string: campaign.campaignUrl) {
                Link(destination: url) {
                    Text("Visit the Campaign")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.cream)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.navy)
                        .cornerRadius(10)
                }
            }

            Button("Done") { dismiss() }
                .foregroundColor(.navy.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.navy)
            TextField("", text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.navy.opacity(0.15))
                )
        }
    }

    private func attemptSubmit() {
        guard canSubmit, !isSubmitting else { return }
        if alreadySubmitted {
            showResubmitConfirm = true
        } else {
            Task { await submit() }
        }
    }

    private func prefill() async {
        guard let user = Auth.auth().currentUser else { return }
        if email.isEmpty { email = user.email ?? "" }
        var name = user.displayName ?? ""
        if let userEmail = user.email,
           let info = await FirebaseService.shared.fetchMyContactInfo(email: userEmail) {
            if !info.name.isEmpty { name = info.name }
            if !info.phone.isEmpty, phone.isEmpty { phone = info.phone }
        }
        if fullName.isEmpty { fullName = name }
        alreadySubmitted = await FirebaseService.shared.hasSubmittedCampaign(uid: user.uid)
    }

    private func submit() async {
        guard let user = Auth.auth().currentUser else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await FirebaseService.shared.submitCampaignSignup(
                uid: user.uid,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                pageTitle: pageTitle.trimmingCharacters(in: .whitespaces),
                goalAmount: goalAmount.trimmingCharacters(in: .whitespaces),
                message: message.trimmingCharacters(in: .whitespaces),
                submittedBy: user.email,
                campaignName: campaign.campaignName
            )
            alreadySubmitted = true
            submitted = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        isSubmitting = false
    }
}
