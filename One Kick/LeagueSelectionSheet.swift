//
//  LeagueSelectionSheet.swift
//  One Kick
//
//  FIX:
//  - 'LeagueCategory' Struktur wieder hinzugefügt (behebt den Fehler "Cannot find type LeagueCategory").
//  - 'LeagueSelectionChip' weggelassen (da er schon in CommunitySettingsView oder global existiert).
//

import SwiftUI
import Combine

struct LeagueSelectionSheet: View {
    @Binding var selectedLeagues: Set<String>
    @Environment(\.dismiss) var dismiss
    
    // Die kompletten Liga-Daten nach Kategorien
    // FEHLER BEHOBEN: LeagueCategory ist jetzt unten definiert!
    let categories: [LeagueCategory] = [
        LeagueCategory(name: "Deutscher Fußball", leagues: ["1. Bundesliga", "2. Bundesliga", "3. Liga", "DFB-Pokal"]),
        LeagueCategory(name: "International (Club)", leagues: ["Champions League", "Europa League", "Conference League"]),
        LeagueCategory(name: "Nationalmannschaften", leagues: ["Weltmeisterschaft", "Europameisterschaft", "Nations League", "WM Qualifikation", "EM Qualifikation"]),
        LeagueCategory(name: "Frauenfußball", leagues: ["1. Frauen-Bundesliga", "Frauen Champions League", "Frauen WM", "Frauen EM"]),
        LeagueCategory(name: "Europäische Top-Ligen", leagues: ["Premier League", "La Liga", "Serie A", "Ligue 1", "Eredivisie", "Liga Portugal", "Super League", "Süper Lig", "Österreich Liga"]),
        LeagueCategory(name: "Internationale Ligen", leagues: ["MLS", "Saudi Pro League"]),
        LeagueCategory(name: "Europäische Pokale", leagues: ["FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France"])
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Hintergrund: One Kick Black
                Color.oneKickBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.name) { idx, category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.name.uppercased())
                                    .font(.caption).bold()
                                    .foregroundColor(.oneKickNeon)
                                    .padding(.leading, 5)
                                    .padding(.horizontal)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                    ForEach(category.leagues, id: \.self) { league in
                                        LeagueSelectionChip(
                                            title: league,
                                            isSelected: selectedLeagues.contains(league),
                                            onTap: { toggle(league) }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 20)

                            if idx < categories.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Wettbewerbe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        HapticManager.instance.impact(style: .light)
                        dismiss()
                    }
                    .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
        }
    }
    
    func toggle(_ league: String) {
        HapticManager.instance.impact(style: .light)
        if selectedLeagues.contains(league) {
            selectedLeagues.remove(league)
        } else {
            selectedLeagues.insert(league)
        }
    }
}

// ---------------------------------------------------------
// DATENSTRUKTUR (WICHTIG: Das hier hat gefehlt!)
// ---------------------------------------------------------
struct LeagueCategory {
    let name: String
    let leagues: [String]
}

// HINWEIS: Hier steht KEIN 'struct LeagueSelectionChip',
// da du diesen Baustein bereits in CommunitySettingsView hast.
// Das verhindert den "Redeclaration"-Fehler.
