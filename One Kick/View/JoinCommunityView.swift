//
//  JoinCommunityView.swift
//  One Kick
//
//  FIX:
//  - Nutzt jetzt 'CommunityModel'.
//  - Ruft die neue Funktion 'createAndOpen' korrekt auf.
//

import SwiftUI
import Combine

struct JoinCommunityView: View {
    @EnvironmentObject var manager: CommunityManager
    @Environment(\.dismiss) var dismiss // Zum Schließen des Fensters
    
    @State private var communityName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Liga beitreten oder gründen")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    // Eingabefeld
                    TextField("Name der Liga", text: $communityName)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    // Button: Erstellen & Öffnen
                    Button(action: {
                        if !communityName.isEmpty {
                            // Ruft die Funktion auf, die wir gerade im Manager ergänzt haben
                            manager.createAndOpen(name: communityName)
                            dismiss() // Fenster schließen
                        }
                    }) {
                        Text("Erstellen & Öffnen")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.oneKickNeon)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(communityName.isEmpty)
                    
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}
