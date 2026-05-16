//
//  ProfileView.swift
//  One Kick
//

import SwiftUI
import FirebaseAuth

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var showEditName = false
    @State private var showPasswordResetAlert = false
    @State private var passwordResetSent = false

    private var initials: String {
        let name = authManager.displayName ?? authManager.userEmail ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        profileHeader
                        profilSection
                        settingsSection
                        logoutButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Profil & Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
            .sheet(isPresented: $showEditName) {
                EditDisplayNameView().environmentObject(authManager)
            }
            .alert("Passwort zurücksetzen", isPresented: $showPasswordResetAlert) {
                Button("E-Mail senden") { sendPasswordReset() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Wir senden dir einen Link an \(authManager.userEmail ?? "deine E-Mail-Adresse") zum Zurücksetzen deines Passworts.")
            }
            .overlay(alignment: .bottom) {
                if passwordResetSent {
                    Text("✓ E-Mail wurde gesendet")
                        .font(.subheadline).bold()
                        .foregroundColor(.black)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.oneKickNeon)
                        .cornerRadius(20)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: passwordResetSent)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.oneKickNeon.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.oneKickNeon.opacity(0.4), lineWidth: 1.5))
                Text(initials)
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.oneKickNeon)
            }

            VStack(spacing: 4) {
                if let name = authManager.displayName, !name.isEmpty {
                    Text(name)
                        .font(.title3).bold().foregroundColor(.white)
                }
                Text(authManager.userEmail ?? "")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.oneKickDarkGray)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Profil-Sektion

    private var profilSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Mein Profil")
            VStack(spacing: 0) {
                rowButton(title: "Anzeigename ändern", icon: "person.fill") {
                    showEditName = true
                }
                rowDivider
                NavigationLink(destination: FavoriteSettingsView()) {
                    rowContent(title: "Lieblingsligen & -teams", icon: "star.fill")
                }
                .buttonStyle(.plain)
            }
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Einstellungen-Sektion

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Sicherheit")
            VStack(spacing: 0) {
                rowButton(title: "Passwort zurücksetzen", icon: "lock.fill") {
                    showPasswordResetAlert = true
                }
            }
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Ausloggen

    private var logoutButton: some View {
        Button(action: {
            HapticManager.instance.impact(style: .medium)
            authManager.signOut()
            dismiss()
        }) {
            Text("Ausloggen")
                .font(.subheadline).bold()
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.oneKickDarkGray)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Hilfsfunktionen

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray)
            .tracking(0.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private func rowButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.instance.impact(style: .light); action() }) {
            rowContent(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func rowContent(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.oneKickNeon)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rowDivider: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.leading, 56)
    }

    private func sendPasswordReset() {
        guard let email = authManager.userEmail else { return }
        authManager.sendPasswordReset(email: email) { _ in
            Task { @MainActor in
                passwordResetSent = true
                try? await Task.sleep(for: .seconds(2.5))
                passwordResetSent = false
            }
        }
    }
}

// MARK: - EditDisplayNameView

struct EditDisplayNameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var newName = ""
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {

                    // Aktueller Name
                    if let current = authManager.displayName, !current.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktueller Anzeigename")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray).tracking(0.5).textCase(.uppercase)
                            Text(current)
                                .font(.subheadline).bold().foregroundColor(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(14)
                    }

                    // Eingabefeld
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Neuer Anzeigename")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray).tracking(0.5).textCase(.uppercase)

                        TextField("z.B. BennyTippt", text: $newName)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.oneKickDarkGray)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(errorMessage != nil ? Color.orange.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        HStack {
                            if let error = errorMessage {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption).foregroundColor(.orange)
                                Text(error)
                                    .font(.caption).foregroundColor(.orange)
                            } else {
                                Text("3–20 Zeichen, muss eindeutig sein")
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(newName.count)/20")
                                .font(.caption)
                                .foregroundColor(newName.count > 20 ? .orange : .gray)
                        }
                    }

                    // Speichern-Button
                    Button(action: save) {
                        Group {
                            if isChecking {
                                ProgressView().tint(.black)
                            } else if success {
                                Label("Gespeichert", systemImage: "checkmark")
                                    .font(.headline).bold()
                            } else {
                                Text("Speichern")
                                    .font(.headline).bold()
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.oneKickNeon)
                        .cornerRadius(14)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isChecking || success)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Anzeigename ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }

    private func save() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 {
            errorMessage = "Mindestens 3 Zeichen erforderlich."
            return
        }
        if trimmed.count > 20 {
            errorMessage = "Maximal 20 Zeichen erlaubt."
            return
        }
        isChecking = true
        errorMessage = nil

        Task {
            do {
                try await authManager.updateDisplayName(trimmed)
                await MainActor.run {
                    isChecking = false
                    success = true
                    HapticManager.instance.notification(type: .success)
                }
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isChecking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
