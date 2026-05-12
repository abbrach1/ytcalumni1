import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    @State private var carouselImages: [CarouselImage] = []
    @State private var announcements: [Announcement] = []
    @State private var upcomingEvents: [Event] = []
    @State private var mostRecentShiur: Shiur?
    @State private var featuredShiur: Shiur?
    @State private var alumniPhotos: [AlumniPhoto] = []
    @State private var activeCollection: ShiurCollection?
    @State private var isLoading = true
    @State private var currentCarouselIndex = 0
    @State private var selectedPhoto: AlumniPhoto?
    @State private var showAnnouncementsExpanded = false
    @State private var showNotificationSettings = false
    @State private var showDownloads = false
    @State private var playbackPositions: [String: Double] = [:]
    
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header with carousel
                headerSection
                
                // Main content - wrapped in a fixed container
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Announcements
                    if !announcements.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Announcements", icon: "megaphone.fill")
                            
                            ForEach(showAnnouncementsExpanded ? announcements : Array(announcements.prefix(3))) { announcement in
                                AnnouncementCard(announcement: announcement)
                            }
                            
                            if announcements.count > 3 {
                                Button(action: {
                                    withAnimation {
                                        showAnnouncementsExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(showAnnouncementsExpanded ? "Show Less" : "Show All (\(announcements.count))")
                                        Image(systemName: showAnnouncementsExpanded ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.gold)
                                }
                            }
                        }
                    }
                    
                    // Featured Collection
                    if let collection = activeCollection {
                        collectionSection(collection)
                    }
                    
                    // Featured/Most Recent Shiur
                    if let featured = featuredShiur {
                        shiurSection(featured, isFeatured: true)
                    }
                    
                    // Show most recent if it's different from featured (or no featured)
                    if let recent = mostRecentShiur, recent.id != featuredShiur?.id {
                        shiurSection(recent, isFeatured: false)
                    }
                    
                    // Alumni Spotlight
                    if !alumniPhotos.isEmpty {
                        alumniSpotlightSection
                    }

                    // Upcoming Simchos (next 2)
                    if !upcomingEvents.isEmpty {
                        upcomingEventsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarHidden(true)
        .task {
            await loadData()
        }
        .sheet(item: $selectedPhoto) { photo in
            AlumniPhotoDetailView(photo: photo)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NavigationStack {
                NotificationSettingsView()
            }
        }
        .sheet(isPresented: $showDownloads) {
            NavigationStack {
                DownloadsView()
            }
        }
    }
    
    // MARK: - Content Section (keeping for reference but not using)
    private var contentSection: some View {
        EmptyView()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Carousel or gradient background
            if !carouselImages.isEmpty {
                TabView(selection: $currentCarouselIndex) {
                    ForEach(Array(carouselImages.enumerated()), id: \.element.id) { index, image in
                        AsyncImage(url: URL(string: image.url)) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Color.navy
                            default:
                                Color.navy.opacity(0.5)
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onReceive(timer) { _ in
                    withAnimation(.easeInOut(duration: 0.8)) {
                        currentCarouselIndex = (currentCarouselIndex + 1) % max(carouselImages.count, 1)
                    }
                }
            } else {
                LinearGradient(
                    colors: [Color.navy, Color.navyLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Overlay gradient for text readability
            LinearGradient(
                colors: [.clear, .clear, Color.navy.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Profile menu button in top right
            VStack {
                HStack {
                    Spacer()
                    Menu {
                        Button(action: { showNotificationSettings = true }) {
                            Label("Notifications", systemImage: "bell.fill")
                        }
                        Button(action: { showDownloads = true }) {
                            Label("Downloads", systemImage: "arrow.down.circle.fill")
                        }
                        if authManager.isAdmin {
                            Button(action: {}) {
                                Label("Admin Dashboard", systemImage: "gearshape.fill")
                            }
                        }
                        Button(role: .destructive, action: { authManager.signOut() }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 50) // Account for status bar
                }
                Spacer()
            }
            
            // Title overlay
            VStack(spacing: 12) {
                // Decorative line
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 50, height: 3)
                
                Text("Yeshiva Toras Chaim")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("ALUMNI NETWORK")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gold)
                    .tracking(4)
                
                // Decorative line
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 50, height: 3)
            }
            .padding(.bottom, 40)
        }
        .frame(height: 350)
        .frame(maxWidth: .infinity)
        .clipped()
    }
    
    // MARK: - Announcements Section
    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Announcements", icon: "megaphone.fill")
            
            VStack(spacing: 12) {
                ForEach(showAnnouncementsExpanded ? announcements : Array(announcements.prefix(3))) { announcement in
                    AnnouncementCard(announcement: announcement)
                }
                
                if announcements.count > 3 {
                    Button(action: {
                        withAnimation {
                            showAnnouncementsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(showAnnouncementsExpanded ? "Show Less" : "Show All (\(announcements.count))")
                            Image(systemName: showAnnouncementsExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.gold)
                    }
                }
            }
        }
    }
    
    // MARK: - Collection Section
    private func collectionSection(_ collection: ShiurCollection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: collection.name, icon: "folder.fill")
            
            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(collection.description)
                            .font(.body)
                            .foregroundColor(.navy.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text("View Collection →")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.gold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.navy.opacity(0.4))
                }
                .padding(20)
                .cardStyle()
            }
        }
    }
    
    // MARK: - Upcoming Events Section
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Upcoming Simchos", icon: "party.popper.fill")

                Spacer()

                NavigationLink(destination: EventsView()) {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.gold)
                }
            }

            VStack(spacing: 12) {
                ForEach(upcomingEvents.prefix(2)) { event in
                    EventCard(event: event)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Shiur Section
    private func shiurSection(_ shiur: Shiur, isFeatured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: isFeatured ? "Featured Shiur" : "Most Recent Shiur",
                icon: "headphones"
            )
            
            // Inline shiur card with full-width play button
            VStack(alignment: .leading, spacing: 16) {
                // Title and Rebbe
                VStack(alignment: .leading, spacing: 6) {
                    Text(shiur.title)
                        .font(.headline)
                        .foregroundColor(.navy)
                    
                    Text(shiur.rebbe)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                }
                
                // Date
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.gold)
                        .font(.caption)
                    
                    Text(shiur.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                }
                
                // Tags
                if !shiur.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(shiur.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.gold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gold.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Saved position indicator
                if let shiurId = shiur.id, getSavedPosition(for: shiurId) > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.gold)
                        Text("Resume from \(formatTime(getSavedPosition(for: shiurId)))")
                            .font(.caption)
                            .foregroundColor(.navy.opacity(0.7))
                    }
                }
                
                // Full-width Play button
                if shiur.audioUrl != nil {
                    Button(action: {
                        if audioPlayer.currentShiur?.id == shiur.id {
                            audioPlayer.togglePlayPause()
                        } else {
                            Task {
                                await audioPlayer.play(shiur: shiur)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: audioPlayer.currentShiur?.id == shiur.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            
                            // Show "Resume" if there's a saved position
                            if let shiurId = shiur.id,
                               getSavedPosition(for: shiurId) > 0,
                               audioPlayer.currentShiur?.id != shiur.id {
                                Text("Resume")
                                    .font(.subheadline.weight(.semibold))
                            } else {
                                Text(audioPlayer.currentShiur?.id == shiur.id && audioPlayer.isPlaying ? "Pause" : "Play")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundColor(.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.navy)
                        .cornerRadius(10)
                    }
                }
                
                // Browse all button
                NavigationLink(destination: ShiurimView()) {
                    HStack {
                        Text("Browse All Shiurim")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.navy)
                    .cornerRadius(10)
                }
            }
            .padding(20)
            .cardStyle()
        }
    }
    
    // MARK: - Alumni Spotlight Section
    private var alumniSpotlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Alumni Spotlight", icon: "person.2.fill")
            
            // 2x2 grid layout with equal width
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(alumniPhotos.prefix(4)) { photo in
                    AlumniPhotoCard(photo: photo)
                        .onTapGesture { selectedPhoto = photo }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        
        do {
            // Load all data
            carouselImages = try await FirebaseService.shared.fetchCarouselImages()
            announcements = try await FirebaseService.shared.fetchAnnouncements()
            upcomingEvents = try await FirebaseService.shared.fetchUpcomingEvents()
            mostRecentShiur = try await FirebaseService.shared.fetchMostRecentShiur()
            featuredShiur = try await FirebaseService.shared.fetchFeaturedShiur()
            alumniPhotos = try await FirebaseService.shared.fetchAlumniPhotos()
            activeCollection = try await FirebaseService.shared.fetchActiveCollection()
            
            // Load playback positions from Firebase
            await loadPlaybackPositions()
            
            print("✅ Loaded: \(carouselImages.count) carousel, \(announcements.count) announcements, \(upcomingEvents.count) events, shiur: \(mostRecentShiur?.title ?? "none"), \(alumniPhotos.count) photos")
        } catch {
            print("❌ Error loading home data: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadPlaybackPositions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Website structure: users/{uid}/preferences/playbackPositions with positions map
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("preferences")
                .document("playbackPositions")
                .getDocument()
            
            if let data = doc.data(),
               let positions = data["positions"] as? [String: Any] {
                var result: [String: Double] = [:]
                for (key, value) in positions {
                    if let position = value as? Double {
                        result[key] = position
                        // Update local cache
                        UserDefaults.standard.set(position, forKey: "playback_position_\(key)")
                    }
                }
                playbackPositions = result
                print("✅ HomeView: Loaded \(result.count) playback positions from Firebase")
            }
        } catch {
            print("Error loading playback positions: \(error)")
        }
    }
    
    private func getSavedPosition(for shiurId: String) -> TimeInterval {
        return playbackPositions[shiurId] ?? 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.gold)
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(.navy)
        }
    }
}

