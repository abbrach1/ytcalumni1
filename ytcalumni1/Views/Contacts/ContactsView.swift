import SwiftUI
import FirebaseAuth

struct ContactsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var rebbeim: [Rebbe] = []
    @State private var alumni: [AlumniContact] = []
    @State private var alumniSearchText = ""
    @State private var expandedAlumniId: String?
    @State private var isLoading = true
    @State private var selectedTab: ContactTab = .rebbeim
    
    enum ContactTab: String, CaseIterable {
        case rebbeim = "Rebbeim"
        case alumni = "Alumni"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Directory")
                        .font(.serifHeadline())
                        .foregroundColor(.cream)
                    
                    Text("Connect with Rebbeim and fellow alumni")
                        .font(.subheadline)
                        .foregroundColor(.cream.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.navy)
                
                VStack(spacing: 24) {
                    // Tab Selector
                    HStack(spacing: 0) {
                        ForEach(ContactTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(selectedTab == tab ? .cream : .navy.opacity(0.6))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(selectedTab == tab ? Color.navy : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    // Content based on tab
                    if selectedTab == .rebbeim {
                        rebbeimSection
                    } else {
                        alumniSection
                    }
                    
                    // Contact Form
                    contactFormSection
                }
                .padding(16)
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Rebbeim Section
    private var rebbeimSection: some View {
        VStack(spacing: 16) {
            if rebbeim.isEmpty {
                comingSoonCard(
                    icon: "book.fill",
                    title: "Rebbeim Directory Coming Soon",
                    message: "We are working on building the Rebbeim directory. Check back soon for contact information for all the Rebbeim."
                )
            } else {
                ForEach(rebbeim) { rebbe in
                    RebbeCard(rebbe: rebbe)
                }
            }
        }
    }
    
    // MARK: - Alumni Section

    private var filteredAlumni: [AlumniContact] {
        if alumniSearchText.isEmpty {
            return alumni
        }
        let query = alumniSearchText.lowercased()
        return alumni.filter {
            $0.name.lowercased().contains(query) ||
            ($0.email?.lowercased().contains(query) ?? false) ||
            $0.location.lowercased().contains(query)
        }
    }

    private var alumniSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.navy.opacity(0.4))
                TextField("Search by name, email, or location", text: $alumniSearchText)
                    .font(.subheadline)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !alumniSearchText.isEmpty {
                    Button(action: { alumniSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.navy.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
            )

            if filteredAlumni.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: alumniSearchText.isEmpty ? "person.2.fill" : "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.navy.opacity(0.3))
                    Text(alumniSearchText.isEmpty ? "No alumni listed yet" : "No results found")
                        .font(.headline)
                        .foregroundColor(.navy)
                    Text(alumniSearchText.isEmpty
                         ? "Be the first! Add your contact info below."
                         : "Try a different search term.")
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            } else {
                ForEach(filteredAlumni) { alumnus in
                    AlumniContactCard(
                        alumnus: alumnus,
                        isExpanded: expandedAlumniId == alumnus.id,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedAlumniId == alumnus.id {
                                    expandedAlumniId = nil
                                } else {
                                    expandedAlumniId = alumnus.id
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Contact Form Section
    private var contactFormSection: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Your Contact Info")
                    .font(.headline)
                    .foregroundColor(.cream)
                
                Text("Submit your details to be listed in the alumni directory.")
                    .font(.caption)
                    .foregroundColor(.cream.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                LinearGradient(colors: [.navy, .navyLight], startPoint: .leading, endPoint: .trailing)
            )
            
            // Form
            ContactInfoForm()
                .padding(20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Coming Soon Card
    private func comingSoonCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
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
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Load Data
    private func loadData() async {
        isLoading = true
        do {
            async let rebbeimResult = FirebaseService.shared.fetchRebbeim()
            async let alumniResult = FirebaseService.shared.fetchApprovedAlumni()
            rebbeim = try await rebbeimResult
            alumni = try await alumniResult
        } catch {
            print("Error loading contacts: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Rebbe Card
struct RebbeCard: View {
    let rebbe: Rebbe
    
    var body: some View {
        HStack(spacing: 16) {
            // Photo
            if let photoUrl = rebbe.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsView
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                initialsView
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(rebbe.name)
                    .font(.headline)
                    .foregroundColor(.navy)
                
                Text(rebbe.title)
                    .font(.subheadline)
                    .foregroundColor(.navy.opacity(0.7))
                
                HStack(spacing: 16) {
                    if let email = rebbe.email {
                        Button(action: { openEmail(email) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                Text("Email")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gold)
                        }
                    }
                    
                    if let phone = rebbe.phone {
                        Button(action: { openPhone(phone) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                Text("Call")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.gold)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color.navy.opacity(0.1))
            
            Text(rebbe.name.prefix(1))
                .font(.title2.weight(.semibold))
                .foregroundColor(.navy)
        }
        .frame(width: 60, height: 60)
    }
    
    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPhone(_ phone: String) {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel:\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Alumni Contact Card
struct AlumniContactCard: View {
    let alumnus: AlumniContact
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header — always visible
            Button(action: onTap) {
                HStack(spacing: 14) {
                    // Initials circle
                    ZStack {
                        Circle()
                            .fill(Color.navy.opacity(0.1))
                        Text(initials)
                            .font(.headline)
                            .foregroundColor(.navy)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alumnus.name)
                            .font(.headline)
                            .foregroundColor(.navy)

                        Text(alumnus.location)
                            .font(.caption)
                            .foregroundColor(.navy.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.navy.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    if let email = alumnus.email, !email.isEmpty {
                        Button(action: { openEmail(email) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.gold)
                                    .frame(width: 24)
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.navy)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let phone = alumnus.phone, !phone.isEmpty {
                        Button(action: { openPhone(phone) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.gold)
                                    .frame(width: 24)
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundColor(.navy)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.gold)
                            .frame(width: 24)
                        Text(alumnus.location)
                            .font(.subheadline)
                            .foregroundColor(.navy)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var initials: String {
        let parts = alumnus.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(alumnus.name.prefix(2)).uppercased()
    }

    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    private func openPhone(_ phone: String) {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel:\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Contact Info Form
struct ContactInfoForm: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var locationType: LocationType?
    @State private var otherLocation = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    enum LocationType: String, CaseIterable {
        case eretzYisroel = "Eretz Yisroel"
        case chutzLaaretz = "Chutz Laaretz"
        case other = "Other"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Name
            VStack(alignment: .leading, spacing: 6) {
                RequiredLabel(text: "Full Name")
                TextField("Enter your full name", text: $name)
                    .customTextField()
            }
            
            // Email
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Email")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                TextField("your.email@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .customTextField()
            }
            
            // Phone
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Phone Number")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.navy)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.navy.opacity(0.5))
                }
                TextField("(555) 123-4567", text: $phone)
                    .keyboardType(.phonePad)
                    .customTextField()
            }
            
            // Location
            VStack(alignment: .leading, spacing: 6) {
                RequiredLabel(text: "Current Location")
                
                Menu {
                    ForEach(LocationType.allCases, id: \.self) { type in
                        Button(action: { locationType = type }) {
                            HStack {
                                Text(type.rawValue)
                                if locationType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(locationType?.rawValue ?? "Select your location")
                            .foregroundColor(locationType == nil ? .navy.opacity(0.5) : .navy)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.navy.opacity(0.5))
                    }
                    .customTextField()
                }
            }
            
            // Other Location
            if locationType == .other {
                VStack(alignment: .leading, spacing: 6) {
                    RequiredLabel(text: "Please specify location")
                    TextField("Enter your location", text: $otherLocation)
                        .customTextField()
                }
            }
            
            // Submit Button
            Button(action: submitInfo) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cream))
                            .scaleEffect(0.8)
                    }
                    Image(systemName: "paperplane.fill")
                    Text(isSubmitting ? "Submitting..." : "Submit My Info")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: isSubmitting || !isFormValid))
            .disabled(isSubmitting || !isFormValid)
        }
        .alert("Information Submitted", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                resetForm()
            }
        } message: {
            Text("Thank you! Your contact information has been submitted and will appear in the directory soon.")
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
    
    private var isFormValid: Bool {
        !name.isEmpty && locationType != nil && (locationType != .other || !otherLocation.isEmpty)
    }
    
    private var locationValue: String {
        if locationType == .other {
            return otherLocation
        }
        return locationType?.rawValue ?? ""
    }
    
    private func submitInfo() {
        isSubmitting = true
        
        Task {
            do {
                try await FirebaseService.shared.submitContactInfo(
                    name: name,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    location: locationValue,
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
        name = ""
        email = ""
        phone = ""
        locationType = nil
        otherLocation = ""
    }
}

#Preview {
    NavigationStack {
        ContactsView()
            .environmentObject(AuthManager())
    }
}
