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
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButtons = false
    
    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            SymbolCycler()
            
            VStack {
                Text("ARTIFACTS")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundColor(Color("MintGreen"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .opacity(showTitle ? 1 : 0)
                    .animation(.easeOut(duration: 1).delay(0.2), value: showTitle)
                
                VStack {
                    Text("Your Reality, Reimagined")
                        .font(.system(size: 28))
                        .foregroundColor(Color("LighterGray"))
                        .frame(maxWidth: .infinity)
                        .opacity(showSubtitle ? 1 : 0)
                        .animation(.easeOut(duration: 1).delay(0.6), value: showSubtitle)
                    
                    Text("Transform your surroundings with augmented reality.")
                        .font(.system(size: 22, weight: .thin))
                        .foregroundColor(Color("LighterGray"))
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
                        .foregroundColor(Color("MintGreen"))
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color("MintGreen"), lineWidth: 2)
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
                        .background(Color("MintGreen"))
                        .foregroundColor(Color("DarkGray"))
                        .cornerRadius(4)
                }
                .contentShape(Rectangle())
            }
            .opacity(showButtons ? 1 : 0)
            .animation(.easeOut(duration: 1).delay(1.2), value: showButtons)
            
            Spacer()
        }
        .padding(.horizontal, 36)
        .background(Color("DarkGray").ignoresSafeArea())
        .onAppear {
            showTitle = true
            showSubtitle = true
            showButtons = true
        }
    }
}

struct AuthFormView: View {
    @EnvironmentObject var session: SessionManager
    @Binding var isLogin: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(isLogin ? "Welcome Back" : "Create Account")
                .font(.custom("Poppins-Bold", size: 26))
                .foregroundColor(Color("MintGreen"))
            
            Text(isLogin ? "Step back into a world of creativity." :
                 "Bring your imagination into the real world.")
                .font(.custom("Poppins-Regular", size: 16))
                .foregroundColor(Color("LighterGray"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(Color("MintGreen"))
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(Color("LighterGray")))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(Color("LighterGray"))
                }
                .padding()
                .background(Color("DarkGray"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("MintGreen"), lineWidth: 2)
                )
                .cornerRadius(8)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(Color("MintGreen"))
                    
                    ZStack {
                        if showPassword {
                            TextField("", text: $password, prompt: Text("Password").foregroundColor(Color("LighterGray")))
                                .foregroundColor(Color("LighterGray"))
                        } else {
                            SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color("LighterGray")))
                                .foregroundColor(Color("LighterGray"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color("MintGreen"))
                    }
                }
                .padding()
                .background(Color("DarkGray"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("MintGreen"), lineWidth: 2)
                )
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            
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
                    session.signUp(email: email, password: password)
                }
            }) {
                Text(isLogin ? "LOGIN" : "SIGN UP")
                    .font(.custom("Poppins-SemiBold", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("MintGreen"))
                    .foregroundColor(Color("DarkGray"))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            
            if isLogin {
                Button("Forgot Password?") {
                    // ADD RESET FUNCTIONALITY
                }
                .font(.custom("Poppins-Regular", size: 14))
                .foregroundColor(Color("MintGreen"))
            }
            
            HStack {
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                Text("OR")
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundColor(Color("LighterGray"))
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 24)
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .font(.custom("Poppins-SemiBold", size: 16))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("DarkGray"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("MintGreen"), lineWidth: 2)
                )
                .foregroundColor(Color("MintGreen"))
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            HStack {
                Text(isLogin ? "Don’t have an account?" : "Already have an account?")
                    .font(.custom("Poppins-Regular", size: 14))
                    .foregroundColor(Color("LighterGray"))
                
                Button(action: {
                    isLogin.toggle()
                    session.errorMessage = nil
                }) {
                    Text(isLogin ? "Sign Up" : "Log In")
                        .font(.custom("Poppins-Bold", size: 14))
                        .foregroundColor(Color("MintGreen"))
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color("DarkGray").ignoresSafeArea())
    }
}

#Preview {
    AuthView()
}
