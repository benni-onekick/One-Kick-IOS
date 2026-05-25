//
//  AuthManager.swift
//  One Kick
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated   = false
    @Published var isEmailVerified   = false
    @Published var userEmail: String?      = nil
    @Published var displayName: String?    = nil

    private let db = Firestore.firestore()

    init() {
        _ = Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                self.isAuthenticated = true
                self.isEmailVerified = user.isEmailVerified
                self.userEmail = user.email
                Task { await self.loadDisplayName(uid: user.uid) }
                UserSettings.shared.loadFromFirebase(uid: user.uid)
            } else {
                self.isAuthenticated   = false
                self.isEmailVerified   = false
                self.userEmail         = nil
                self.displayName       = nil
                UserSettings.shared.clearPhoto()
            }
        }
    }

    // MARK: - Einloggen
    func signIn(email: String, pass: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: pass) { _, error in
            completion(error)
        }
    }

    // MARK: - Registrieren (mit Anzeigename)
    func signUp(email: String, pass: String, displayName: String,
                completion: @escaping (String?) -> Void) {
        Task {
            // 1. Anzeigename auf Verfügbarkeit prüfen
            let available = await checkDisplayNameAvailable(displayName)
            guard available else {
                await MainActor.run {
                    completion("Der Name ist bereits vergeben. Bitte wähle einen anderen.")
                }
                return
            }

            // 2. Firebase Auth Nutzer anlegen
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: pass)
                let uid    = result.user.uid

                // 3. Anzeigename in Firestore sichern
                try await db.collection("users").document(uid).setData([
                    "displayName": displayName,
                    "email": email
                ])
                // Reservierungs-Dokument für Eindeutigkeit (lowercase key)
                try await db.collection("usernames")
                    .document(displayName.lowercased()).setData(["uid": uid])

                // 4. Firebase Auth Profil aktualisieren
                let req = result.user.createProfileChangeRequest()
                req.displayName = displayName
                try await req.commitChanges()

                // 5. Verifizierungsmail senden
                try? await result.user.sendEmailVerification()

                await MainActor.run {
                    self.displayName     = displayName
                    self.isEmailVerified = false
                    completion(nil)
                }
            } catch {
                await MainActor.run { completion(error.localizedDescription) }
            }
        }
    }

    // MARK: - Abmelden
    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Verifizierungsstatus neu laden
    func reloadVerificationStatus() async {
        try? await Auth.auth().currentUser?.reload()
        await MainActor.run {
            self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
        }
    }

    // MARK: - Verifizierungsmail erneut senden
    func resendVerificationEmail(completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        user.sendEmailVerification { error in
            completion(error?.localizedDescription)
        }
    }

    // MARK: - Passwort zurücksetzen
    func sendPasswordReset(email: String, completion: @escaping (String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error?.localizedDescription)
        }
    }

    // MARK: - Anzeigename ändern
    func updateDisplayName(_ newName: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Nicht eingeloggt."])
        }
        // Eigenen aktuellen Namen nicht als "vergeben" werten
        let available = await checkDisplayNameAvailable(newName, excludingUid: user.uid)
        guard available else {
            throw NSError(domain: "AuthManager", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Dieser Name ist bereits vergeben."])
        }

        // Alte Reservierung löschen
        if let old = displayName {
            try? await db.collection("usernames").document(old.lowercased()).delete()
        }

        // setData(merge: true) statt updateData – erstellt Dokument falls noch keins existiert
        try await db.collection("users").document(user.uid)
            .setData(["displayName": newName, "email": user.email ?? ""], merge: true)
        try await db.collection("usernames")
            .document(newName.lowercased()).setData(["uid": user.uid])

        // Firebase Auth Profil
        let req = user.createProfileChangeRequest()
        req.displayName = newName
        try await req.commitChanges()

        await MainActor.run { self.displayName = newName }
    }

    // MARK: - Anzeigename prüfen (true = verfügbar)
    // excludingUid: eigener Name zählt nicht als "vergeben"
    func checkDisplayNameAvailable(_ name: String, excludingUid: String? = nil) async -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let doc = try? await db.collection("usernames")
            .document(name.lowercased()).getDocument(), doc.exists else {
            return true
        }
        if let uid = excludingUid,
           let existingUid = doc.data()?["uid"] as? String,
           existingUid == uid {
            return true
        }
        return false
    }

    // MARK: - Anzeigename aus Firestore laden
    private func loadDisplayName(uid: String) async {
        let doc  = try? await db.collection("users").document(uid).getDocument()
        let name = doc?.data()?["displayName"] as? String
        await MainActor.run { self.displayName = name }
    }
}
