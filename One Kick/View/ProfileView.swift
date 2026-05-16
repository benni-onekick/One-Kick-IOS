//
//  ProfileView.swift
//  One Kick
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager // <--- NEU: Wir holen uns den AuthManager
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Mein Account")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            // NEU: Zeigt deine echte E-Mail-Adresse an
                            Text(authManager.userEmail ?? "Spieler")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("Pro Mitglied")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 5)
                    
                    Text("Profil bearbeiten")
                }
                
                Section(header: Text("App Einstellungen")) {
                    Toggle("Benachrichtigungen", isOn: .constant(true))
                    Toggle("Dark Mode", isOn: .constant(false))

                    NavigationLink {
                        FavoriteSettingsView()
                    } label: {
                        Label("Lieblingsligen & -teams", systemImage: "star.fill")
                            .foregroundColor(.primary)
                    }
                }
                
                Section {
                    // NEU: Der funktionierende Ausloggen-Button
                    Button(action: {
                        HapticManager.instance.impact(style: .medium)
                        authManager.signOut() // Meldet dich bei Firebase ab
                        dismiss() // Schließt das kleine Profil-Fenster
                    }) {
                        Text("Ausloggen")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profil & Einstellungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
        }
    }
}
