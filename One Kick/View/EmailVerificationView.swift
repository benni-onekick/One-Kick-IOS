//
//  EmailVerificationView.swift
//  One Kick
//
//  Erscheint nach der Registrierung, bis die E-Mail verifiziert wurde.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var isChecking     = false
    @State private var resendMessage: String?
    @State private var resendSuccess  = false

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.oneKickNeon)

                VStack(spacing: 8) {
                    Text("E-Mail bestätigen")
                        .font(.title2.bold()).foregroundColor(.white)
                    Text("Wir haben eine Bestätigungsmail an")
                        .font(.subheadline).foregroundColor(.gray)
                    Text(authManager.userEmail ?? "")
                        .font(.subheadline.bold()).foregroundColor(.white)
                    Text("gesendet. Klicke auf den Link in der Mail, um fortzufahren.")
                        .font(.caption).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                // Bereits verifiziert? App freischalten
                Button(action: {
                    isChecking = true
                    Task {
                        await authManager.reloadVerificationStatus()
                        isChecking = false
                        if !authManager.isEmailVerified {
                            resendMessage = "Noch nicht verifiziert. Bitte prüfe dein Postfach."
                            resendSuccess = false
                        }
                    }
                }) {
                    if isChecking {
                        ProgressView().tint(.black)
                    } else {
                        Text("Ich habe die Mail bestätigt")
                            .font(.headline.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.oneKickNeon)
                .foregroundColor(.black)
                .cornerRadius(15)
                .padding(.horizontal, 30)
                .disabled(isChecking)

                // Mail erneut senden
                Button(action: {
                    authManager.resendVerificationEmail { err in
                        if err == nil {
                            resendMessage = "Mail wurde erneut gesendet."
                            resendSuccess = true
                        } else {
                            resendMessage = err
                            resendSuccess = false
                        }
                    }
                }) {
                    Text("Mail erneut senden")
                        .font(.subheadline).foregroundColor(.gray)
                }

                if let msg = resendMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(resendSuccess ? .oneKickNeon : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: { authManager.signOut() }) {
                    Text("Abmelden")
                        .font(.caption).foregroundColor(.gray.opacity(0.6))
                }
                .padding(.bottom, 30)
            }
        }
    }
}
