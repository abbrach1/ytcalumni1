import Foundation
import FirebaseFirestore

// MARK: - Expiry helper
// Mirrors lib/expiry.ts on the website: admin sets `hideAfterDays` and the
// service captures `timerStartAt` on first save. Item hides when now >=
// timerStartAt + hideAfterDays.
enum Expiry {
    private static let dayMs: Double = 24 * 60 * 60 * 1000

    // JS `new Date().toISOString()` always includes fractional seconds
    // ("...T15:14:52.123Z"), but be defensive and accept either format.
    private static let isoWithMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoMs = ISO8601DateFormatter()

    private static func parseISO(_ s: String) -> Date? {
        isoWithMs.date(from: s) ?? isoNoMs.date(from: s)
    }

    static func expiryAt(hideAfterDays: Int?, timerStartAt: String?) -> Double? {
        guard let days = hideAfterDays, days > 0,
              let startStr = timerStartAt,
              let startDate = parseISO(startStr) else { return nil }
        return startDate.timeIntervalSince1970 * 1000 + Double(days) * dayMs
    }

    static func isExpired(hideAfterDays: Int?, timerStartAt: String?, now: Double = Date().timeIntervalSince1970 * 1000) -> Bool {
        guard let expiresAt = expiryAt(hideAfterDays: hideAfterDays, timerStartAt: timerStartAt) else { return false }
        return now >= expiresAt
    }

    static func isExpired(_ data: [String: Any], now: Double = Date().timeIntervalSince1970 * 1000) -> Bool {
        let days = data["hideAfterDays"] as? Int
        let start = data["timerStartAt"] as? String
        return isExpired(hideAfterDays: days, timerStartAt: start, now: now)
    }
}

// MARK: - Shiur Model
struct Shiur: Identifiable, Hashable, Codable {
    var id: String?
    let title: String
    let rebbe: String
    let date: String  // Stored as string like "2024-01-15"
    let tags: [String]
    let audioUrl: String?
    let pdfUrl: String?
    let description: String?
    let playCount: Int?
    let downloadCount: Int?
    let series: String?
    
    var formattedDate: String {
        // Parse the date string and format it nicely
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .long
            return outputFormatter.string(from: date)
        }
        return date
    }
    
    var shortDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        return date
    }
    
    init(id: String?, title: String, rebbe: String, date: String, tags: [String], audioUrl: String?, pdfUrl: String?, description: String?, playCount: Int?, downloadCount: Int?, series: String?) {
        self.id = id
        self.title = title
        self.rebbe = rebbe
        self.date = date
        self.tags = tags
        self.audioUrl = audioUrl
        self.pdfUrl = pdfUrl
        self.description = description
        self.playCount = playCount
        self.downloadCount = downloadCount
        self.series = series
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.rebbe = data["rebbe"] as? String ?? ""
        self.date = data["date"] as? String ?? ""
        self.tags = data["tags"] as? [String] ?? []
        self.audioUrl = data["audioUrl"] as? String
        self.pdfUrl = data["pdfUrl"] as? String
        self.description = data["description"] as? String
        self.playCount = data["playCount"] as? Int
        self.downloadCount = data["downloadCount"] as? Int
        self.series = data["series"] as? String
    }
}

// MARK: - Event Model
struct Event: Identifiable, Hashable {
    var id: String?
    let eventName: String
    let personFamily: String
    let type: String
    let date: String  // Stored as string like "2024-01-15"
    let location: String
    let time: String?
    let imageUrl: String?
    let description: String?
    let hideAfterDays: Int?
    let timerStartAt: String?

    var isExpired: Bool {
        Expiry.isExpired(hideAfterDays: hideAfterDays, timerStartAt: timerStartAt)
    }
    
    var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .long
            return outputFormatter.string(from: date)
        }
        return date
    }
    
    var dayNumber: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "d"
            return outputFormatter.string(from: date)
        }
        return ""
    }
    
    var monthAbbreviation: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM"
            return outputFormatter.string(from: date).uppercased()
        }
        return ""
    }
    
    var isPast: Bool {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let eventDate = inputFormatter.date(from: date) {
            return eventDate < Date()
        }
        return false
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.eventName = data["eventName"] as? String ?? ""
        self.personFamily = data["personFamily"] as? String ?? ""
        self.type = data["type"] as? String ?? ""
        self.date = data["date"] as? String ?? ""
        self.location = data["location"] as? String ?? ""
        self.time = data["time"] as? String
        self.imageUrl = data["imageUrl"] as? String
        self.description = data["description"] as? String
        self.hideAfterDays = data["hideAfterDays"] as? Int
        self.timerStartAt = data["timerStartAt"] as? String
    }
}

