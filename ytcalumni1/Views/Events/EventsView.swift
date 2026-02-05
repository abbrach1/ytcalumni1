import SwiftUI
import PhotosUI
import FirebaseAuth

struct EventsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var events: [Event] = []
    @State private var isLoading = true
    @State private var showSubmitForm = false
    
    private var upcomingEvents: [Event] {
        events.filter { !$0.isPast }
    }
    
    private var pastEvents: [Event] {
        events.filter { $0.isPast }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Yeshiva Simchos")
                        .font(.serifHeadline())
                        .foregroundColor(.cream)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.navy)
                
                VStack(spacing: 32) {
                    // Upcoming Events Section
                    if !upcomingEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Upcoming")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.navy)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(upcomingEvents) { event in
                                    EventDetailCard(event: event)
                                }
                            }
                        }
                    } else if !isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 40))
                                .foregroundColor(.navy.opacity(0.3))
                            
                            Text("No upcoming simchos")
                                .font(.headline)
                                .foregroundColor(.navy.opacity(0.6))
                        }
                        .padding(.vertical, 40)
                    }
                    
                    // Past Events Section
                    if !pastEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Past")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.navy.opacity(0.7))
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(pastEvents.prefix(8)) { event in
                                    PastEventCard(event: event)
                                }
                            }
                        }
                    }
                    
                    // Submit Simcha Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Share Your Simcha")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.navy)
                        
                        SimchaSubmissionForm()
                    }
                }
                .padding(16)
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEvents()
        }
        .refreshable {
            await loadEvents()
        }
    }
    
    private func loadEvents() async {
        isLoading = true
        do {
            events = try await FirebaseService.shared.fetchEvents()
        } catch {
            print("Error loading events: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Event Detail Card
struct EventDetailCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image header or gradient
            if let imageUrl = event.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    default:
                        gradientHeader
                    }
                }
            } else {
                gradientHeader
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    // Date badge
                    VStack(spacing: 0) {
                        Text(event.monthAbbreviation)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.cream.opacity(0.8))
                        Text(event.dayNumber)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.cream)
                    }
                    .frame(width: 56)
                    .padding(.vertical, 8)
                    .background(Color.navy)
                    .cornerRadius(8)
                    
                    // Event details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.type)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gold.opacity(0.15))
                            .cornerRadius(4)
                        
                        Text(event.eventName)
                            .font(.headline)
                            .foregroundColor(.navy)
                        
                        Text(event.personFamily)
                            .font(.subheadline)
                            .foregroundColor(.navy.opacity(0.7))
                    }
                }
                
                Divider()
                    .background(Color.navy.opacity(0.1))
                
                // Location and time
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .foregroundColor(.gold)
                            .font(.caption)
                        Text(event.location)
                            .font(.subheadline)
                            .foregroundColor(.navy.opacity(0.7))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.gold)
                            .font(.caption)
                        Text(event.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.navy.opacity(0.7))
                    }
                    
                    if let time = event.time {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .foregroundColor(.gold)
                                .font(.caption)
                            Text(time)
                                .font(.subheadline)
                                .foregroundColor(.navy.opacity(0.7))
                        }
                    }
                }
                
                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(16)
        }
        .cardStyle()
    }
    
    private var gradientHeader: some View {
        LinearGradient(
            colors: [.navy, .gold],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 12)
    }
}

// MARK: - Past Event Card
struct PastEventCard: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 0) {
                Text(event.monthAbbreviation)
                    .font(.system(size: 8).weight(.medium))
                    .foregroundColor(.navy.opacity(0.6))
                Text(event.dayNumber)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.navy)
            }
            .frame(width: 44)
            .padding(.vertical, 6)
            .background(Color.navy.opacity(0.1))
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.eventName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.navy)
                    .lineLimit(1)
                
                Text(event.personFamily)
                    .font(.caption2)
                    .foregroundColor(.navy.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Simcha Submission Form
struct SimchaSubmissionForm: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var fullName = ""
    @State private var simchaType = ""
    @State private var date = Date()
    @State private var connection = ""
    @State private var message = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Full Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Full Name")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.navy)
                
                TextField("Enter full name", text: $fullName)
                    .customTextField()
            }
            
            // Simcha Type
            VStack(alignment: .leading, spacing: 6) {
                Text("Type of Simcha")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.navy)
                
                TextField("Wedding, Bar Mitzvah, etc.", text: $simchaType)
                    .customTextField()
            }
            
            // Date
            VStack(alignment: .leading, spacing: 6) {
                Text("Date")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.navy)
                
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.gold)
            }
            
            // Connection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Connection to Yeshiva")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                
                TextField("Alumnus, Parent, etc.", text: $connection)
                    .customTextField()
            }
            
            // Message
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Additional Details")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                
                TextEditor(text: $message)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Image Picker
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Upload Picture")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    VStack(spacing: 12) {
                        if let data = selectedImageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .cornerRadius(8)
                            
                            Text("Tap to change")
                                .font(.caption)
                                .foregroundColor(.navy.opacity(0.5))
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundColor(.navy.opacity(0.4))
                            
                            Text("Click to upload")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.navy)
                            
                            Text("JPG, PNG up to 10MB")
                                .font(.caption)
                                .foregroundColor(.navy.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.navy.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
                .onChange(of: selectedImage) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }
            }
            
            // Submit Button
            Button(action: submitSimcha) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cream))
                            .scaleEffect(0.8)
                    }
                    Image(systemName: "paperplane.fill")
                    Text(isSubmitting ? "Submitting..." : "Submit Simcha")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: isSubmitting))
            .disabled(isSubmitting || fullName.isEmpty || simchaType.isEmpty)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .alert("Simcha Submitted!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                resetForm()
            }
        } message: {
            Text("Thank you! Your simcha has been submitted for review.")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    private func submitSimcha() {
        isSubmitting = true
        
        Task {
            do {
                try await FirebaseService.shared.submitSimcha(
                    fullName: fullName,
                    simchaType: simchaType,
                    date: date,
                    connection: connection.isEmpty ? nil : connection,
                    message: message.isEmpty ? nil : message,
                    imageUrl: nil, // Image upload would require Firebase Storage setup
                    submittedBy: authManager.user?.email ?? "unknown"
                )
                
                await MainActor.run {
                    showSuccess = true
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
    
    private func resetForm() {
        fullName = ""
        simchaType = ""
        date = Date()
        connection = ""
        message = ""
        selectedImage = nil
        selectedImageData = nil
    }
}

#Preview {
    NavigationStack {
        EventsView()
            .environmentObject(AuthManager())
    }
}
