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
