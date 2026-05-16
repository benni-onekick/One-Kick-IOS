//
//  AllOpenGamesView.swift
//  One Kick
//
//  UPDATE:
//  - Zeigt alle offenen Spiele untereinander.
//  - Nutzt jetzt das neue RapidAPI 'MatchData' Modell.
//  - "Tippen" öffnet das 'BettingPopupView'.
//

import SwiftUI

struct AllOpenGamesView: View {
    let matches: [MatchData]
    var communityId: String = ""
    
    @Environment(\.dismiss) var dismiss
    
    // Popup Steuerung
    @State private var showPopup = false
    // ÄNDERUNG 2: Erwartet nun MatchData
    @State private var selectedMatchForPopup: MatchData?
    
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // HEADER (Zurück + Titel)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.oneKickDarkGray)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Offene Tipps")
                        .font(.headline).bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Dummy Spacer für Symmetrie
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding()
                
                // LISTE DER SPIELE
                ScrollView {
                    LazyVStack(spacing: 15) {
                        // ÄNDERUNG 3: ForEach braucht eine explizite ID, da MatchData nicht Identifiable ist
                        ForEach(matches, id: \.fixture.id) { match in
                            // Wir nutzen die existierende Row-Komponente
                            ApiMatchRow(match: match) {
                                // ACTION: Wenn "Tippen" gedrückt wird
                                selectedMatchForPopup = match
                                showPopup = true
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // DAS POPUP OVERLAY
            if showPopup, let match = selectedMatchForPopup {
                // ACHTUNG: BettingPopupView muss ebenfalls MatchData als Input akzeptieren!
                BettingPopupView(isPresented: $showPopup, match: match, communityId: communityId)
                    .zIndex(2) // Liegt über allem
            }
        }
        .navigationBarHidden(true)
    }
}
