//
//  LoginView.swift
//  One Kick
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email        = ""
    @State private var password     = ""
    @State private var displayName  = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var nameError:    String?
    @State private var isLoading    = false
    @State private var checkTask:   Task<Void, Never>?
    @State private var currentNonce = ""

    @State private var showResetSheet   = false
    @State private var resetEmail       = ""
    @State private var resetSent        = false
    @State private var resetError:      String?
    @State private var resetLoading     = false

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        Text("ONE KICK")
                            .font(.system(size: 50, weight: .black))
                            .foregroundColor(.oneKickNeon)

                        Picker("", selection: $isRegistering) {
                            Text("Anmelden").tag(false)
                            Text("Registrieren").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 60)

                    VStack(spacing: 15) {
                        if isRegistering {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Anzeigename (wird öffentlich angezeigt)", text: $displayName)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color.oneKickDarkGray)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(nameError != nil
                                                    ? Color.red.opacity(0.7)
                                                    : Color.white.opacity(0.1),
                                                    lineWidth: 1)
                                    )
                                    .onChange(of: displayName) { _, newValue in
                                        nameError = nil
                                        checkTask?.cancel()
                                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                        guard !trimmed.isEmpty else { return }
                                        checkTask = Task {
                                            try? await Task.sleep(for: .seconds(0.6))
                                            guard !Task.isCancelled else { return }
                                            let available = await authManager.checkDisplayNameAvailable(trimmed)
                                            if !available {
                                                nameError = "Der Name \"\(trimmed)\" ist bereits vergeben. Bitte wähle einen anderen."
                                            }
                                        }
                                    }

                                if let ne = nameError {
                                    Text(ne).font(.caption).foregroundColor(.red).padding(.horizontal, 4)
                                }
                            }
                        }

                        TextField("E-Mail Adresse", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.oneKickDarkGray)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1))

                        SecureField("Passwort", text: $password)
                            .padding()
                            .background(Color.oneKickDarkGray)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1))

                        // Passwort vergessen (nur im Login-Modus)
                        if !isRegistering {
                            HStack {
                                Spacer()
                                Button("Passwort vergessen?") {
                                    resetEmail = email
                                    resetSent  = false
                                    resetError = nil
                                    showResetSheet = true
                                }
                                .font(.caption).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: authenticate) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text(isRegistering ? "Account erstellen" : "Einloggen")
                                .font(.headline).bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.oneKickNeon : Color.oneKickNeon.opacity(0.4))
                    .foregroundColor(.black)
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
                    .disabled(!canSubmit || isLoading)

                    // Social Login (in beiden Reitern: Anmelden + Registrieren)
                    HStack {
                        Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.5))
                        Text("oder").font(.caption).foregroundColor(.gray)
                        Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 20)

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = authManager.generateNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authManager.sha256Nonce(nonce)
                    } onCompletion: { result in
                        Task { await authManager.handleAppleSignIn(result: result, nonce: currentNonce) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Mit Google anmelden
                    Button(action: {
                        #if canImport(GoogleSignIn)
                        Task { await authManager.signInWithGoogle() }
                        #endif
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                            Text("Mit Google anmelden")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showResetSheet) {
            passwordResetSheet
        }
    }

    // MARK: - Passwort-Reset Sheet

    private var passwordResetSheet: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 40)).foregroundColor(.oneKickNeon)
                    Text("Passwort zurücksetzen")
                        .font(.title3.bold()).foregroundColor(.white)
                    Text("Gib deine E-Mail-Adresse ein. Du erhältst einen Link zum Zurücksetzen deines Passworts.")
                        .font(.caption).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                if resetSent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50)).foregroundColor(.oneKickNeon)
                        Text("E-Mail gesendet!")
                            .font(.headline.bold()).foregroundColor(.white)
                        Text("Schau in dein Postfach und klicke auf den Link, um ein neues Passwort festzulegen.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        TextField("E-Mail Adresse", text: $resetEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.oneKickDarkGray)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal, 20)

                        if let re = resetError {
                            Text(re).font(.caption).foregroundColor(.red)
                                .multilineTextAlignment(.center).padding(.horizontal)
                        }

                        Button(action: sendReset) {
                            if resetLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Link senden")
                                    .font(.headline.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(resetEmail.isEmpty ? Color.oneKickNeon.opacity(0.4) : Color.oneKickNeon)
                        .foregroundColor(.black)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .disabled(resetEmail.isEmpty || resetLoading)
                    }
                }

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        if isRegistering {
            return !email.isEmpty && !password.isEmpty
                && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
                && nameError == nil
        }
        return !email.isEmpty && !password.isEmpty
    }

    private func authenticate() {
        isLoading    = true
        errorMessage = nil

        if isRegistering {
            let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
            authManager.signUp(email: email, pass: password, displayName: trimmedName) { err in
                isLoading = false
                if let err { errorMessage = err }
            }
        } else {
            authManager.signIn(email: email, pass: password) { error in
                isLoading = false
                if let error { errorMessage = error.localizedDescription }
            }
        }
    }

    private func sendReset() {
        resetLoading = true
        resetError   = nil
        authManager.sendPasswordReset(email: resetEmail) { err in
            resetLoading = false
            if let err {
                resetError = err
            } else {
                resetSent = true
            }
        }
    }
}
