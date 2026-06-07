import Foundation
import FirebaseFirestore
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    /// True when the last `fetchShiurim` call had to fall back to the
    /// on-disk cache because Firestore was unreachable. UI surfaces this as
    /// a small "Offline" banner so users know the list may be stale.
    @Published var isOfflineFallback: Bool = false

    private let db = Firestore.firestore()

    /// In-memory cache of the shiurim list. Populated on first read and
    /// reused for the lifetime of the app process — cleared by relaunching,
    /// or bypassed via fetchShiurim(forceRefresh: true) (pull-to-refresh).
    /// Main-actor isolated so the check-then-write can't race across the two
    /// concurrent call sites (Shiurim tab + Collection detail / pull-to-refresh).
    @MainActor private var cachedShiurim: [Shiur]?

    /// Coalesces concurrent non-forced loads onto a single Firestore round-trip.
    @MainActor private var inFlightFetch: Task<[Shiur], Error>?

    /// Disk path for the offline-mode shiurim cache. Survives relaunch so
    /// the app shows the last-known list when launched without connectivity.
    private var shiurimCacheURL: URL? {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base?.appendingPathComponent("shiurim-cache.json")
    }

    // MARK: - Shiurim
    @MainActor
    func fetchShiurim(forceRefresh: Bool = false) async throws -> [Shiur] {
        if !forceRefresh, let cached = cachedShiurim {
            return cached
        }
        // Join an in-flight load instead of issuing a second identical fetch.
        if !forceRefresh, let inFlight = inFlightFetch {
            return try await inFlight.value
        }

        let task = Task { () throws -> [Shiur] in
            try await self.performFetchShiurim()
        }
        if !forceRefresh { inFlightFetch = task }
        do {
            let result = try await task.value
            inFlightFetch = nil
            return result
        } catch {
            inFlightFetch = nil
            throw error
        }
    }

    @MainActor
    private func performFetchShiurim() async throws -> [Shiur] {
        do {
            let snapshot = try await db.collection("shiurim")
                .order(by: "date", descending: true)
                .getDocuments()

            let shiurim = snapshot.documents.compactMap { Shiur(document: $0) }
            cachedShiurim = shiurim
            persistShiurimToDisk(shiurim)
            isOfflineFallback = false
            return shiurim
        } catch {
            // Network/Firestore failure — fall back to last on-disk snapshot
            // so the user can still browse (and play downloaded) shiurim.
            if let cached = loadShiurimFromDisk() {
                cachedShiurim = cached
                isOfflineFallback = true
                return cached
            }
            throw error
        }
    }

    private func persistShiurimToDisk(_ shiurim: [Shiur]) {
        guard let url = shiurimCacheURL else { return }
        do {
            let data = try JSONEncoder().encode(shiurim)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[firebase] Failed to persist shiurim cache: \(error)")
        }
    }

    /// Decode wrapper that tolerates per-element schema drift: if the Shiur
    /// model changes in a future build, one bad record can't drop the whole
    /// cached list — only the records that fail to decode are skipped.
    private struct FailableShiur: Decodable {
        let value: Shiur?
        init(from decoder: Decoder) throws {
            value = try? Shiur(from: decoder)
        }
    }

    private func loadShiurimFromDisk() -> [Shiur]? {
        guard let url = shiurimCacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        guard let wrapped = try? JSONDecoder().decode([FailableShiur].self, from: data) else { return nil }
        let shiurim = wrapped.compactMap { $0.value }
        // Return nil (not an empty list) so a fully-undecodable cache surfaces
        // the network error rather than showing a blank list.
        return shiurim.isEmpty ? nil : shiurim
    }
    
    func fetchMostRecentShiur() async throws -> Shiur? {
        let snapshot = try await db.collection("shiurim")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { Shiur(document: $0) }
    }
    
    // MARK: - Events
    func fetchEvents() async throws -> [Event] {
        let snapshot = try await db.collection("events")
            .order(by: "date", descending: false)
            .getDocuments()

        return snapshot.documents
            .compactMap { Event(document: $0) }
            .filter { !$0.isExpired }
    }

    func fetchUpcomingEvents(limit eventLimit: Int = 3) async throws -> [Event] {
        let today = formatDateString(Date())

        // Over-fetch so we can drop expired items and still hit eventLimit.
        let snapshot = try await db.collection("events")
            .whereField("date", isGreaterThanOrEqualTo: today)
            .order(by: "date", descending: false)
            .limit(to: eventLimit * 3)
            .getDocuments()

        return snapshot.documents
            .compactMap { Event(document: $0) }
            .filter { !$0.isExpired }
            .prefix(eventLimit)
            .map { $0 }
    }

    // MARK: - Announcements
    func fetchAnnouncements() async throws -> [Announcement] {
        let snapshot = try await db.collection("announcements")
            .whereField("enabled", isEqualTo: true)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents
            .compactMap { Announcement(document: $0) }
            .filter { !$0.isExpired }
    }

    // MARK: - Carousel Images
    func fetchCarouselImages() async throws -> [CarouselImage] {
        let snapshot = try await db.collection("carouselImages")
            .getDocuments()

        let images = snapshot.documents
            .compactMap { CarouselImage(document: $0) }
            .filter { $0.enabled }
        return images.sorted { $0.order < $1.order }
    }
    
    // MARK: - Alumni Photos
    func fetchAlumniPhotos() async throws -> [AlumniPhoto] {
        let snapshot = try await db.collection("alumniPhotos")
            .getDocuments()
        
        let photos = snapshot.documents.compactMap { AlumniPhoto(document: $0) }
        return photos.sorted { $0.order < $1.order }
    }
    
    // MARK: - Alumni Contacts
    func fetchApprovedAlumni() async throws -> [AlumniContact] {
        let snapshot = try await db.collection("alumniContactSubmissions")
            .getDocuments()

        return snapshot.documents
            .filter { ($0.data()["status"] as? String) == "approved" }
            .compactMap { AlumniContact(document: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Rebbeim
    func fetchRebbeim() async throws -> [Rebbe] {
        let snapshot = try await db.collection("rebbeim")
            .getDocuments()
        
        return snapshot.documents.compactMap { Rebbe(document: $0) }
    }
    
    // MARK: - Collections
    func fetchActiveCollection() async throws -> ShiurCollection? {
        let snapshot = try await db.collection("shiurCollections")
            .getDocuments()

        for doc in snapshot.documents {
            if let collection = ShiurCollection(document: doc),
               collection.isActive,
               !collection.isExpired {
                return collection
            }
        }
        return nil
    }

    // MARK: - Featured Shiurim
    // settings/featuredShiur now stores `shiurIds: [String]` (up to 5). Falls
    // back to the legacy single `shiurId: String` for back-compat with the
    // pre-migration document shape.
    func fetchFeaturedShiurim() async throws -> [Shiur] {
        let settingsDoc = try await db.collection("settings").document("featuredShiur").getDocument()

        guard let data = settingsDoc.data(),
              let enabled = data["enabled"] as? Bool, enabled else {
            return []
        }

        let ids: [String]
        if let arr = data["shiurIds"] as? [String], !arr.isEmpty {
            ids = arr.filter { !$0.isEmpty }
        } else if let legacy = data["shiurId"] as? String, !legacy.isEmpty {
            ids = [legacy]
        } else {
            ids = []
        }
        guard !ids.isEmpty else { return [] }

        let shiurim = try await withThrowingTaskGroup(of: (Int, Shiur?).self) { group -> [Shiur] in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    let doc = try await self.db.collection("shiurim").document(id).getDocument()
                    return (index, Shiur(document: doc))
                }
            }
            var results: [(Int, Shiur)] = []
            for try await (index, shiur) in group {
                if let shiur = shiur { results.append((index, shiur)) }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        return shiurim
    }

    // MARK: - System Announcement (site-wide banner)
    func fetchSystemAnnouncement() async throws -> SystemAnnouncement? {
        let doc = try await db.collection("settings").document("systemAnnouncement").getDocument()
        return SystemAnnouncement(document: doc)
    }

    // MARK: - App Update prompt (remote-controlled from the website admin)
    func fetchAppUpdateConfig() async throws -> AppUpdateConfig? {
        let doc = try await db.collection("settings").document("appUpdate").getDocument()
        return AppUpdateConfig(document: doc)
    }
    
    // MARK: - Submissions
    func submitContactInfo(
        name: String,
        email: String?,
        phone: String?,
        location: String,
        submittedBy: String
    ) async throws {
        let data: [String: Any] = [
            "name": name,
            "email": email as Any,
            "phone": phone as Any,
            "location": location,
            "submittedBy": submittedBy,
            "submittedAt": ISO8601DateFormatter().string(from: Date()),
            "status": "pending"
        ]
        
        try await db.collection("alumniContactSubmissions").addDocument(data: data)
    }

    func updateContactInfo(
        documentId: String,
        name: String,
        phone: String?,
        location: String
    ) async throws {
        let data: [String: Any] = [
            "name": name,
            "phone": phone as Any,
            "location": location
        ]

        try await db.collection("alumniContactSubmissions").document(documentId).updateData(data)
    }

    func submitSimcha(
        fullName: String,
        simchaType: String,
        date: Date,
        connection: String?,
        message: String?,
        imageUrl: String?,
        submittedBy: String
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let data: [String: Any] = [
            "fullName": fullName,
            "simchaType": simchaType,
            "date": dateFormatter.string(from: date),
            "connection": connection as Any,
            "message": message as Any,
            "imageUrl": imageUrl as Any,
            "submittedBy": submittedBy,
            "submittedAt": ISO8601DateFormatter().string(from: Date()),
            "status": "new"
        ]
        
        try await db.collection("simchaSubmissions").addDocument(data: data)
    }

    // MARK: - Fundraiser Campaign
    // settings/fundraiserCampaign holds the admin-managed campaign config;
    // campaignSignups holds one doc per alumni page request (same schema the
    // website writes). A per-user marker at users/{uid}/preferences/fundraiserSignup
    // records that this account already created a page (cross-device).
    func fetchFundraiserCampaign() async throws -> FundraiserCampaign? {
        let doc = try await db.collection("settings").document("fundraiserCampaign").getDocument()
        return FundraiserCampaign(document: doc)
    }

    /// Best-effort prefill: the alumnus's name + phone from their contact record
    /// (the same source the website + Profile use). Returns nil if none exists.
    func fetchMyContactInfo(email: String) async -> (name: String, phone: String)? {
        do {
            let snapshot = try await db.collection("alumniContactSubmissions")
                .whereField("email", isEqualTo: email)
                .getDocuments()
            guard let data = snapshot.documents.first?.data() else { return nil }
            return (data["name"] as? String ?? "", data["phone"] as? String ?? "")
        } catch {
            return nil
        }
    }

    /// Whether this account already created a campaign page (used to confirm re-submits).
    func hasSubmittedCampaign(uid: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("preferences").document("fundraiserSignup").getDocument()
            return (doc.data()?["signedUp"] as? Bool) == true
        } catch {
            return false
        }
    }

    func submitCampaignSignup(
        uid: String,
        fullName: String,
        email: String,
        phone: String,
        pageTitle: String,
        goalAmount: String,
        message: String,
        submittedBy: String?,
        campaignName: String
    ) async throws {
        // Match the website's `new Date().toISOString()` (fractional seconds) so
        // submittedAt sorts consistently across web + iOS in the admin list.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let data: [String: Any] = [
            "fullName": fullName,
            "email": email,
            "phone": phone,
            "pageTitle": pageTitle,
            "goalAmount": goalAmount,
            "message": message,
            "submittedBy": submittedBy as Any,
            "submittedAt": iso.string(from: Date()),
            "status": "new"
        ]
        try await db.collection("campaignSignups").addDocument(data: data)

        // Mark this user as having signed up (cross-device; gates the re-submit confirm).
        let now = Date().timeIntervalSince1970 * 1000
        try? await db.collection("users").document(uid)
            .collection("preferences").document("fundraiserSignup")
            .setData(["signedUp": true, "lastSignupAt": now], merge: true)

        // Best-effort office email via the website API (same endpoint the web form uses).
        await notifyCampaignSignup(
            fullName: fullName, email: email, phone: phone, pageTitle: pageTitle,
            goalAmount: goalAmount, message: message, campaignName: campaignName,
            submittedBy: submittedBy ?? ""
        )
    }

    private func notifyCampaignSignup(
        fullName: String, email: String, phone: String, pageTitle: String,
        goalAmount: String, message: String, campaignName: String, submittedBy: String
    ) async {
        guard let url = URL(string: "https://alumni.ytchaim.com/api/send-campaign-signup") else { return }
        let body: [String: Any] = [
            "fullName": fullName, "email": email, "phone": phone, "pageTitle": pageTitle,
            "goalAmount": goalAmount, "message": message, "campaignName": campaignName,
            "submittedBy": submittedBy
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: req)
        } catch {
            print("[campaign] notify failed: \(error)")
        }
    }

    // MARK: - Helper
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
