import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ShiurimView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var shiurim: [Shiur] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedRebbeFilter: String?
    @State private var selectedTagFilter: String?
    @State private var selectedSeriesFilter: String?
    @State private var showSavedOnly = false
    @State private var showInProgressOnly = false
    @State private var showDownloadedOnly = false
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showFilters = false
    @State private var savedShiurimIds: Set<String> = []
    @State private var playbackPositions: [String: Double] = [:]
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case titleAZ = "Title A-Z"
        case rebbeAZ = "Rebbe A-Z"
    }
    
    private var allRebbeim: [String] {
        Array(Set(shiurim.map { $0.rebbe })).sorted()
    }
    
    private var allTags: [String] {
        Array(Set(shiurim.flatMap { $0.tags })).sorted()
    }
    
    private var allSeries: [String] {
        Array(Set(shiurim.compactMap { $0.series })).sorted()
    }
    
    private var filteredShiurim: [Shiur] {
        // When showing downloads only, fall back to the manifest so the list
        // is still populated when the network fetch hasn't returned yet
        // (or fails entirely while offline).
        var result: [Shiur]
        if showDownloadedOnly && shiurim.isEmpty {
            result = downloadManager.downloads.values.map { $0.shiur }
        } else {
            result = shiurim
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { shiur in
                shiur.title.localizedCaseInsensitiveContains(searchText) ||
                shiur.rebbe.localizedCaseInsensitiveContains(searchText) ||
                shiur.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (shiur.series?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Rebbe filter
        if let rebbe = selectedRebbeFilter {
            result = result.filter { $0.rebbe == rebbe }
        }

        // Tag filter
        if let tag = selectedTagFilter {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Series filter
        if let series = selectedSeriesFilter {
            result = result.filter { $0.series == series }
        }

        // Saved filter
        if showSavedOnly {
            result = result.filter { shiur in
                guard let id = shiur.id else { return false }
                return savedShiurimIds.contains(id)
            }
        }

        // In Progress filter
        if showInProgressOnly {
            result = result.filter { shiur in
                guard let id = shiur.id else { return false }
                return (playbackPositions[id] ?? 0) > 0
            }
        }

        // Downloaded filter
        if showDownloadedOnly {
            result = result.filter { shiur in
                guard let id = shiur.id else { return false }
                return downloadManager.isDownloaded(id)
            }
        }
        
        // Sorting
        switch sortOrder {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .titleAZ:
            result.sort { $0.title < $1.title }
        case .rebbeAZ:
            result.sort { $0.rebbe < $1.rebbe }
        }
        
        return result
    }
    
    private var hasActiveFilters: Bool {
        selectedRebbeFilter != nil || selectedTagFilter != nil || selectedSeriesFilter != nil || showSavedOnly || showInProgressOnly || showDownloadedOnly
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedRebbeFilter != nil { count += 1 }
        if selectedTagFilter != nil { count += 1 }
        if selectedSeriesFilter != nil { count += 1 }
        if showSavedOnly { count += 1 }
        if showInProgressOnly { count += 1 }
        if showDownloadedOnly { count += 1 }
        return count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                // Title
                Text("Shiurim")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.cream)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Search bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.navy.opacity(0.4))
                        TextField("Search by title, rebbe, or topic...", text: $searchText)
                            .foregroundColor(.navy)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.navy.opacity(0.4))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // Filter button with badge
                    Button(action: { showFilters.toggle() }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title3)
                                .foregroundColor(.cream)
                                .padding(10)
                                .background(Color.cream.opacity(0.2))
                                .cornerRadius(10)
                            
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.navy)
                                    .padding(4)
                                    .background(Color.gold)
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                
                // Quick filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Saved filter
                        QuickFilterChip(
                            title: "Saved",
                            icon: "bookmark.fill",
                            isSelected: showSavedOnly
                        ) {
                            showSavedOnly.toggle()
                            if showSavedOnly { showInProgressOnly = false }
                        }
                        
                        // In Progress filter
                        QuickFilterChip(
                            title: "In Progress",
                            icon: "clock.fill",
                            isSelected: showInProgressOnly
                        ) {
                            showInProgressOnly.toggle()
                            if showInProgressOnly { showSavedOnly = false }
                        }

                        // Downloaded filter
                        QuickFilterChip(
                            title: "Downloaded",
                            icon: "arrow.down.circle.fill",
                            isSelected: showDownloadedOnly
                        ) {
                            showDownloadedOnly.toggle()
                        }
                        
                        // Sort menu
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button(action: { sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortOrder.rawValue)
                                    .lineLimit(1)
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.cream)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.cream.opacity(0.2))
                            .cornerRadius(20)
                        }
                        
                        // Clear all button
                        if hasActiveFilters {
                            Button(action: clearFilters) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark")
                                    Text("Clear")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundColor(.gold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                
                // Active filters display
                if hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let rebbe = selectedRebbeFilter {
                                ActiveFilterTag(title: rebbe, onRemove: { selectedRebbeFilter = nil })
                            }
                            if let tag = selectedTagFilter {
                                ActiveFilterTag(title: tag, onRemove: { selectedTagFilter = nil })
                            }
                            if let series = selectedSeriesFilter {
                                ActiveFilterTag(title: series, onRemove: { selectedSeriesFilter = nil })
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.navy)
            
            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.navy)
                Spacer()
            } else if filteredShiurim.isEmpty {
                EmptyStateView(
                    icon: "headphones",
                    title: showSavedOnly ? "No saved shiurim" : (showInProgressOnly ? "No shiurim in progress" : "No shiurim found"),
                    message: showSavedOnly ? "Bookmark shiurim to access them here" : (showInProgressOnly ? "Start listening to a shiur to track your progress" : "Try adjusting your search or filters"),
                    actionTitle: "Clear Filters",
                    action: clearFilters
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredShiurim) { shiur in
                            ShiurRowView(
                                shiur: shiur,
                                isSaved: savedShiurimIds.contains(shiur.id ?? ""),
                                isCurrentlyPlaying: audioPlayer.currentShiur?.id == shiur.id,
                                savedPosition: playbackPositions[shiur.id ?? ""] ?? 0,
                                onToggleSave: { toggleSave(shiur) }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, audioPlayer.currentShiur != nil ? 100 : 20)
                }
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await loadShiurim()
            await loadSavedShiurim()
            await loadPlaybackPositions()
        }
        .refreshable {
            // Force a network fetch so pull-to-refresh always shows the latest;
            // a tab switch or returning to this view uses the in-memory cache.
            await loadShiurim(forceRefresh: true)
            await loadSavedShiurim()
            await loadPlaybackPositions()
        }
        .sheet(isPresented: $showFilters) {
            AdvancedFiltersSheet(
                allRebbeim: allRebbeim,
                allTags: allTags,
                allSeries: allSeries,
                selectedRebbeFilter: $selectedRebbeFilter,
                selectedTagFilter: $selectedTagFilter,
                selectedSeriesFilter: $selectedSeriesFilter
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private func loadShiurim(forceRefresh: Bool = false) async {
        isLoading = true
        do {
            shiurim = try await FirebaseService.shared.fetchShiurim(forceRefresh: forceRefresh)
        } catch {
            print("Error loading shiurim: \(error)")
        }
        isLoading = false
    }
    
    private func loadSavedShiurim() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Website structure: users/{uid}/preferences/savedShiurim with savedShiurIds array
            let docRef = Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("preferences")
                .document("savedShiurim")
            
            let doc = try await docRef.getDocument()
            
            if let data = doc.data(), let savedIds = data["savedShiurIds"] as? [String] {
                await MainActor.run {
                    savedShiurimIds = Set(savedIds)
                }
                print("✅ Loaded \(savedIds.count) saved shiurim from Firebase")
            } else {
                await MainActor.run {
                    savedShiurimIds = []
                }
            }
        } catch {
            print("Error loading saved shiurim: \(error)")
        }
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
                
                await MainActor.run {
                    playbackPositions = result
                }
                print("✅ Loaded \(result.count) playback positions from Firebase")
            }
        } catch {
            print("Error loading playback positions: \(error)")
        }
    }
    
    private func clearFilters() {
        selectedRebbeFilter = nil
        selectedTagFilter = nil
        selectedSeriesFilter = nil
        showSavedOnly = false
        showInProgressOnly = false
        showDownloadedOnly = false
        searchText = ""
    }
    
    private func toggleSave(_ shiur: Shiur) {
        guard let id = shiur.id,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        // Website structure: users/{uid}/preferences/savedShiurim with savedShiurIds array
        let docRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("preferences")
            .document("savedShiurim")
        
        if savedShiurimIds.contains(id) {
            // Remove from saved
            savedShiurimIds.remove(id)
            docRef.updateData([
                "savedShiurIds": FieldValue.arrayRemove([id]),
                "lastUpdated": FieldValue.serverTimestamp(),
                "syncedAt": FieldValue.serverTimestamp()
            ])
        } else {
            // Add to saved
            savedShiurimIds.insert(id)
            docRef.setData([
                "savedShiurIds": FieldValue.arrayUnion([id]),
                "lastUpdated": FieldValue.serverTimestamp(),
                "syncedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
}

// MARK: - Quick Filter Chip
struct QuickFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
            }
            .font(.caption.weight(.medium))
            .foregroundColor(isSelected ? .navy : .cream)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.gold : Color.cream.opacity(0.2))
            .cornerRadius(20)
        }
    }
}

