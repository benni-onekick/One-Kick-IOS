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
    @Published var isAuthenticated = false
    @Published var userEmail: String?      = nil
    @Published var displayName: String?    = nil

    private let db = Firestore.firestore()

    init() {
        _ = Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                self.isAuthenticated = true
                self.userEmail = user.email
                Task { await self.loadDisplayName(uid: user.uid) }
            } else {
                self.isAuthenticated = false
                self.userEmail       = nil
                self.displayName     = nil
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

                await MainActor.run {
                    self.displayName = displayName
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

    // MARK: - Anzeigename prüfen (true = verfügbar)
    func checkDisplayNameAvailable(_ name: String) async -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let doc = try? await db.collection("usernames")
            .document(name.lowercased()).getDocument()
        return !(doc?.exists ?? false)
    }

    // MARK: - Anzeigename aus Firestore laden
    private func loadDisplayName(uid: String) async {
        let doc  = try? await db.collection("users").document(uid).getDocument()
        let name = doc?.data()?["displayName"] as? String
        await MainActor.run { self.displayName = name }
    }
}
