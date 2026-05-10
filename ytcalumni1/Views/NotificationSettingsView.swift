import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Single screen for everything notification-related. Email is the primary
/// subscription model — it mirrors the website's /subscriptions page
/// (reads settings/shiurOptions, writes subscriptions/{uid}). Push is an
/// opt-in mirror of those same picks via FCM topics, plus two global
/// push toggles for "all new shiurim" and "announcements".
///
/// Replaces the previous EmailSubscriptionsView + NotificationPreferencesView,
/// which had overlapping per-rebbe controls.
struct NotificationSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var rebbeimOptions: [String] = []
    @State private var tagsOptions: [String] = []
    @State private var selectedRebbeim: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var rebbeimExpanded = false
    @State private var tagsExpanded = false

    @State private var pushEnabled: Bool = NotificationManager.shared.pushSubscriptionsEnabled
    @State private var allNewShiurimPush: Bool = UserDefaults.standard.object(forKey: allNewShiurimKey) as? Bool ?? true
    @State private var announcementsPush: Bool = UserDefaults.standard.object(forKey: announcementsKey) as? Bool ?? true

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    private static let allNewShiurimKey = "notif_new_shiurim"
    private static let announcementsKey = "notif_announcements"
    private static let allNewShiurimTopic = "new_shiurim"
    private static let announcementsTopic = "announcements"

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
                    if pushEnabled {
                        broadcastTogglesCard
                    }
                    section(
                        title: "Rebbeim",
                        options: rebbeimOptions,
                        selected: $selectedRebbeim,
                        isExpanded: $rebbeimExpanded,
                        emptyText: "No rebbeim available yet."
                    )
                    section(
                        title: "Topics",
                        options: tagsOptions,
                        selected: $selectedTags,
                        isExpanded: $tagsExpanded,
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
        .navigationTitle("Notifications")
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
                Text("Email & Push Notifications")
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
                Text("Get an instant alert on this device for the things you've subscribed to below.")
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
        .background(cardBackground)
        .padding(.horizontal, 16)
    }

    private var broadcastTogglesCard: some View {
        VStack(spacing: 0) {
            broadcastToggle(
                title: "All new shiurim",
                description: "Get notified about every new shiur, not just your picks.",
                icon: "headphones",
                isOn: $allNewShiurimPush,
                topic: Self.allNewShiurimTopic,
                userDefaultsKey: Self.allNewShiurimKey
            )
            Divider().padding(.leading, 52)
            broadcastToggle(
                title: "Announcements",
                description: "Community announcements from the office.",
                icon: "megaphone.fill",
                isOn: $announcementsPush,
                topic: Self.announcementsTopic,
                userDefaultsKey: Self.announcementsKey
            )
        }
        .background(cardBackground)
        .padding(.horizontal, 16)
    }

    private func broadcastToggle(
        title: String,
        description: String,
        icon: String,
        isOn: Binding<Bool>,
        topic: String,
        userDefaultsKey: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.navy.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.gold)
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
                    if newValue {
                        notifications.subscribeToTopic(topic)
                    } else {
                        notifications.unsubscribeFromTopic(topic)
                    }
                }
        }
        .padding(16)
    }

    private var summary: some View {
        let total = selectedRebbeim.count + selectedTags.count
        return Text(total == 0
                    ? "No rebbeim or topics selected — you won't receive emails for matching shiurim."
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
        isExpanded: Binding<Bool>,
        emptyText: String,
        footer: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.navy.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    Text("\(title) (\(selected.wrappedValue.count) selected)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.navy)
                    Spacer()
                    if isExpanded.wrappedValue && !selected.wrappedValue.isEmpty {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.navy.opacity(0.6))
                            .onTapGesture { selected.wrappedValue.removeAll() }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
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
                if let footer {
                    Text(footer)
                        .font(.caption2)
                        .foregroundColor(.navy.opacity(0.5))
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .padding(.horizontal, 16)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
            )
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

    private func desiredPushTopics() -> Set<String> {
        let rebbeTopics = selectedRebbeim.map { "rebbe_\(NotificationManager.sanitizeTopicName($0))" }
        let tagTopics = selectedTags.map { "tag_\(NotificationManager.sanitizeTopicName($0))" }
        return Set(rebbeTopics).union(tagTopics)
    }

    private func handlePushToggleChange(enabled: Bool) async {
        if enabled {
            await notifications.checkPermissionStatus()
            if !notifications.hasPermission {
                _ = await notifications.requestPermission()
            }
            notifications.applyPushTopicDiff(desired: desiredPushTopics())
            // Honor the broadcast toggles when push first comes on
            if allNewShiurimPush { notifications.subscribeToTopic(Self.allNewShiurimTopic) }
            if announcementsPush { notifications.subscribeToTopic(Self.announcementsTopic) }
        } else {
            notifications.applyPushTopicDiff(desired: [])
            notifications.unsubscribeFromTopic(Self.allNewShiurimTopic)
            notifications.unsubscribeFromTopic(Self.announcementsTopic)
        }
    }

    private func saveStatusMessage() -> String {
        let nothingSelected = selectedRebbeim.isEmpty && selectedTags.isEmpty
        if nothingSelected {
            return "Saved — you won't receive any new shiur emails."
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
        NotificationSettingsView()
            .environmentObject(AuthManager())
    }
}
