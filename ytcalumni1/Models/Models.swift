import Foundation
import FirebaseFirestore

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
    
    var isMazelTov: Bool {
        type == "mazel_tov"
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.content = data["content"] as? String ?? ""
        self.type = data["type"] as? String ?? "announcement"
        self.date = data["date"] as? String ?? ""
        self.enabled = data["enabled"] as? Bool ?? false
    }
}

// MARK: - Carousel Image Model
struct CarouselImage: Identifiable, Hashable {
    var id: String?
    let url: String
    let caption: String?
    let order: Int
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.url = data["url"] as? String ?? ""
        self.caption = data["caption"] as? String
        self.order = data["order"] as? Int ?? 0
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
    
    init(id: String?, name: String, description: String, isActive: Bool, shiurIds: [String]?) {
        self.id = id
        self.name = name
        self.description = description
        self.isActive = isActive
        self.shiurIds = shiurIds
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.isActive = data["isActive"] as? Bool ?? false
        self.shiurIds = data["shiurIds"] as? [String]
    }
}
