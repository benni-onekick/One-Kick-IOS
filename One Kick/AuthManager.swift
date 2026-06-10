//
//  AuthManager.swift
//  One Kick
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class AuthManager: ObservableObject {
    @Published var isAuthenticated   = false
    @Published var isEmailVerified   = false
    @Published var userEmail: String?      = nil
    @Published var displayName: String?    = nil
    @Published var isFirstLogin: Bool      = false

    private let db = Firestore.firestore()

    init() {
        _ = Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                let uid = user.uid
                let welcomed = UserDefaults.standard.bool(forKey: "welcomed_\(uid)")
                self.isFirstLogin = !welcomed
                if !welcomed {
                    UserDefaults.standard.set(true, forKey: "welcomed_\(uid)")
                }
                self.isAuthenticated = true
                self.isEmailVerified = user.isEmailVerified
                self.userEmail = user.email
                Task { await self.loadDisplayName(uid: uid) }
                UserSettings.shared.loadFromFirebase(uid: uid)
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

                // 5. Verifizierungsmail senden (Deutsch → landet seltener im Spam)
                Auth.auth().languageCode = "de"
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

    // MARK: - E-Mail-Verifizierung erneut senden
    func sendEmailVerificationEmail(completion: @escaping (Error?) -> Void) {
        Auth.auth().currentUser?.sendEmailVerification(completion: completion)
    }

    // MARK: - Verifizierungsstatus neu laden
    func reloadUser(completion: @escaping () -> Void) {
        Auth.auth().currentUser?.reload { _ in
            if let user = Auth.auth().currentUser {
                DispatchQueue.main.async {
                    self.isEmailVerified = user.isEmailVerified
                    if user.isEmailVerified { self.isAuthenticated = true }
                    completion()
                }
            }
        }
    }

    // MARK: - Abmelden
    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Account löschen
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Nicht eingeloggt."])
        }
        let uid = user.uid

        // 1. Alle Communities des Users laden
        let communitiesSnapshot = try await db.collection("communities")
            .whereField("memberIds", arrayContains: uid)
            .getDocuments()

        for doc in communitiesSnapshot.documents {
            let communityId = doc.documentID
            let communityRef = db.collection("communities").document(communityId)

            // Bets löschen (query by userId)
            if let betsSnapshot = try? await communityRef
                .collection("bets")
                .whereField("userId", isEqualTo: uid)
                .getDocuments() {
                for bet in betsSnapshot.documents {
                    try? await bet.reference.delete()
                }
            }

            // BonusBet löschen
            try? await communityRef.collection("bonusBets").document(uid).delete()

            // User aus memberIds entfernen
            try? await communityRef.updateData([
                "memberIds": FieldValue.arrayRemove([uid])
            ])
        }

        // 2. User-Dokument löschen
        try? await db.collection("users").document(uid).delete()

        // 3. Username-Reservierung löschen
        if let name = displayName {
            try? await db.collection("usernames").document(name.lowercased()).delete()
        }

        // 4. Firebase Auth User löschen (muss zuletzt passieren)
        try await user.delete()
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

    // MARK: - Nonce-Hilfsfunktionen (Apple Sign-In)

    func generateNonce() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = 32
        while remaining > 0 {
            (0..<16).map { _ -> UInt8 in
                var r: UInt8 = 0
                SecRandomCopyBytes(kSecRandomDefault, 1, &r)
                return r
            }.forEach { r in
                guard remaining > 0 else { return }
                if r < charset.count { result.append(charset[Int(r)]); remaining -= 1 }
            }
        }
        return result
    }

    func sha256Nonce(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Apple Sign-In

    @MainActor
    func handleAppleSignIn(result: Result<ASAuthorization, Error>, nonce: String) async {
        guard case .success(let auth) = result,
              let cred   = auth.credential as? ASAuthorizationAppleIDCredential,
              let idData = cred.identityToken,
              let idToken = String(data: idData, encoding: .utf8) else { return }

        let firebaseCred = OAuthProvider.appleCredential(
            withIDToken: idToken, rawNonce: nonce, fullName: cred.fullName)

        do {
            let authResult = try await Auth.auth().signIn(with: firebaseCred)
            let given  = cred.fullName?.givenName  ?? ""
            let family = cred.fullName?.familyName ?? ""
            let name   = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            let email  = cred.email ?? authResult.user.email ?? ""
            await ensureUserInFirestore(uid: authResult.user.uid,
                                        displayName: name.isEmpty ? "Nutzer" : name,
                                        email: email)
        } catch {
            print("Apple Firebase sign-in Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign-In

    #if canImport(GoogleSignIn)
    @MainActor
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let cred = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: cred)
            let name  = result.user.profile?.name  ?? "Nutzer"
            let email = result.user.profile?.email ?? authResult.user.email ?? ""
            await ensureUserInFirestore(uid: authResult.user.uid,
                                        displayName: name, email: email)
        } catch {
            print("Google sign-in Fehler: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Neuen Social-Login-Nutzer in Firestore anlegen (nur beim ersten Mal)

    private func ensureUserInFirestore(uid: String, displayName proposedName: String, email: String) async {
        let doc = try? await db.collection("users").document(uid).getDocument()
        guard doc?.exists == false else { return }

        // Einzigartigen Anzeigenamen sicherstellen
        var name = proposedName
        var counter = 1
        while !(await checkDisplayNameAvailable(name)) {
            name = "\(proposedName)\(counter)"
            counter += 1
        }
        try? await db.collection("users").document(uid).setData(["displayName": name, "email": email])
        try? await db.collection("usernames").document(name.lowercased()).setData(["uid": uid])
        await MainActor.run { self.displayName = name }
    }
}
