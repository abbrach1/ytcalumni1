import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Email subscriptions for new-shiur notifications. Mirrors the website's
/// /subscriptions page (app/subscriptions/page.tsx in the website repo):
///   reads:  settings/shiurOptions.{rebbeim, tags}  +  subscriptions/{uid}
///   writes: subscriptions/{uid} = {userId, email, rebbeim, tags, updatedAt}
/// The website's email-fanout job reads from `subscriptions` and matches
/// these arrays against newly-uploaded shiurim.
struct EmailSubscriptionsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var rebbeimOptions: [String] = []
    @State private var tagsOptions: [String] = []
    @State private var selectedRebbeim: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var pushEnabled: Bool = NotificationManager.shared.pushSubscriptionsEnabled
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    private let db = Firestore.firestore()
    private let notifications = NotificationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if isLoading {
                    HStack { Spacer(); ProgressView().tint(.navy); Spacer() }
                        .padding(.top, 80)
                } else {
                    pushToggleRow
                    section(
                        title: "Rebbeim",
                        options: rebbeimOptions,
                        selected: $selectedRebbeim,
                        emptyText: "No rebbeim available yet."
                    )
                    section(
                        title: "Topics",
                        options: tagsOptions,
                        selected: $selectedTags,
                        emptyText: "No topics available yet."
                    )
                    summary
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusIsError ? .red : .navy.opacity(0.7))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Email Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundColor(.navy)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) {
                    if isSaving {
                        ProgressView().tint(.navy)
                    } else {
                        Text("Save").fontWeight(.semibold).foregroundColor(.navy)
                    }
                }
                .disabled(isSaving || isLoading)
            }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill").foregroundColor(.gold)
                Text("Shiur Email Subscriptions")
                    .font(.headline)
                    .foregroundColor(.navy)
            }
            if let email = authManager.user?.email {
                (Text("Pick the rebbeim and topics you want to follow. We'll email you at ")
                    .foregroundColor(.navy.opacity(0.7))
                    + Text(email).foregroundColor(.navy).fontWeight(.medium)
                    + Text(" whenever a matching shiur is uploaded.").foregroundColor(.navy.opacity(0.7)))
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
    }

    private var pushToggleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .foregroundColor(.gold)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text("Also send iPhone push notifications")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                Text("Get an instant alert on this device when a matching shiur is uploaded.")
                    .font(.caption)
                    .foregroundColor(.navy.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $pushEnabled)
                .labelsHidden()
                .tint(.gold)
                .onChange(of: pushEnabled) { _, newValue in
                    notifications.setPushSubscriptionsEnabled(newValue)
                    Task { await handlePushToggleChange(enabled: newValue) }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var summary: some View {
        let total = selectedRebbeim.count + selectedTags.count
        return Text(total == 0
                    ? "No subscriptions selected — you won't receive emails."
                    : "\(total) subscription\(total == 1 ? "" : "s") selected.")
            .font(.caption)
            .foregroundColor(.navy.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }

    private func section(
        title: String,
        options: [String],
        selected: Binding<Set<String>>,
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(title) (\(selected.wrappedValue.count) selected)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                Spacer()
                if !selected.wrappedValue.isEmpty {
                    Button("Clear") { selected.wrappedValue.removeAll() }
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.6))
                }
            }
            if options.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.navy.opacity(0.5))
            } else {
                ChipFlow(spacing: 8) {
                    ForEach(options, id: \.self) { item in
                        SubscriptionChip(label: item, isOn: selected.wrappedValue.contains(item)) {
                            if selected.wrappedValue.contains(item) {
                                selected.wrappedValue.remove(item)
                            } else {
                                selected.wrappedValue.insert(item)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let optionsDoc = try await db.collection("settings").document("shiurOptions").getDocument()
            if let data = optionsDoc.data() {
                rebbeimOptions = (data["rebbeim"] as? [String])?.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } ?? []
                tagsOptions = (data["tags"] as? [String])?.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } ?? []
            }
            if let uid = authManager.user?.uid {
                let subDoc = try await db.collection("subscriptions").document(uid).getDocument()
                if let data = subDoc.data() {
                    selectedRebbeim = Set((data["rebbeim"] as? [String]) ?? [])
                    selectedTags = Set((data["tags"] as? [String]) ?? [])
                }
            }
        } catch {
            statusMessage = "Couldn't load subscriptions."
            statusIsError = true
        }
    }

    private func save() {
        guard let user = authManager.user, let email = user.email else {
            statusMessage = "You must be signed in with an email to subscribe."
            statusIsError = true
            return
        }
        isSaving = true
        statusMessage = nil
        statusIsError = false
        Task {
            do {
                // setData (no merge) matches the website's setDoc — the doc is
                // owned by this page, so a save is the full new state.
                try await db.collection("subscriptions").document(user.uid).setData([
                    "userId": user.uid,
                    "email": email,
                    "rebbeim": Array(selectedRebbeim).sorted(),
                    "tags": Array(selectedTags).sorted(),
                    "updatedAt": ISO8601DateFormatter().string(from: Date())
                ])
                if pushEnabled {
                    notifications.applyPushTopicDiff(desired: desiredPushTopics())
                }
                statusMessage = saveStatusMessage()
                statusIsError = false
            } catch {
                statusMessage = "Couldn't save: \(error.localizedDescription)"
                statusIsError = true
            }
            isSaving = false
        }
    }

    // MARK: - Push topic sync

    /// Topics this view manages when push is on. Only rebbeim get topics for now —
    /// the website's send-notification fan-out uses the rebbe_<sanitized>
    /// convention, and there are no per-tag topics defined yet.
    private func desiredPushTopics() -> Set<String> {
        Set(selectedRebbeim.map { "rebbe_\(NotificationManager.sanitizeTopicName($0))" })
    }

    private func handlePushToggleChange(enabled: Bool) async {
        if enabled {
            // Make sure system permission is granted before subscribing —
            // FCM subscriptions still succeed without it, but iOS won't
            // surface alerts until the user allows them.
            await notifications.checkPermissionStatus()
            if !notifications.hasPermission {
                _ = await notifications.requestPermission()
            }
            notifications.applyPushTopicDiff(desired: desiredPushTopics())
        } else {
            notifications.applyPushTopicDiff(desired: [])
        }
    }

    private func saveStatusMessage() -> String {
        let nothingSelected = selectedRebbeim.isEmpty && selectedTags.isEmpty
        if nothingSelected {
            return "Saved — you won't receive any new shiur emails or alerts."
        }
        return pushEnabled
            ? "Saved — you'll be emailed and alerted on this device when matching shiurim are uploaded."
            : "Saved — you'll be emailed when matching shiurim are uploaded."
    }
}

// MARK: - Chip + Flow Layout

private struct SubscriptionChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(isOn ? .cream : .navy)
                .background(isOn ? Color.navy : Color.cream)
                .overlay(
                    Capsule().stroke(isOn ? Color.clear : Color.gold.opacity(0.4), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapping HStack for chip-style content. Requires iOS 16+.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        EmailSubscriptionsView()
            .environmentObject(AuthManager())
    }
}