// MARK: - Announcement Model
struct Announcement: Identifiable, Hashable {
    var id: String?
    let title: String
    let content: String
    let type: String  // "mazel_tov" or "announcement"
    let date: String
    let enabled: Bool
    let hideAfterDays: Int?
    let timerStartAt: String?

    var isMazelTov: Bool {
        type == "mazel_tov"
    }

    var isExpired: Bool {
        Expiry.isExpired(hideAfterDays: hideAfterDays, timerStartAt: timerStartAt)
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.content = data["content"] as? String ?? ""
        self.type = data["type"] as? String ?? "announcement"
        self.date = data["date"] as? String ?? ""
        self.enabled = data["enabled"] as? Bool ?? false
        self.hideAfterDays = data["hideAfterDays"] as? Int
        self.timerStartAt = data["timerStartAt"] as? String
    }
}

// MARK: - Carousel Image Model
struct CarouselImage: Identifiable, Hashable {
    var id: String?
    let url: String
    let caption: String?
    let order: Int
    let enabled: Bool

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.url = data["url"] as? String ?? ""
        self.caption = data["caption"] as? String
        self.order = data["order"] as? Int ?? 0
        // Treat missing `enabled` as enabled (back-compat with images created
        // before the toggle existed — matches website behavior).
        self.enabled = (data["enabled"] as? Bool) ?? true
    }
}

// MARK: - Alumni Photo Model
struct AlumniPhoto: Identifiable, Hashable {
    var id: String?
    let url: String
    let caption: String?
    let name: String?
    let year: String?
    let order: Int
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.url = data["url"] as? String ?? ""
        self.caption = data["caption"] as? String
        self.name = data["name"] as? String
        self.year = data["year"] as? String
        self.order = data["order"] as? Int ?? 0
    }
}

// MARK: - Alumni Contact Model
struct AlumniContact: Identifiable, Hashable {
    var id: String?
    let name: String
    let email: String?
    let phone: String?
    let location: String
    let submittedAt: String?

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.email = data["email"] as? String
        self.phone = data["phone"] as? String
        self.location = data["location"] as? String ?? ""
        self.submittedAt = data["submittedAt"] as? String
    }
}

// MARK: - Rebbe Model
struct Rebbe: Identifiable, Hashable {
    var id: String?
    let name: String
    let title: String
    let email: String?
    let phone: String?
    let photoUrl: String?
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.email = data["email"] as? String
        self.phone = data["phone"] as? String
        self.photoUrl = data["photoUrl"] as? String
    }
}

// MARK: - Shiur Collection Model
struct ShiurCollection: Identifiable {
    var id: String?
    let name: String
    let description: String
    let isActive: Bool
    let shiurIds: [String]?
    let hideAfterDays: Int?
    let timerStartAt: String?

    var isExpired: Bool {
        Expiry.isExpired(hideAfterDays: hideAfterDays, timerStartAt: timerStartAt)
    }

    init(id: String?, name: String, description: String, isActive: Bool, shiurIds: [String]?, hideAfterDays: Int? = nil, timerStartAt: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isActive = isActive
        self.shiurIds = shiurIds
        self.hideAfterDays = hideAfterDays
        self.timerStartAt = timerStartAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.isActive = data["isActive"] as? Bool ?? false
        self.shiurIds = data["shiurIds"] as? [String]
        self.hideAfterDays = data["hideAfterDays"] as? Int
        self.timerStartAt = data["timerStartAt"] as? String
    }
}

// MARK: - System Announcement (settings/systemAnnouncement)
// Site-wide banner editable from the admin settings page. Shown above the
// Mazel Tovs & Announcements section on the home page. Respects the same
// hideAfterDays/timerStartAt auto-hide timer as other expirable content.
struct SystemAnnouncement {
    let title: String
    let message: String
    let linkUrl: String
    let linkText: String

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let enabled = data["enabled"] as? Bool, enabled,
              let message = data["message"] as? String, !message.isEmpty,
              !Expiry.isExpired(data) else { return nil }

        self.title = data["title"] as? String ?? ""
        self.message = message
        self.linkUrl = data["linkUrl"] as? String ?? ""
        self.linkText = data["linkText"] as? String ?? ""
    }
}
