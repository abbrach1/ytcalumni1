import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo and Title
                VStack(spacing: 12) {
                    Image("yeshiva-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    Text("Yeshiva Toras Chaim Alumni")
                        .font(.serifHeadline())
                        .foregroundColor(.navy)
                        .multilineTextAlignment(.center)
                    
                    Text(isSignUp ? "Create your account" : "Sign in to access the alumni portal")
                        .font(.subheadline)
                        .foregroundColor(.navy.opacity(0.7))
                }
                .padding(.top, 40)
                
                // Sign Up Info Box
                if isSignUp {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How approval works:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.navy)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            BulletPoint(text: "If your email is in our alumni database, you will be approved automatically")
                            BulletPoint(text: "Otherwise, your request will be reviewed by an administrator")
                            BulletPoint(text: "You will receive access once approved")
                        }
                    }
                    .padding()
                    .background(Color.navy.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.navy.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Form Fields
                VStack(spacing: 16) {
                    if isSignUp {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                RequiredLabel(text: "First Name")
                                TextField("Moshe", text: $firstName)
                                    .textContentType(.givenName)
                                    .customTextField()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                RequiredLabel(text: "Last Name")
                                TextField("Cohen", text: $lastName)
                                    .textContentType(.familyName)
                                    .customTextField()
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RequiredLabel(text: "Email")
                        TextField("email@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .customTextField()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RequiredLabel(text: "Password")
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textContentType(isSignUp ? .newPassword : .password)
                            } else {
                                SecureField("Password", text: $password)
                                    .textContentType(isSignUp ? .newPassword : .password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.navy.opacity(0.5))
                            }
                        }
                        .customTextField()
                    }
                    
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 6) {
                            RequiredLabel(text: "Confirm Password")
                            HStack {
                                if showConfirmPassword {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                }
                                
                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.navy.opacity(0.5))
                                }
                            }
                            .customTextField()
                        }
                    }
                }
                
                // Submit Button
                Button(action: handleAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cream))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? (isSignUp ? "Creating Account..." : "Signing In...") : (isSignUp ? "Sign Up" : "Sign In"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: isLoading))
                .disabled(isLoading)
                
                // Toggle Sign Up / Sign In
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                        .font(.subheadline)
                        .foregroundColor(.navy)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.cream.ignoresSafeArea())
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    private func handleAuth() {
        // Validation
        if isSignUp {
            guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
                  !lastName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Please enter your first and last name."
                showError = true
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match. Please make sure both passwords are the same."
                showError = true
                return
            }
        }
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all required fields."
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    let _ = try await authManager.signUp(
                        email: email,
                        password: password,
                        firstName: firstName.trimmingCharacters(in: .whitespaces),
                        lastName: lastName.trimmingCharacters(in: .whitespaces)
                    )
                } else {
                    let _ = try await authManager.signIn(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views
struct RequiredLabel: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.navy)
            Text("*")
                .foregroundColor(.red)
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.navy.opacity(0.6))
            Text(text)
                .font(.caption)
                .foregroundColor(.navy.opacity(0.8))
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
