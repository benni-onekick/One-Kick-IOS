//
//  AuthManager.swift
//  One Kick
//

import Foundation
import FirebaseAuth
import SwiftUI
import Combine // <--- DAS HAT GEFEHLT! Das repariert den Fehler.

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String? = nil
    
    init() {
        // Lauscht automatisch, ob jemand eingeloggt ist
        _ = Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                self.isAuthenticated = true
                self.userEmail = user.email
            } else {
                self.isAuthenticated = false
                self.userEmail = nil
            }
        }
    }
    
    // MARK: - Einloggen
    func signIn(email: String, pass: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: pass) { result, error in
            completion(error)
        }
    }
    
    // MARK: - Registrieren
    func signUp(email: String, pass: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: pass) { result, error in
            completion(error)
        }
    }
    
    // MARK: - Abmelden
    func signOut() {
        try? Auth.auth().signOut()
    }
}
