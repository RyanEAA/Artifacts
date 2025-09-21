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
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack {
                Image("drawnPlane")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                                
                Text("ARTIFACTS")
                    .font(.custom("FingerPaint-Regular", size: 60))
                    .foregroundColor(Color("LighterGray"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, -36)
                
                VStack {
                    Text("Your Reality, Reimagined")
                        .font(.custom("Poppins-Bold", size: 26))
                        .foregroundColor(Color("LighterGray"))
                        .frame(maxWidth: .infinity)
                    
                    Text("Transform your surroundings with augmented reality.")
                        .font(.custom("Poppins-Light", size: 22))
                        .foregroundColor(Color("LighterGray"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    isLogin = true
                    showingForm = true
                } label: {
                    Text("LOGIN")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(Color("DarkBlue"))
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color("DarkBlue"), lineWidth: 2)
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
                        .background(Color("DarkBlue"))
                        .foregroundColor(Color("LighterGray"))
                        .cornerRadius(4)
                }
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 48)
            Spacer();
        }
        .background(Color("BrightRed").ignoresSafeArea())
    }
}

struct AuthFormView: View {
    @EnvironmentObject var session: SessionManager
    @Binding var isLogin: Bool
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            
            Text(isLogin ? "Welcome Back!" : "Create Your Account!")
                .font(.custom("Poppins-Bold", size: 26))
                .foregroundColor(Color("LighterGray"))
            
            Text(isLogin ? "Step into your world of creation." :
                 "Join us and start creating your world.")
                .font(.custom("Poppins-Light", size: 18))
                .foregroundColor(Color("LighterGray"))
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "envelope")
                    TextField("EMAIL", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color("LighterGray"))
                .cornerRadius(4)
                
                HStack {
                    Image(systemName: "lock")
                    SecureField("PASSWORD", text: $password)
                }
                .padding()
                .background(Color("LighterGray"))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            .foregroundColor(Color("DarkBlue"))
            
            if let error = session.errorMessage {
                Text(error)
                    .foregroundColor(Color("LighterGray"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                if isLogin {
                    session.signIn(email: email, password: password)
                } else {
                    session.signUp(email: email, password: password)
                }
            }) {
                Text(isLogin ? "LOG IN" : "SIGN UP")
                    .font(.custom("Poppins-SemiBold", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(Color("LighterGray"))
                    .background(Color("DarkBlue"))
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            
            if isLogin {
                Button(action: {
                    // ADD RESET FUNCTIONALITY
                }) {
                    Text("Forgot Password?")
                        .font(.custom("Poppins-Regular", size: 14))
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .foregroundColor(Color("LighterGray"))
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Toggle Login/Signup
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
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .foregroundColor(Color("LighterGray"))
            }
            .padding(.bottom, 20)
        }
        .background(Color("BrightRed").ignoresSafeArea())
    }
}
#Preview {
    AuthView()
}
