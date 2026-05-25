//
//  CommunityStartMenu.swift
//  One Kick
//

import SwiftUI

struct CommunityStartMenu: View {
    @Environment(\.dismiss) var dismiss
    
    // NEU: Hier holen wir uns den Manager rein, um mit Firebase zu sprechen
    @EnvironmentObject var manager: CommunityManager
    
    @State private var showCreateCommunity = false
    @State private var showJoinCommunity = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Was möchtest du tun?")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    // Button: Liga erstellen
                    Button(action: { showCreateCommunity = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text("Eigene Liga gründen")
                                    .font(.headline)
                                Text("Erstelle eine Tipprunde für deine Freunde")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6).opacity(0.12))
                        .cornerRadius(15)
                        .foregroundColor(.oneKickNeon)
                    }
                    
                    // Button: Liga beitreten
                    Button(action: { showJoinCommunity = true }) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text("Einer Liga beitreten")
                                    .font(.headline)
                                Text("Tritt einer bestehenden Tipprunde bei")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6).opacity(0.12))
                        .cornerRadius(15)
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            
            // --- HIER PASSIERT DIE FIREBASE MAGIE ---
            .sheet(isPresented: $showCreateCommunity) {
                CreateCommunityView(
                    onDismiss: {
                        showCreateCommunity = false
                    },
                    onCreate: { newCommunity in
                        // 1. Speichert die Liga in Firebase!
                        manager.addCommunity(newCommunity)
                        
                        // 2. Schließt die Fenster
                        showCreateCommunity = false
                        dismiss()
                    }
                )
            }
            // ----------------------------------------
            
            .sheet(isPresented: $showJoinCommunity) {
                JoinCommunitySheet().environmentObject(manager)
            }
        }
    }
}
