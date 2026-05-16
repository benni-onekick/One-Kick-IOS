//
//  AddCommunitySheet.swift
//  One Kick
//
//  ÄNDERUNG (Milestone A):
//  - Baut nur noch ein "Skelett"-CommunityModel mit name + activeLeagues.
//  - adminId, memberIds und createdAt setzt der CommunityManager selbst.
//  - Trim auf den Namen, sauberer Disabled-State für den Button.
//

import SwiftUI

struct AddCommunitySheet: View {
    var onClose: () -> Void
    var onCommunityCreated: (CommunityModel) -> Void
    
    @State private var name = ""
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Neue Liga erstellen")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    TextField("Name der Liga", text: $name)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    Button(action: {
                        guard !trimmedName.isEmpty else { return }
                        HapticManager.instance.impact(style: .medium)
                        
                        // Nur das Minimum bauen – der Manager kennt den User
                        // und ergänzt adminId / memberIds / createdAt.
                        let newCom = CommunityModel(
                            name: trimmedName,
                            activeLeagues: ["1. Bundesliga"]
                        )
                        onCommunityCreated(newCom)
                        onClose()
                    }) {
                        Text("Erstellen")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                trimmedName.isEmpty
                                ? Color.oneKickNeon.opacity(0.4)
                                : Color.oneKickNeon
                            )
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(trimmedName.isEmpty)
                    
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { onClose() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}