// MARK: - Active Filter Tag
struct ActiveFilterTag: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.navy)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gold.opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Shiur Row View
struct ShiurRowView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var downloadManager: DownloadManager

    let shiur: Shiur
    let isSaved: Bool
    let isCurrentlyPlaying: Bool
    let savedPosition: TimeInterval
    let onToggleSave: () -> Void

    private var hasProgress: Bool {
        savedPosition > 0
    }

    private var downloadState: DownloadState {
        guard let id = shiur.id else { return .idle }
        return downloadManager.state(for: id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top, spacing: 12) {
                // Play indicator or icon
                ZStack {
                    Circle()
                        .fill(isCurrentlyPlaying ? Color.gold : Color.navy.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if isCurrentlyPlaying && audioPlayer.isPlaying {
                        // Playing indicator
                        Image(systemName: "waveform")
                            .font(.body)
                            .foregroundColor(.navy)
                    } else {
                        Image(systemName: "headphones")
                            .font(.body)
                            .foregroundColor(isCurrentlyPlaying ? .navy : .navy.opacity(0.5))
                    }
                }
                
                // Title and info
                VStack(alignment: .leading, spacing: 4) {
                    Text(shiur.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.navy)
                        .lineLimit(2)
                    
                    Text(shiur.rebbe)
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.7))
                    
                    HStack(spacing: 8) {
                        Text(shiur.shortDate)
                            .font(.caption2)
                            .foregroundColor(.navy.opacity(0.5))
                        
                        if let series = shiur.series, !series.isEmpty {
                            Text("•")
                                .foregroundColor(.navy.opacity(0.3))
                            Text(series)
                                .font(.caption2)
                                .foregroundColor(.gold)
                        }
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.body)
                        .foregroundColor(isSaved ? .gold : .navy.opacity(0.3))
                }
            }
            
            // Tags
            if !shiur.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(shiur.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.navy.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.navy.opacity(0.06))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Progress indicator (if has saved position)
            if hasProgress && !isCurrentlyPlaying {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.gold)
                    Text("Resume from \(formatTime(savedPosition))")
                        .font(.caption2)
                        .foregroundColor(.navy.opacity(0.6))
                }
            }
            
            // Action buttons
            HStack(spacing: 10) {
                // Play/Resume button
                if shiur.audioUrl != nil {
                    Button(action: {
                        if isCurrentlyPlaying {
                            audioPlayer.togglePlayPause()
                        } else {
                            Task {
                                await audioPlayer.play(shiur: shiur)
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isCurrentlyPlaying && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            
                            if isCurrentlyPlaying {
                                Text(audioPlayer.isPlaying ? "Pause" : "Play")
                            } else if hasProgress {
                                Text("Resume")
                            } else {
                                Text("Play")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isCurrentlyPlaying ? Color.gold : Color.navy)
                        .cornerRadius(8)
                    }
                }
                
                // Mareh Mekomos button - ONLY if pdfUrl exists and not empty
                if let pdfUrl = shiur.pdfUrl, !pdfUrl.isEmpty {
                    Button(action: {
                        if let url = URL(string: pdfUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("PDF")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.navy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.navy.opacity(0.08))
                        .cornerRadius(8)
                    }
                }

                // Download / Delete / Progress button
                if shiur.audioUrl != nil, shiur.id != nil {
                    DownloadButton(shiur: shiur, state: downloadState)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Download Button
struct DownloadButton: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showDeleteConfirm = false

    let shiur: Shiur
    let state: DownloadState

    var body: some View {
        Button(action: handleTap) {
            content
                .font(.caption.weight(.medium))
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(background)
                .cornerRadius(8)
        }
        .confirmationDialog(
            "Remove this download?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Download", role: .destructive) {
                if let id = shiur.id { downloadManager.deleteDownload(id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .failed:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                Text("Download")
            }
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .controlSize(.mini)
                    .tint(.navy)
                Text("\(Int(progress * 100))%")
            }
        case .downloaded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Saved")
            }
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .downloaded: return .green
        case .failed: return .red
        default: return .navy
        }
    }

    private var background: Color {
        switch state {
        case .downloaded: return Color.green.opacity(0.12)
        case .failed: return Color.red.opacity(0.1)
        default: return Color.navy.opacity(0.08)
        }
    }

    private func handleTap() {
        switch state {
        case .idle, .failed:
            downloadManager.download(shiur)
        case .downloading:
            if let id = shiur.id { downloadManager.cancelDownload(id) }
        case .downloaded:
            showDeleteConfirm = true
        }
    }
}

// MARK: - Advanced Filters Sheet
struct AdvancedFiltersSheet: View {
    let allRebbeim: [String]
    let allTags: [String]
    let allSeries: [String]
    @Binding var selectedRebbeFilter: String?
    @Binding var selectedTagFilter: String?
    @Binding var selectedSeriesFilter: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Rebbe Section
                    FilterSection(title: "Rebbe", icon: "person.fill") {
                        FilterOptionButton(title: "All Rebbeim", isSelected: selectedRebbeFilter == nil) {
                            selectedRebbeFilter = nil
                        }
                        
                        ForEach(allRebbeim, id: \.self) { rebbe in
                            FilterOptionButton(title: rebbe, isSelected: selectedRebbeFilter == rebbe) {
                                selectedRebbeFilter = rebbe
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Series Section
                    if !allSeries.isEmpty {
                        FilterSection(title: "Series", icon: "folder.fill") {
                            FilterOptionButton(title: "All Series", isSelected: selectedSeriesFilter == nil) {
                                selectedSeriesFilter = nil
                            }
                            
                            ForEach(allSeries, id: \.self) { series in
                                FilterOptionButton(title: series, isSelected: selectedSeriesFilter == series) {
                                    selectedSeriesFilter = series
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Tags Section
                    FilterSection(title: "Topics", icon: "tag.fill") {
                        FilterOptionButton(title: "All Topics", isSelected: selectedTagFilter == nil) {
                            selectedTagFilter = nil
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(allTags, id: \.self) { tag in
                                TagFilterButton(title: tag, isSelected: selectedTagFilter == tag) {
                                    selectedTagFilter = tag
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.cream)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedRebbeFilter = nil
                        selectedTagFilter = nil
                        selectedSeriesFilter = nil
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.navy)
                }
            }
        }
    }
}

// MARK: - Filter Section
struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.gold)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.navy)
            }
            
            content
        }
    }
}

// MARK: - Filter Option Button
struct FilterOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .gold : .navy)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.gold)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Tag Filter Button
struct TagFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? .cream : .navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.navy : Color.navy.opacity(0.08))
                .cornerRadius(16)
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.navy.opacity(0.3))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.navy)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.navy.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.navy)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.navy.opacity(0.1))
                    .cornerRadius(20)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        ShiurimView()
            .environmentObject(AudioPlayerManager())
            .environmentObject(DownloadManager.shared)
    }
}