struct CarouselImageView: View {
    let url: String
    
    var body: some View {
        Color.clear
            .overlay(
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.navy
                    default:
                        Color.navy.opacity(0.5)
                            .overlay(ProgressView().tint(.white))
                    }
                }
            )
            .clipped()
    }
}

struct AnnouncementCard: View {
    let announcement: Announcement
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: announcement.isMazelTov ? "party.popper.fill" : "megaphone.fill")
                .foregroundColor(.gold)
                .frame(width: 32, height: 32)
                .background(Color.gold.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(announcement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.navy)
                
                Text(announcement.content)
                    .font(.caption)
                    .foregroundColor(.navy.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct EventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date badge at top
            HStack {
                VStack(spacing: 0) {
                    Text(event.monthAbbreviation)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.cream.opacity(0.8))
                    Text(event.dayNumber)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.cream)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.navy)
                .cornerRadius(8)
                
                Spacer()
                
                Text(event.type)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gold.opacity(0.15))
                    .cornerRadius(4)
            }
            .padding(12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(event.eventName)
                    .font(.headline)
                    .foregroundColor(.navy)
                    .lineLimit(2)
                
                Text(event.personFamily)
                    .font(.subheadline)
                    .foregroundColor(.navy.opacity(0.7))
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundColor(.gold)
                    Text(event.location)
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .cardStyle()
    }
}

