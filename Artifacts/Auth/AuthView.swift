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
        if showingForm {
            AuthFormView(isLogin: $isLogin)
                .environmentObject(session)
        } else {
            LandingView(showingForm: $showingForm, isLogin: $isLogin)
        }
    }
}

struct LandingView: View {
    @Binding var showingForm: Bool
    @Binding var isLogin: Bool
    
    @State private var showBricks = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButtons = false
    
    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            
            VStack {
                AnimatedRevealHeader(
                    hiddenImages: ["smiley", "flower", "car"],
                    wallRows: 5,
                    wallCols: 7,
                    showBricks: $showBricks
                )
                .frame(height: 180)
                
                Text("ARTIFACTS")
                    .font(.custom("Poppins-Bold", size: 45))
                    .foregroundColor(Color("DarkGray"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .opacity(showTitle ? 1 : 0)
                    .animation(.easeOut(duration: 1).delay(0.2), value: showTitle)
                
                VStack {
                    Text("Your Reality, Reimagined")
                        .font(.system(size: 28))
                        .foregroundColor(Color("DarkGray"))
                        .frame(maxWidth: .infinity)
                        .opacity(showSubtitle ? 1 : 0)
                        .animation(.easeOut(duration: 1).delay(0.6), value: showSubtitle)
                    
                    Text("Transform your surroundings with augmented reality.")
                        .font(.system(size: 22, weight: .thin))
                        .foregroundColor(Color("DarkGray"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .opacity(showSubtitle ? 1 : 0)
                        .animation(.easeOut(duration: 1).delay(0.8), value: showSubtitle)
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    isLogin = true
                    showingForm = true
                } label: {
                    Text("LOGIN")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(Color("DarkGray"))
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color("DarkGray"), lineWidth: 2)
                        )
                }
                .contentShape(Rectangle())
                
                Button {
                    isLogin = false
                    showingForm = true
                } label: {
                    Text("SIGN UP")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("DarkGray"))
                        .foregroundColor(Color("LighterGray"))
                        .cornerRadius(4)
                }
                .contentShape(Rectangle())
            }
            .opacity(showButtons ? 1 : 0)
            .animation(.easeOut(duration: 1).delay(1.2), value: showButtons)
            
            Spacer()
        }
        .padding(.horizontal, 48)
        .background(Color("MintGreen").ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 1).delay(0.05)) {
                showBricks = true
            }
            withAnimation(.easeOut(duration: 1).delay(0.1)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 1).delay(0.3)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: 1).delay(0.6)) {
                showButtons = true
            }
        }
    }
}

struct AuthFormView: View {
    @EnvironmentObject var session: SessionManager
    @Binding var isLogin: Bool
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack {
                Text(isLogin ? "Welcome Back!" : "Create Your Account!")
                    .font(.custom("Poppins-Bold", size: 26))
                    .foregroundColor(Color("DarkGray"))
                
                Text(isLogin ? "Step back into a world of creativity." :
                     "Bring your imagination into reality.")
                    .font(.custom("Poppins-Regular", size: 16))
                    .foregroundColor(Color("DarkGray"))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                if !isLogin {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(Color("DarkGray"))
                        TextField("", text: $username, prompt: Text("Username").foregroundColor(Color("DarkGray")))
                            .autocapitalization(.none)
                            .foregroundColor(Color("DarkGray"))
                    }
                    .padding()
                    .background(Color("MintGreen"))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("DarkGray"), lineWidth: 2))
                    .cornerRadius(8)
                }
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(Color("DarkGray"))
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(Color("DarkGray")))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(Color("DarkGray"))
                }
                .padding()
                .background(Color("MintGreen"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("DarkGray"), lineWidth: 2)
                )
                .cornerRadius(8)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(Color("DarkGray"))
                    
                    ZStack {
                        if showPassword {
                            TextField("", text: $password, prompt: Text("Password").foregroundColor(Color("DarkGray")))
                                .foregroundColor(Color("DarkGray"))
                        } else {
                            SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color("DarkGray")))
                                .foregroundColor(Color("DarkGray"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color("DarkGray"))
                    }
                }
                .padding()
                .background(Color("MintGreen"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("DarkGray"), lineWidth: 2)
                )
                .cornerRadius(8)
            }
            
            if let error = session.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.custom("Poppins-Regular", size: 14))
                    .padding(.horizontal)
            }
            
            Button(action: {
                if isLogin {
                    session.signIn(email: email, password: password)
                } else {
                    session.signUp(email: email, password: password, username: username)
                }
            }) {
                Text(isLogin ? "LOGIN" : "SIGN UP")
                    .font(.custom("Poppins-SemiBold", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("DarkGray"))
                    .foregroundColor(Color("MintGreen"))
                    .cornerRadius(8)
            }
            
            if isLogin {
                Button("Forgot Password?") {
                    // ADD RESET FUNCTIONALITY
                }
                .font(.custom("Poppins-Regular", size: 14))
                .foregroundColor(Color("DarkGray"))
            }
            
            HStack {
                Rectangle().frame(height: 1).foregroundColor(Color("DarkGray").opacity(0.3))
                Text("OR")
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundColor(Color("DarkGray"))
                Rectangle().frame(height: 1).foregroundColor(Color("DarkGray").opacity(0.3))
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .font(.custom("Poppins-SemiBold", size: 16))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("MintGreen"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("DarkGray"), lineWidth: 2)
                )
                .foregroundColor(Color("DarkGray"))
                .cornerRadius(8)
            }
            
            Spacer()
            
            HStack {
                Text(isLogin ? "Don’t have an account?" : "Already have an account?")
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundColor(Color("DarkGray"))
                
                Button(action: {
                    isLogin.toggle()
                    session.errorMessage = nil
                }) {
                    Text(isLogin ? "Sign Up" : "Log In")
                        .font(.custom("Poppins-Bold", size: 14))
                        .foregroundColor(Color("DarkGray"))
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 48)
        .background(Color("MintGreen").ignoresSafeArea())
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

#Preview {
    AuthView()
}
