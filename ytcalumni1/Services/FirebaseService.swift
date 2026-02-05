import Foundation
import FirebaseFirestore
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    
    // MARK: - Shiurim
    func fetchShiurim() async throws -> [Shiur] {
        let snapshot = try await db.collection("shiurim")
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { Shiur(document: $0) }
    }
    
    func fetchMostRecentShiur() async throws -> Shiur? {
        let snapshot = try await db.collection("shiurim")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { Shiur(document: $0) }
    }
    
    func incrementPlayCount(shiurId: String) async throws {
        try await db.collection("shiurim").document(shiurId).updateData([
            "playCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func incrementDownloadCount(shiurId: String) async throws {
        try await db.collection("shiurim").document(shiurId).updateData([
            "downloadCount": FieldValue.increment(Int64(1))
        ])
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
