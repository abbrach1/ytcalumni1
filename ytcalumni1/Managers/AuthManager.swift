import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isApproved: Bool = false
    @Published var isAdmin: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?

    // Last approval source ("alumniDatabase" | "approvedEmails" | nil) — mirrored
    // on the access-request doc and the admin signup email so the admin sees
    // why a new account was auto-approved, matching the web flow.
    private var lastApprovalSource: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let websiteBaseURL = "https://alumni.ytchaim.com"
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                if let user = user, let email = user.email {
                    await self?.checkUserApproval(email: email)
                    // Logs an "/" pageview to the website's tracking API so
                    // this user shows up in the admin Analytics tab as iOS.
                    Task { await AnalyticsService.shared.trackPageView(path: "/") }
                    // Pull subscription doc and mirror to FCM topics, so a
                    // signup the user did on the website reaches this device.
                    Task { await NotificationManager.shared.syncPushTopicsFromSubscription() }
                } else {
                    self?.isApproved = false
                    self?.isAdmin = false
                    self?.userProfile = nil
                }
                self?.isLoading = false
            }
        }
    }
    
    /// Check user approval status - matches the web app logic exactly.
    ///
    /// Reads cached approval from UserDefaults first so the app can render
    /// MainTabView immediately at launch (and stay there if the Firestore
    /// check fails, e.g. no network). Firestore reads then overwrite the
    /// cache so an approval revocation propagates the next time we're online.
    private func checkUserApproval(email: String) async {
        let normalizedEmail = email.lowercased()

        // Seed from the persisted cache so an offline launch doesn't bounce
        // the user to RequestAccessView before the Firestore call resolves.
        let cached = loadCachedApproval(for: normalizedEmail)
        if let cached = cached {
            self.isApproved = cached.approved
            self.isAdmin = cached.admin
            self.lastApprovalSource = cached.source
        }

        var approved = cached?.approved ?? false
        var admin = cached?.admin ?? false
        var approvalSource: String? = cached?.source
        var firestoreReachable = false

        do {
            // 1. Check if email exists in alumniDatabase collection (document ID = email)
            let alumniDoc = try await db.collection("alumniDatabase").document(normalizedEmail).getDocument()
            firestoreReachable = true
            // Reset before re-checking since we're trusting a live read now.
            approved = false
            admin = false
            approvalSource = nil
            if alumniDoc.exists {
                approved = true
                approvalSource = "alumniDatabase"
            }

            // 2. Fallback: Check approvedEmails collection (document ID = email)
            if !approved {
                let approvedDoc = try await db.collection("approvedEmails").document(normalizedEmail).getDocument()
                if approvedDoc.exists {
                    approved = true
                    approvalSource = "approvedEmails"
                }
            }

            // 3. Fallback: Query approvedEmails collection by email field
            if !approved {
                let approvedQuery = try await db.collection("approvedEmails")
                    .whereField("email", isEqualTo: normalizedEmail)
                    .getDocuments()
                if !approvedQuery.documents.isEmpty {
                    approved = true
                    approvalSource = "approvedEmails"
                }
            }
            
            // 4. Check admin status - admins collection (document ID = email)
            let adminDoc = try await db.collection("admins").document(normalizedEmail).getDocument()
            if adminDoc.exists {
                admin = true
            }
            
            // 5. Fallback: Query admins collection by email field
            if !admin {
                let adminQuery = try await db.collection("admins")
                    .whereField("email", isEqualTo: normalizedEmail)
                    .getDocuments()
                if !adminQuery.documents.isEmpty {
                    admin = true
                }
            }
            
        } catch {
            print("Error checking user approval: \(error)")
        }

        // If we never reached Firestore, keep the cached values we seeded
        // earlier — don't downgrade an approved user to "pending" just
        // because the network is down.
        if !firestoreReachable, cached != nil {
            return
        }

        self.isApproved = approved
        self.isAdmin = admin
        self.lastApprovalSource = approvalSource

        // Persist the fresh decision so the next offline launch can trust it.
        saveCachedApproval(
            for: normalizedEmail,
            approved: approved,
            admin: admin,
            source: approvalSource
        )

        // Create a basic user profile
        self.userProfile = UserProfile(
            id: user?.uid ?? "",
            email: normalizedEmail,
            firstName: "",
            lastName: "",
            isApproved: approved,
            isAdmin: admin,
            createdAt: nil
        )
    }
    
    func signIn(email: String, password: String) async throws -> (isApproved: Bool, isAdmin: Bool) {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        if let email = result.user.email {
            await checkUserApproval(email: email)
        }
        
        return (isApproved, isAdmin)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws -> (isApproved: Bool, isAdmin: Bool) {
        isLoading = true
        defer { isLoading = false }

        _ = try await Auth.auth().createUser(withEmail: email, password: password)
        let normalizedEmail = email.lowercased()

        // Check approval status
        await checkUserApproval(email: normalizedEmail)

        let approvalSource = lastApprovalSource

        // Create access request record (same shape as web app's auth-context.tsx
        // signUpWithEmail — keeps the admin Requests/Users tab consistent).
        let fullName = "\(firstName) \(lastName)"
        var accessRequestData: [String: Any] = [
            "email": normalizedEmail,
            "firstName": firstName,
            "lastName": lastName,
            "fullName": fullName,
            "requestedAt": ISO8601DateFormatter().string(from: Date()),
            "status": isApproved ? "approved" : "pending",
            "autoApproved": isApproved
        ]
        if let approvalSource = approvalSource {
            accessRequestData["approvalSource"] = approvalSource
        }

        do {
            try await db.collection("accessRequests").document(normalizedEmail).setData(accessRequestData)
        } catch {
            print("Failed to create access request record: \(error)")
        }

        // Notify admin (Resend → ADMIN_EMAIL). The website triggers this from
        // its client after createUserWithEmailAndPassword; iOS has to do the
        // same or admins never hear about new signups from the iOS app.
        await sendSignupNotification(
            userEmail: normalizedEmail,
            userName: fullName,
            isApproved: isApproved,
            isAdmin: isAdmin,
            approvalSource: approvalSource
        )

        if isApproved {
            await sendWelcomeEmail(email: normalizedEmail, userName: fullName)
        }

        return (isApproved, isAdmin)
    }

    // MARK: - Signup notification + welcome email
    // Endpoints documented in YTC-ALUMNI-MAIN-WEBSITE:
    //   /api/send-signup-notification  — emails admin (Resend, NewSignupEmail)
    //   /api/send-welcome-email        — emails the new user
    private func sendSignupNotification(
        userEmail: String,
        userName: String,
        isApproved: Bool,
        isAdmin: Bool,
        approvalSource: String?
    ) async {
        var body: [String: Any] = [
            "userEmail": userEmail,
            "userName": userName,
            "isApproved": isApproved,
            "isAdmin": isAdmin
        ]
        if let approvalSource = approvalSource {
            body["approvalSource"] = approvalSource
        }
        await postJSON(path: "/api/send-signup-notification", body: body)
    }

    private func sendWelcomeEmail(email: String, userName: String) async {
        await postJSON(path: "/api/send-welcome-email", body: [
            "email": email,
            "userName": userName
        ])
    }

    private func postJSON(path: String, body: [String: Any]) async {
        guard let url = URL(string: websiteBaseURL + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                print("[auth] \(path) returned HTTP \(http.statusCode)")
            }
        } catch {
            print("[auth] \(path) failed: \(error)")
        }
    }
    
    func signOut() {
        do {
            let email = user?.email?.lowercased()
            try Auth.auth().signOut()
            user = nil
            isApproved = false
            isAdmin = false
            userProfile = nil
            // Clear the cached approval so a future sign-in re-checks from scratch.
            if let email = email { clearCachedApproval(for: email) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Offline approval cache
    private struct CachedApproval {
        let approved: Bool
        let admin: Bool
        let source: String?
    }

    private func cacheKey(for email: String) -> String {
        "approval_cache_\(email)"
    }

    private func loadCachedApproval(for email: String) -> CachedApproval? {
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: cacheKey(for: email)) else { return nil }
        let approved = dict["approved"] as? Bool ?? false
        let admin = dict["admin"] as? Bool ?? false
        let source = dict["source"] as? String
        return CachedApproval(approved: approved, admin: admin, source: source)
    }

    private func saveCachedApproval(for email: String, approved: Bool, admin: Bool, source: String?) {
        var dict: [String: Any] = ["approved": approved, "admin": admin]
        if let source = source { dict["source"] = source }
        UserDefaults.standard.set(dict, forKey: cacheKey(for: email))
    }

    private func clearCachedApproval(for email: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: email))
    }
    
    func refreshUserStatus() async {
        guard let email = user?.email else { return }
        await checkUserApproval(email: email)
    }
}

// MARK: - User Profile Model
struct UserProfile: Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let isApproved: Bool
    let isAdmin: Bool
    let createdAt: Date?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        firstName.isEmpty ? email.components(separatedBy: "@").first ?? email : firstName
    }
}
