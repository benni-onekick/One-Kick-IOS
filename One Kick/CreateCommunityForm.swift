//
//  CreateCommunityForm.swift
//  One Kick
//
//  UI-KOMPONENTE:
//  - Das Design für das Erstellen-Formular.
//  - Enthält: Logo-Upload, Name, Wettbewerb-Auswahl, Einsatz.
//

import SwiftUI

struct CreateCommunityForm: View {
    // Bindings: Daten kommen von der Eltern-View (CreateCommunityView)
    @Binding var groupName: String
    @Binding var groupStake: String
    @Binding var selectedLeagues: Set<String>
    @Binding var communityLogo: UIImage?
    
    // Aktionen: Was passiert beim Tippen?
    var onLogoTap: () -> Void
    var onLeaguesTap: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // 1. LOGO UPLOAD (Runder Kreis mit Kamera/Bild)
                Button(action: {
                    HapticManager.instance.impact(style: .light)
                    onLogoTap()
                }) {
                    ZStack {
                        if let image = communityLogo {
                            // Wenn Bild da ist: Anzeigen
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.oneKickNeon, lineWidth: 2))
                        } else {
                            // Wenn kein Bild: Platzhalter
                            Circle()
                                .fill(Color.oneKickDarkGray)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                )
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        
                        // Kleines Plus Icon (unten rechts am Kreis)
                        Circle()
                            .fill(Color.oneKickNeon)
                            .frame(width: 30, height: 30)
                            .overlay(Image(systemName: "plus").font(.caption).bold().foregroundColor(.black))
                            .offset(x: 35, y: 35)
                    }
                }
                .padding(.top, 20)
                
                // 2. NAME EINGABE
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name der Liga")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.leading, 4)
                    
                    TextField("z.B. Stammtisch Kickers", text: $groupName)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.headline)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // 3. WETTBEWERBE WÄHLEN
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wettbewerbe")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.leading, 4)
                    
                    Button(action: {
                        HapticManager.instance.impact(style: .medium)
                        onLeaguesTap()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wettbewerbe auswählen")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Zeigt an, wie viele gewählt wurden
                                Text(selectedLeagues.isEmpty ? "Keine ausgewählt" : "\(selectedLeagues.count) ausgewählt")
                                    .font(.caption)
                                    .foregroundColor(.oneKickNeon)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                // 4. EINSATZ (Optionales Feld)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Einsatz (Optional)")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.leading, 4)
                    
                    TextField("z.B. Ein Kasten Bier", text: $groupStake)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                Spacer(minLength: 100) // Platzhalter, damit man nicht hinter den Button scrollt
            }
            .padding(.horizontal)
        }
    }
}
