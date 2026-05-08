import Foundation
import FirebaseAuth
import UIKit

/// Posts analytics events to the YTC Alumni website's tracking API so iOS
/// shows up in the same admin Analytics tab as the web. The server handles
/// the Firestore writes (shiurim/{id}.playCount increment, shiurPlays /
/// shiurDownloads / pageViews collections) and verifies user attribution
/// from the Firebase ID token when present.
///
/// Schema mirrors `lib/track-engagement.ts` and `app/api/track/*` in
/// abbrach1/YTC-ALUMNI-MAIN-WEBSITE.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let baseURL = "https://alumni.ytchaim.com"
    private let platform = "ios" // server's sanitizePlatform allow-list

    private lazy var userAgent: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        let model = UIDevice.current.model
        let osVer = UIDevice.current.systemVersion
        return "YTCAlumniiOS/\(version).\(build) (\(model); iOS \(osVer))"
    }()

    func trackPlay(shiurId: String) async {
        await post(path: "/api/track/play", body: ["shiurId": shiurId])
    }

    func trackDownload(shiurId: String) async {
        await post(path: "/api/track/download", body: ["shiurId": shiurId])
    }

    /// Use web-style paths so events unify across web + native:
    /// "/", "/shiurim", "/shiurim/{id}", "/events", etc.
    func trackPageView(path appPath: String, referrer: String? = nil) async {
        var body: [String: Any] = ["path": appPath]
        if let referrer = referrer { body["referrer"] = referrer }
        await post(path: "/api/track/pageview", body: body)
    }

    private func post(path: String, body: [String: Any]) async {
        guard let url = URL(string: baseURL + path) else { return }

        var fullBody: [String: Any] = body
        fullBody["platform"] = platform
        fullBody["userAgent"] = userAgent

        // Server prefers token-verified user fields, but include body fallbacks
        // so attribution still works if the token call fails.
        var idToken: String?
        if let user = Auth.auth().currentUser {
            fullBody["userId"] = user.uid
            if let email = user.email { fullBody["userEmail"] = email }
            if let name = user.displayName { fullBody["userName"] = name }
            idToken = try? await user.getIDToken()
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let idToken = idToken {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: fullBody)
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                print("[analytics] \(path) returned HTTP \(http.statusCode)")
            }
        } catch {
            print("[analytics] \(path) failed: \(error)")
        }
    }
}
