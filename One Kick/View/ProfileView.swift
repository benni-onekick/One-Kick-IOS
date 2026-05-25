//
//  ProfileView.swift
//  One Kick
//

import SwiftUI
import FirebaseAuth
import UserNotifications
import PhotosUI

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @ObservedObject private var userSettings = UserSettings.shared

    @State private var showEditName = false
    @State private var showPasswordResetAlert = false
    @State private var passwordResetSent = false
    @State private var photoItem: PhotosPickerItem? = nil

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
                        tippingSection
                        settingsSection
                        legalSection
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
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        displayName: authManager.displayName ?? authManager.userEmail ?? "?",
                        photoBase64: userSettings.photoBase64,
                        size: 80
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.oneKickNeon.opacity(0.5), lineWidth: 2)
                    )

                    Circle()
                        .fill(Color.oneKickNeon)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await processPickedPhoto(item) }
            }

            VStack(spacing: 4) {
                if let name = authManager.displayName, !name.isEmpty {
                    Text(name)
                        .font(.title3).bold().foregroundColor(.white)
                }
                Text(authManager.userEmail ?? "")
                    .font(.caption).foregroundColor(.gray)
                Text("Foto tippen zum Ändern")
                    .font(.caption2).foregroundColor(.gray.opacity(0.6))
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

    // MARK: - Tippen-Sektion

    private var tippingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Tippen")
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13))
                        .foregroundColor(.oneKickNeon)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Übergreifendes Tippen")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Tipp automatisch in allen Communities mit gleicher Liga speichern")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $userSettings.crossCommunityTipping)
                        .labelsHidden()
                        .tint(.oneKickNeon)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                rowDivider
                HStack(spacing: 12) {
                    Image(systemName: "percent")
                        .font(.system(size: 13))
                        .foregroundColor(.oneKickNeon)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wettquoten anzeigen")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Quoten von Wettanbietern in der Spielübersicht einblenden")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $userSettings.showOdds)
                        .labelsHidden()
                        .tint(.oneKickNeon)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                rowDivider
                NavigationLink(destination: NotificationSettingsView()) {
                    rowContent(title: "Tipperinnerungen", icon: "bell.fill")
                }
                .buttonStyle(.plain)
            }
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Rechtliches

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Rechtliches")
            VStack(spacing: 0) {
                NavigationLink(destination: ImpressumView()) {
                    rowContent(title: "Impressum", icon: "doc.text.fill")
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink(destination: PrivacyPolicyView()) {
                    rowContent(title: "Datenschutz", icon: "lock.shield.fill")
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

    private func processPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        // Auf 120×120px verkleinern und als JPEG komprimieren (~3-8KB)
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        let square = renderer.image { _ in
            let side = min(uiImage.size.width, uiImage.size.height)
            let cropOrigin = CGPoint(
                x: (uiImage.size.width - side) / 2,
                y: (uiImage.size.height - side) / 2
            )
            let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: side, height: side))
            guard let cgImage = uiImage.cgImage?.cropping(to:
                CGRect(x: cropOrigin.x * uiImage.scale,
                       y: cropOrigin.y * uiImage.scale,
                       width: side * uiImage.scale,
                       height: side * uiImage.scale))
            else {
                uiImage.draw(in: CGRect(origin: .zero, size: size))
                return
            }
            UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
            _ = cropRect
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.6) else { return }
        userSettings.photoBase64 = jpeg.base64EncodedString()
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

// MARK: - Tipperinnerungen

struct NotificationSettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var selectedMinutes: Set<Int> = ReminderInterval.load()

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if authStatus != .authorized {
                        permissionBanner
                    }
                    if authStatus == .authorized {
                        reminderSection
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Tipperinnerungen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
    }

    // MARK: - Banner (Berechtigung fehlt)

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(authStatus == .denied
                 ? "Benachrichtigungen deaktiviert"
                 : "Benachrichtigungen aktivieren")
                .font(.headline).bold().foregroundColor(.white)

            Text(authStatus == .denied
                 ? "Du hast Benachrichtigungen für One Kick deaktiviert. Öffne die Einstellungen, um sie wieder zu aktivieren."
                 : "Erlaube Benachrichtigungen, damit One Kick dich erinnern kann, wenn du noch Tipps abgeben musst.")
                .font(.subheadline).foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                if authStatus == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task {
                        _ = await NotificationManager.shared.requestPermission()
                        await refreshStatus()
                    }
                }
            }) {
                Text(authStatus == .denied ? "Einstellungen öffnen" : "Benachrichtigungen erlauben")
                    .font(.subheadline).bold().foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.oneKickNeon).cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.oneKickDarkGray).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Erinnerungszeiten (Mehrfachauswahl)

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erinnerung vor Anpfiff")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                .tracking(0.5).textCase(.uppercase).padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(ReminderInterval.allCases.enumerated()), id: \.element.id) { i, interval in
                    let isSelected = selectedMinutes.contains(interval.rawValue)
                    Button(action: { toggle(interval) }) {
                        HStack(spacing: 14) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .oneKickNeon : .gray)
                            Text(interval.label)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    if i < ReminderInterval.allCases.count - 1 {
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                    }
                }
            }
            .background(Color.oneKickDarkGray).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))

            Text("Mehrere Zeiten möglich. Du wirst nur erinnert, wenn du noch nicht getippt hast. Erinnerungen sind lautlos.")
                .font(.caption).foregroundColor(.gray).padding(.leading, 4)
        }
    }

    // MARK: - Helpers

    private func toggle(_ interval: ReminderInterval) {
        HapticManager.instance.impact(style: .light)
        if selectedMinutes.contains(interval.rawValue) {
            selectedMinutes.remove(interval.rawValue)
        } else {
            selectedMinutes.insert(interval.rawValue)
        }
        ReminderInterval.save(selectedMinutes)
    }

    private func refreshStatus() async {
        authStatus = await NotificationManager.shared.authorizationStatus()
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
