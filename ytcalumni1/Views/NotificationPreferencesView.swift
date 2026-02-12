import SwiftUI
import FirebaseFirestore

struct NotificationPreferencesView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var rebbeim: [Rebbe] = []
    @State private var isLoading = true

    // Global toggles
    @State private var newShiurimEnabled = true
    @State private var simchasEnabled = true
    @State private var announcementsEnabled = true

    // Per-rebbe toggles keyed by sanitized rebbe name
    @State private var rebbeToggles: [String: Bool] = [:]

    private let notificationManager = NotificationManager.shared

    var body: some View {
        List {
            // General section
            Section {
                Toggle(isOn: $announcementsEnabled) {
                    Label("Announcements", systemImage: "megaphone.fill")
                        .foregroundColor(.navy)
                }
                .tint(.gold)
                .onChange(of: announcementsEnabled) { _, newValue in
                    toggleTopic("announcements", enabled: newValue)
                }

                Toggle(isOn: $simchasEnabled) {
                    Label("Simchas & Mazel Tovs", systemImage: "party.popper.fill")
                        .foregroundColor(.navy)
                }
                .tint(.gold)
                .onChange(of: simchasEnabled) { _, newValue in
                    toggleTopic("simchas", enabled: newValue)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Get notified about community announcements and simchas.")
            }

            // Shiurim section
            Section {
                Toggle(isOn: $newShiurimEnabled) {
                    Label("All New Shiurim", systemImage: "headphones")
                        .foregroundColor(.navy)
                }
                .tint(.gold)
                .onChange(of: newShiurimEnabled) { _, newValue in
                    toggleTopic("new_shiurim", enabled: newValue)
                }
            } header: {
                Text("Shiurim")
            } footer: {
                Text("Get notified when any new shiur is uploaded. You can also choose specific Rebbeim below.")
            }

            // Per-rebbe section
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if rebbeim.isEmpty {
                    Text("No Rebbeim available yet.")
                        .foregroundColor(.navy.opacity(0.5))
                } else {
                    ForEach(rebbeim) { rebbe in
                        let topicKey = sanitizeTopicName(rebbe.name)
                        Toggle(isOn: Binding(
                            get: { rebbeToggles[topicKey] ?? false },
                            set: { newValue in
                                rebbeToggles[topicKey] = newValue
                                toggleTopic("rebbe_\(topicKey)", enabled: newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rebbe.name)
                                    .foregroundColor(.navy)
                                Text(rebbe.title)
                                    .font(.caption)
                                    .foregroundColor(.navy.opacity(0.6))
                            }
                        }
                        .tint(.gold)
                    }
                }
            } header: {
                Text("Notify by Rebbe")
            } footer: {
                Text("Get notified when a specific Rebbe's shiur is uploaded.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.cream)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(.navy)
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Load rebbeim
        do {
            rebbeim = try await FirebaseService.shared.fetchRebbeim()
        } catch {
            print("Error loading rebbeim: \(error)")
        }

        // Load saved preferences from UserDefaults
        newShiurimEnabled = UserDefaults.standard.object(forKey: "notif_new_shiurim") as? Bool ?? true
        simchasEnabled = UserDefaults.standard.object(forKey: "notif_simchas") as? Bool ?? true
        announcementsEnabled = UserDefaults.standard.object(forKey: "notif_announcements") as? Bool ?? true

        for rebbe in rebbeim {
            let key = sanitizeTopicName(rebbe.name)
            rebbeToggles[key] = UserDefaults.standard.object(forKey: "notif_rebbe_\(key)") as? Bool ?? false
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func toggleTopic(_ topic: String, enabled: Bool) {
        if enabled {
            notificationManager.subscribeToTopic(topic)
        } else {
            notificationManager.unsubscribeFromTopic(topic)
        }
        // Persist locally
        UserDefaults.standard.set(enabled, forKey: "notif_\(topic)")
    }

    /// Sanitize a rebbe name into a valid FCM topic name (alphanumeric + underscores)
    private func sanitizeTopicName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return name
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }
}

#Preview {
    NavigationStack {
        NotificationPreferencesView()
            .environmentObject(AuthManager())
    }
}