struct AlumniPhotoCard: View {
    let photo: AlumniPhoto
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo
            AsyncImage(url: URL(string: photo.url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.navy.opacity(0.2)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.navy.opacity(0.3))
                        )
                default:
                    Color.navy.opacity(0.1)
                        .overlay(ProgressView())
                }
            }
            .frame(height: 90)
            .clipped()
            
            // Info - only show if there's actual data
            if (photo.name != nil && !photo.name!.isEmpty) || (photo.year != nil && !photo.year!.isEmpty) {
                VStack(alignment: .leading, spacing: 2) {
                    if let name = photo.name, !name.isEmpty {
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.navy)
                            .lineLimit(1)
                    }
                    if let year = photo.year, !year.isEmpty {
                        Text("Class of \(year)")
                            .font(.caption2)
                            .foregroundColor(.gold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

struct AlumniPhotoDetailView: View {
    let photo: AlumniPhoto
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: photo.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Color.navy.opacity(0.2)
                                .frame(height: 300)
                        default:
                            Color.navy.opacity(0.1)
                                .frame(height: 300)
                                .overlay(ProgressView())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let name = photo.name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(.navy)
                        }
                        
                        if let year = photo.year, !year.isEmpty {
                            Text("Class of \(year)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.gold)
                        }
                        
                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.body)
                                .foregroundColor(.navy.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
            }
            .background(Color.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.navy)
                }
            }
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthManager())
            .environmentObject(AudioPlayerManager())
    }
}
