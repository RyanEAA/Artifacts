//
//  AuthView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showingForm = false
    @State private var isLogin = true
    
    var body: some View {
        ZStack {
            DarkAuthBackground()
            
            Group {
                if showingForm {
                    AuthFormView(isLogin: $isLogin) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingForm = false
                        }
                    }
                    .environmentObject(session)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    LandingView(showingForm: $showingForm, isLogin: $isLogin)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showingForm)
        }
    }
}

private struct LandingView: View {
    @Binding var showingForm: Bool
    @Binding var isLogin: Bool
    
    @State private var showBricks = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButtons = false
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer(minLength: 22)
                    
                    VStack(spacing: 16) {
                        AnimatedRevealHeader(
                            hiddenImages: ["smiley", "flower", "car"],
                            wallRows: 5,
                            wallCols: 7,
                            showBricks: $showBricks
                        )
                        .frame(height: 176)
                        .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 14)
                        .padding(.top, 10)
                        
                        VStack(spacing: 10) {
                            Text("Artifacts")
                                .font(.custom("Poppins-Bold", size: 44))
                                .foregroundColor(Color("MintGreen"))
                                .opacity(showTitle ? 1 : 0)
                                .animation(.easeOut(duration: 0.9).delay(0.12), value: showTitle)
                            
                            VStack(spacing: 8) {
                                Text("Your Reality, Reimagined")
                                    .font(.custom("Poppins-SemiBold", size: 22))
                                    .foregroundColor(Color.white.opacity(0.92))
                                
                                Text("Place models and text in the real world, share them with friends, and explore what others leave behind.")
                                    .font(.custom("Poppins-Regular", size: 16))
                                    .foregroundColor(Color.white.opacity(0.78))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity(showSubtitle ? 1 : 0)
                            .animation(.easeOut(duration: 0.9).delay(0.35), value: showSubtitle)
                            .padding(.horizontal, 6)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Button {
                            isLogin = true
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingForm = true
                            }
                        } label: {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryAuthButtonStyle())
                        
                        Button {
                            isLogin = false
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingForm = true
                            }
                        } label: {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryAuthButtonStyle())
                    }
                    .opacity(showButtons ? 1 : 0)
                    .animation(.easeOut(duration: 0.9).delay(0.60), value: showButtons)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 22)
                }
                .padding(.horizontal, max(22, geo.size.width * 0.08))
                .frame(minHeight: geo.size.height)
            }
            .authKeyboardDismissBehavior()
            .background(Color.clear)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9).delay(0.05)) { showBricks = true }
                withAnimation(.easeOut(duration: 0.9).delay(0.10)) { showTitle = true }
                withAnimation(.easeOut(duration: 0.9).delay(0.25)) { showSubtitle = true }
                withAnimation(.easeOut(duration: 0.9).delay(0.45)) { showButtons = true }
            }
        }
    }
}

private struct AuthFormView: View {
    @EnvironmentObject var session: SessionManager
    @Binding var isLogin: Bool
    
