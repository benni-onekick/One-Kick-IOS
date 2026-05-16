//
//  LoginView.swift
//  One Kick
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo / Titel
                VStack(spacing: 5) {
                    Text("ONE KICK")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(.oneKickNeon)
                    
                    Text(isRegistering ? "Neuen Account erstellen" : "Willkommen zurück")
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
                
                // Eingabefelder
                VStack(spacing: 15) {
                    TextField("E-Mail Adresse", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none) // Wichtig für E-Mails!
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    SecureField("Passwort", text: $password)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                
                // Fehlermeldung (falls Passwort falsch etc.)
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Haupt-Button
                Button(action: authenticate) {
                    Text(isRegistering ? "Account erstellen" : "Einloggen")
                        .font(.headline).bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.oneKickNeon)
                        .foregroundColor(.black)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                
                // Wechseln zwischen Login und Registrierung
                Button(action: {
                    isRegistering.toggle()
                    errorMessage = nil // Fehler zurücksetzen
                }) {
                    Text(isRegistering ? "Ich habe schon einen Account" : "Noch keinen Account? Registrieren")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
    }
    
    // Führt die Aktion im AuthManager aus
    func authenticate() {
        if isRegistering {
            authManager.signUp(email: email, pass: password) { error in
                if let error = error { self.errorMessage = error.localizedDescription }
            }
        } else {
            authManager.signIn(email: email, pass: password) { error in
                if let error = error { self.errorMessage = error.localizedDescription }
            }
        }
    }
}
