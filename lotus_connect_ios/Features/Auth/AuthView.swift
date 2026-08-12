//
//  AuthView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//
import ComposableArchitecture
import SwiftUI

public struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>
    
    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "lotus.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                        
                        Text("Lotus Connect")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        Text(store.isRegisterMode ? "Create a new account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 40)
                    
                    if let errorMessage = store.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triagle.fill")
                            Text(errorMessage)
                                .font(.footnote)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                    }
                    
                    VStack(spacing: 16) {
                        if store.isRegisterMode {
                            CustomTextField(icon: "person.fill", placeholder: "Username", text: $store.usernameText)
                            CustomTextField(icon: "person.crop.square.fill", placeholder: "Full Name", text: $store.fullNameText)
                        }
                        CustomTextField(icon: "envelope", placeholder: "Email", text: $store.emailText)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $store.passwordText)
                        
                        Button {
                            store.send(.submitButtonTapped)
                        } label: {
                            HStack {
                                if store.isLoading {
                                    ProgressView()
                                        .tint(.blue)
                                } else {
                                    Text(store.isRegisterMode ? "Sign Up" : "Sign In")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        }
                        .disabled(store.isLoading)
                    }
                    .padding(24)
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    Button {
                        store.send(.toggleRegisterMode)
                    } label: {
                        Text(store.isRegisterMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { store.send(.onAppear)}
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemBackground)).opacity(0.9)
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary)
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(10)
    }
}
