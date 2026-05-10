import Foundation
import SwiftUI
import Combine
import UserNotifications
import UIKit
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

// MARK: - Notification Manager
class NotificationManager: NSObject, ObservableObject {
    @Published var hasPermission = false
    @Published var fcmToken: String?
    
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions from user
    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            await MainActor.run {
                self.hasPermission = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                // Subscribe to default topics
                subscribeToDefaultTopics()
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    /// Check current notification permission status
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.hasPermission = settings.authorizationStatus == .authorized
        }
    }
    
    /// Open app settings for notifications
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Topic Subscriptions
    
    /// Subscribe to default topics for all users
    func subscribeToDefaultTopics() {
        subscribeToTopic("all_users")
        subscribeToTopic("announcements")
        subscribeToTopic("new_shiurim")
        subscribeToTopic("events")
    }

    /// Unsubscribe from topics that were once managed by the old
    /// NotificationPreferencesView but are no longer offered to users.
    /// Idempotent (FCM no-ops when not subscribed) and gated by a
    /// UserDefaults flag so it only runs once per device.
    func cleanupRetiredTopics() {
        let key = "notif_cleanup_v1_done"
        if UserDefaults.standard.bool(forKey: key) { return }
        unsubscribeFromTopic("simchas")
        UserDefaults.standard.set(true, forKey: key)
    }
    
    /// Subscribe to a topic
    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("❌ Error subscribing to \(topic): \(error)")
            } else {
                print("✅ Subscribed to topic: \(topic)")
            }
        }
    }
    
    /// Unsubscribe from a topic
    func unsubscribeFromTopic(_ topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("❌ Error unsubscribing from \(topic): \(error)")
            } else {
                print("✅ Unsubscribed from topic: \(topic)")
            }
        }
    }
    
    // MARK: - Subscription-driven Push Topics
    //
    // The website writes the user's preferences to `subscriptions/{uid}` (the
    // same doc NotificationSettingsView writes). When push mirroring is on
    // (default), we keep this device subscribed to `rebbe_<sanitized>` and
    // `tag_<sanitized>` FCM topics that match the user's picks — so the
    // website's existing /api/send-notification fan-out delivers an alert
    // here too.
    //
    // We diff against the last synced set in UserDefaults so a toggle-off
    // cleanly unsubscribes only the topics this flow added.

    static let pushSubscriptionsEnabledKey = "subscriptions_push_enabled"
    static let pushSubscriptionsTopicsKey = "subscriptions_push_topics"

    /// True if push should mirror the user's email subscriptions. Defaults
    /// to true; only false when the user has explicitly toggled it off.
    var pushSubscriptionsEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.pushSubscriptionsEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.pushSubscriptionsEnabledKey)
    }

    func setPushSubscriptionsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.pushSubscriptionsEnabledKey)
    }

    /// Reads `subscriptions/{uid}` and (if mirroring is enabled) syncs FCM
    /// rebbe_* and tag_* topics to match. Safe to call on every launch +
    /// foreground.
    func syncPushTopicsFromSubscription() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard pushSubscriptionsEnabled else {
            // User opted out — make sure no stale topics from a previous
            // mirror remain subscribed on this device.
            applyPushTopicDiff(desired: [])
            return
        }

        do {
            let doc = try await Firestore.firestore()
                .collection("subscriptions")
                .document(userId)
                .getDocument()
            let data = doc.data() ?? [:]
            let rebbeim = (data["rebbeim"] as? [String]) ?? []
            let tags = (data["tags"] as? [String]) ?? []
            let rebbeTopics = rebbeim.map { "rebbe_\(Self.sanitizeTopicName($0))" }
            let tagTopics = tags.map { "tag_\(Self.sanitizeTopicName($0))" }
            applyPushTopicDiff(desired: Set(rebbeTopics).union(tagTopics))
        } catch {
            print("❌ syncPushTopicsFromSubscription: \(error)")
        }
    }

    /// Subscribe / unsubscribe FCM topics to bring this device into the
    /// desired set. Persists the result so the next call is a minimal diff.
    func applyPushTopicDiff(desired: Set<String>) {
        let previous = Set(UserDefaults.standard.stringArray(forKey: Self.pushSubscriptionsTopicsKey) ?? [])
        for topic in desired.subtracting(previous) {
            subscribeToTopic(topic)
        }
        for topic in previous.subtracting(desired) {
            unsubscribeFromTopic(topic)
        }
        UserDefaults.standard.set(Array(desired), forKey: Self.pushSubscriptionsTopicsKey)
    }

    /// FCM topic sanitization rule (alphanumerics + `_`). Must match the
    /// website's lib/platform.ts equivalent so iOS and web pick the same
    /// topic name for a given rebbe.
    static func sanitizeTopicName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return name.lowercased().unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }

    // MARK: - Token Management
    
    /// Save FCM token to Firestore for the current user
    func saveTokenToFirestore(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "platform": "ios"
            ], merge: true) { error in
                if let error = error {
                    print("❌ Error saving FCM token: \(error)")
                } else {
                    print("✅ FCM token saved to Firestore")
                }
            }
    }
    
    // MARK: - Badge Management
    
    /// Clear app badge
    func clearBadge() {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
    
    // MARK: - Local Notifications (for testing)
    
    /// Schedule a local notification
    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Local notification scheduled")
            }
        }
    }
}

// MARK: - Firebase Messaging Delegate
extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM Token: \(fcmToken ?? "none")")
        
        Task { @MainActor in
            self.fcmToken = fcmToken
        }
        
        // Save token to Firestore
        if let token = fcmToken {
            saveTokenToFirestore(token)
        }
    }
}
