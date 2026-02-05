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
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
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
                } else {
                    self?.isApproved = false
                    self?.isAdmin = false
                    self?.userProfile = nil
                }
                self?.isLoading = false
            }
        }
    }
    
    /// Check user approval status - matches the web app logic exactly
    private func checkUserApproval(email: String) async {
        let normalizedEmail = email.lowercased()
        var approved = false
        var admin = false
        
        do {
            // 1. Check if email exists in alumniDatabase collection (document ID = email)
            let alumniDoc = try await db.collection("alumniDatabase").document(normalizedEmail).getDocument()
            if alumniDoc.exists {
                approved = true
            }
            
            // 2. Fallback: Check approvedEmails collection (document ID = email)
            if !approved {
                let approvedDoc = try await db.collection("approvedEmails").document(normalizedEmail).getDocument()
                if approvedDoc.exists {
                    approved = true
                }
            }
            
            // 3. Fallback: Query approvedEmails collection by email field
            if !approved {
                let approvedQuery = try await db.collection("approvedEmails")
                    .whereField("email", isEqualTo: normalizedEmail)
                    .getDocuments()
                if !approvedQuery.documents.isEmpty {
                    approved = true
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
        
        self.isApproved = approved
        self.isAdmin = admin
        
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
        
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let normalizedEmail = email.lowercased()
        
        // Check approval status
        await checkUserApproval(email: normalizedEmail)
        
        // Create access request record (same as web app)
        let fullName = "\(firstName) \(lastName)"
        let accessRequestData: [String: Any] = [
            "email": normalizedEmail,
            "firstName": firstName,
            "lastName": lastName,
            "fullName": fullName,
            "requestedAt": ISO8601DateFormatter().string(from: Date()),
            "status": isApproved ? "approved" : "pending",
            "autoApproved": isApproved
        ]
        
        try? await db.collection("accessRequests").document(normalizedEmail).setData(accessRequestData)
        
        return (isApproved, isAdmin)
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            isApproved = false
            isAdmin = false
            userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
