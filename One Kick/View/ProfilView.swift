//
//  ProfilView.swift
//  One Kick
//

import SwiftUI

struct ProfilView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Mein Account")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Benni")
                                .font(.headline)
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
                    Text("Ausloggen")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Profil & Einstellungen")
            .toolbar {
                Button("Fertig") { dismiss() }
            }
        }
    }
}

#Preview {
    ProfilView()
}
