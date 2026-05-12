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
    private var cachedShiurim: [Shiur]?

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
    func fetchShiurim(forceRefresh: Bool = false) async throws -> [Shiur] {
        if !forceRefresh, let cached = cachedShiurim {
            return cached
        }

        do {
            let snapshot = try await db.collection("shiurim")
                .order(by: "date", descending: true)
                .getDocuments()

            let shiurim = snapshot.documents.compactMap { Shiur(document: $0) }
            cachedShiurim = shiurim
            persistShiurimToDisk(shiurim)
            await MainActor.run { self.isOfflineFallback = false }
            return shiurim
        } catch {
            // Network/Firestore failure — fall back to last on-disk snapshot
            // so the user can still browse (and play downloaded) shiurim.
            if let cached = loadShiurimFromDisk() {
                cachedShiurim = cached
                await MainActor.run { self.isOfflineFallback = true }
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

    private func loadShiurimFromDisk() -> [Shiur]? {
        guard let url = shiurimCacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Shiur].self, from: data)
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
        
        return snapshot.documents.compactMap { Event(document: $0) }
    }
    
    func fetchUpcomingEvents(limit eventLimit: Int = 3) async throws -> [Event] {
        let today = formatDateString(Date())
        
        let snapshot = try await db.collection("events")
            .whereField("date", isGreaterThanOrEqualTo: today)
            .order(by: "date", descending: false)
            .limit(to: eventLimit)
            .getDocuments()
        
        return snapshot.documents.compactMap { Event(document: $0) }
    }
    
    // MARK: - Announcements
    func fetchAnnouncements() async throws -> [Announcement] {
        let snapshot = try await db.collection("announcements")
            .whereField("enabled", isEqualTo: true)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { Announcement(document: $0) }
    }
    
    // MARK: - Carousel Images
    func fetchCarouselImages() async throws -> [CarouselImage] {
        let snapshot = try await db.collection("carouselImages")
            .getDocuments()
        
        let images = snapshot.documents.compactMap { CarouselImage(document: $0) }
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
            if let collection = ShiurCollection(document: doc), collection.isActive {
                return collection
            }
        }
        return nil
    }
    
    // MARK: - Featured Shiur
    func fetchFeaturedShiur() async throws -> Shiur? {
        let settingsDoc = try await db.collection("settings").document("featuredShiur").getDocument()
        
        guard let data = settingsDoc.data(),
              let enabled = data["enabled"] as? Bool, enabled,
              let shiurId = data["shiurId"] as? String else {
            return nil
        }
        
        let shiurDoc = try await db.collection("shiurim").document(shiurId).getDocument()
        return Shiur(document: shiurDoc)
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
    
    // MARK: - Helper
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