    let onBack: () -> Void
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case username
        case email
        case password
    }
    
    private var hasError: Bool {
        guard let msg = session.errorMessage else { return false }
        return !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var canSubmit: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isLogin {
            return !cleanEmail.isEmpty && !cleanPassword.isEmpty && !session.isAuthInFlight
        }
        
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanUsername.isEmpty && !cleanEmail.isEmpty && !cleanPassword.isEmpty && !session.isAuthInFlight
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer(minLength: 16)
                    
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.20)) {
                                session.errorMessage = nil
                            }
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("MintGreen"))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.06))
                                .overlay(
                                    Circle()
                                        .stroke(Color("MintGreen").opacity(0.26), lineWidth: 1)
                                )
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Back")
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 10) {
                        Text(isLogin ? "Welcome Back" : "Create Your Account")
                            .font(.custom("Poppins-Bold", size: 28))
                            .foregroundColor(Color.white.opacity(0.92))
                        
                        Text(isLogin ? "Sign in to continue building in AR." : "Set up your profile to start leaving artifacts.")
                            .font(.custom("Poppins-Regular", size: 16))
                            .foregroundColor(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    
                    VStack(spacing: 14) {
                        if hasError {
                            ErrorBanner(text: session.errorMessage ?? "") {
                                withAnimation(.easeInOut(duration: 0.20)) {
                                    session.errorMessage = nil
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: 12) {
                            if !isLogin {
                                AuthInputRow(
                                    systemImage: "person",
                                    title: "Username",
                                    text: $username,
                                    keyboard: .default,
                                    textContentType: .username,
                                    submitLabel: .next
                                )
                                .focused($focusedField, equals: .username)
                                .onSubmit { focusedField = .email }
                                .onChange(of: username) { _, newValue in
                                    username = newValue.lowercased()
                                }
                            }
                            
                            AuthInputRow(
                                systemImage: "envelope",
                                title: "Email",
                                text: $email,
                                keyboard: .emailAddress,
                                textContentType: .emailAddress,
                                submitLabel: .next
                            )
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
                            
                            AuthSecureRow(
                                title: "Password",
                                text: $password,
                                showPassword: $showPassword,
                                submitLabel: .go
                            )
                            .focused($focusedField, equals: .password)
                            .onSubmit { submit() }
                        }
                        .padding(18)
                        .background(DarkAuthCardBackground())
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color("MintGreen").opacity(0.16), lineWidth: 1)
                        )
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.55), radius: 22, x: 0, y: 14)
                        
                        Button(action: submit) {
                            ZStack {
                                Text(isLogin ? "Log In" : "Create Account")
                                    .opacity(session.isAuthInFlight ? 0 : 1)
                                
                                if session.isAuthInFlight {
                                    ProgressView()
                                        .tint(Color("DarkGray"))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryAuthButtonStyle())
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.55)
                        
                        if isLogin {
                            Button("Forgot Password") {
                                sendPasswordReset()
                            }
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundColor(Color("MintGreen"))
                            .padding(.top, 2)
                        }
                        
                        HStack(spacing: 12) {
                            Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.12))
                            Text("OR")
                                .font(.custom("Poppins-SemiBold", size: 12))
                                .foregroundColor(Color.white.opacity(0.55))
                            Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.12))
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: {}) {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Continue with Google")
                                    .font(.custom("Poppins-SemiBold", size: 16))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryAuthButtonStyle())
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.90), value: hasError)
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 6) {
                        Text(isLogin ? "No account?" : "Already have an account?")
                            .font(.custom("Poppins-Regular", size: 14))
                            .foregroundColor(Color.white.opacity(0.70))
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                session.errorMessage = nil
                                isLogin.toggle()
                            }
                            focusedField = isLogin ? .email : .username
                        }) {
                            Text(isLogin ? "Create one" : "Log in")
                                .font(.custom("Poppins-Bold", size: 14))
                                .foregroundColor(Color("MintGreen"))
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, max(20, geo.size.width * 0.07))
                .frame(minHeight: geo.size.height)
            }
            .authKeyboardDismissBehavior()
            .background(Color.clear)
            .onTapGesture { UIApplication.shared.endEditing() }
            .onAppear { focusedField = isLogin ? .email : .username }
        }
    }
    
    private func submit() {
        guard canSubmit else { return }
        
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isLogin {
            session.signIn(email: cleanEmail, password: cleanPassword)
        } else {
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            session.signUp(email: cleanEmail, password: cleanPassword, username: cleanUsername)
        }
    }
    
    private func sendPasswordReset() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            withAnimation(.easeInOut(duration: 0.20)) {
                session.errorMessage = "Enter your email to reset your password."
            }
            focusedField = .email
            return
        }
        
        session.sendPasswordReset(email: cleanEmail)
    }
}

private struct DarkAuthBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.55),
                    .init(color: Color.black.opacity(0.96), location: 1.00)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color("MintGreen").opacity(0.08),
                    Color.clear
                ]),
                startPoint: .topTrailing,
                endPoint: .center
            )
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.55)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

private struct DarkAuthCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct ErrorBanner: View {
    let text: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.red.opacity(0.95))
                .padding(.top, 2)
            
            Text(text)
                .font(.custom("Poppins-Regular", size: 14))
                .foregroundColor(Color.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .background(Color.black.opacity(0.62))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct AuthInputRow: View {
    let systemImage: String
    let title: String
    
    @Binding var text: String
    let keyboard: UIKeyboardType
    let textContentType: UITextContentType?
    let submitLabel: SubmitLabel
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(Color("MintGreen").opacity(0.92))
                .frame(width: 22)
            
            ZStack(alignment: .leading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title)
                        .font(.custom("Poppins-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.40))
                        .padding(.leading, 2)
                }
                
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(textContentType)
                    .submitLabel(submitLabel)
                    .foregroundColor(Color.white.opacity(0.92))
                    .tint(Color("MintGreen"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct AuthSecureRow: View {
    let title: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let submitLabel: SubmitLabel
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .foregroundColor(Color("MintGreen").opacity(0.92))
                .frame(width: 22)
            
            ZStack(alignment: .leading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title)
                        .font(.custom("Poppins-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.40))
                        .padding(.leading, 2)
                }
                
                Group {
                    if showPassword {
                        TextField("", text: $text)
                    } else {
                        SecureField("", text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.password)
                .submitLabel(submitLabel)
                .foregroundColor(Color.white.opacity(0.92))
                .tint(Color("MintGreen"))
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct PrimaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 17))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color("MintGreen"))
            .foregroundColor(Color.black.opacity(0.92))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.25 : 0.55), radius: 18, x: 0, y: 14)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SecondaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 17))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.06))
            .foregroundColor(Color.white.opacity(0.90))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color("MintGreen").opacity(0.26), lineWidth: 1)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.20 : 0.45), radius: 16, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func authKeyboardDismissBehavior() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
