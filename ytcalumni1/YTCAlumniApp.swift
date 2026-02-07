import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Called when APNs assigns a device token - IMPORTANT: Pass to Firebase
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs Device Token: \(tokenString)")
    }
    
    // Called when registration fails
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 Received notification in foreground: \(userInfo)")
        
        // Show banner and play sound even when app is open
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")
        
        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "new_shiur":
                NotificationCenter.default.post(name: .navigateToShiurim, object: nil)
            case "announcement":
                NotificationCenter.default.post(name: .navigateToHome, object: nil)
            case "event":
                NotificationCenter.default.post(name: .navigateToEvents, object: nil)
            default:
                break
            }
        }
        
        // Clear badge
        Task { @MainActor in
            NotificationManager.shared.clearBadge()
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names for Navigation
extension Notification.Name {
    static let navigateToShiurim = Notification.Name("navigateToShiurim")
    static let navigateToHome = Notification.Name("navigateToHome")
    static let navigateToEvents = Notification.Name("navigateToEvents")
}

// MARK: - Main App
@main
struct YTCAlumniApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(audioPlayer)
                .task {
                    // Request notification permission
                    await NotificationManager.shared.requestPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Clear badge when app opens
                    NotificationManager.shared.clearBadge()
                }
        }
    }
}
