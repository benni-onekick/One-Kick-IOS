//
//  LoginView.swift
//  One Kick
//

import SwiftUI

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

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 5) {
                        Text("ONE KICK")
                            .font(.system(size: 50, weight: .black))
                            .foregroundColor(.oneKickNeon)
                        Text(isRegistering ? "Neuen Account erstellen" : "Willkommen zurück")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)

                    VStack(spacing: 15) {
                        // Anzeigename nur bei Registrierung
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
                                    Text(ne)
                                        .font(.caption).foregroundColor(.red)
                                        .padding(.horizontal, 4)
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

                    Button(action: {
                        withAnimation {
                            isRegistering.toggle()
                            errorMessage = nil
                            nameError    = nil
                            displayName  = ""
                        }
                    }) {
                        Text(isRegistering
                             ? "Ich habe schon einen Account"
                             : "Noch keinen Account? Registrieren")
                            .font(.caption).foregroundColor(.gray)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }

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
}
