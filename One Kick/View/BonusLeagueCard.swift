//
//  BonusLeagueCard.swift
//  One Kick
//
//  Aufklappbare Bonus-Karte pro Liga. Admin kann Kategorien ein-/ausschalten.
//

import SwiftUI

// MARK: - Bonus-Antwort-Modell (geteilt zwischen Punkte- und BonusTipp-View)

struct UserBonusEntry: Identifiable {
    let id: String           // userId / Firestore-Dokument-ID
    let displayName: String
    let answers: [String: String]   // "Liga|Kategorie": "Antwort"
}

// Alle möglichen Bonus-Kategorien (modul-weit, auch für CommunitySettingsView)
let allBonusCategories: [String] = [
    "Finalisten tippen",
    "Halbfinalisten tippen",
    "Torschützenkönig",
    "Meiste Vorlagen",
    "Meiste Tore (Team)",
    "Meiste Gegentore",
    "Endtabelle",
    "Meiste Aluminium-Treffer",
    "Meiste Karten",
    "Meiste Zu-Null-Spiele"
]

let koLeagueNames: Set<String> = [
    "Champions League", "Europa League", "Conference League",
    "DFB-Pokal", "FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France",
    "Weltmeisterschaft", "Europameisterschaft", "Nations League",
    "WM Qualifikation", "EM Qualifikation",
    "Frauen Champions League", "Frauen WM", "Frauen EM"
]

/// Gibt die aktiven Bonus-Kategorien für eine Liga zurück (gefiltert nach activeCategorySet).
func bonusCategoriesForLeague(_ leagueName: String, activeCategorySet: Set<String>) -> [String] {
    let isKO = koLeagueNames.contains(leagueName)
    var cats: [String] = isKO
        ? ["Finalisten tippen", "Halbfinalisten tippen", "Torschützenkönig", "Meiste Vorlagen",
           "Meiste Tore (Team)", "Meiste Gegentore"]
        : ["Torschützenkönig", "Meiste Vorlagen", "Meiste Tore (Team)", "Meiste Gegentore", "Endtabelle"]
    cats += ["Meiste Aluminium-Treffer", "Meiste Karten", "Meiste Zu-Null-Spiele"]
    return cats.filter { activeCategorySet.contains($0) }
}

struct BonusLeagueCard: View {
    let leagueName: String
    // nil = alle Kategorien aktiv; Set = nur diese aktiv
    var enabledCategories: Set<String>? = nil

    @State private var isExpanded = false

    private var isKO: Bool { koLeagueNames.contains(leagueName) }

    private var allCategoriesForLeague: [(icon: String, title: String, color: Color)] {
        var result: [(String, String, Color)] = []
        if isKO {
            result.append(("trophy.fill",           "Finalisten tippen",      .yellow))
            result.append(("medal.fill",            "Halbfinalisten tippen",  Color(white: 0.75)))
            result.append(("person.fill",           "Torschützenkönig",       .oneKickNeon))
            result.append(("figure.stand",          "Meiste Vorlagen",        .cyan))
            result.append(("arrow.up.right",        "Meiste Tore (Team)",     .orange))
            result.append(("arrow.down.right",      "Meiste Gegentore",       .red.opacity(0.8)))
        } else {
            result.append(("person.fill",           "Torschützenkönig",       .oneKickNeon))
            result.append(("figure.stand",          "Meiste Vorlagen",        .cyan))
            result.append(("arrow.up.right",        "Meiste Tore (Team)",     .orange))
            result.append(("arrow.down.right",      "Meiste Gegentore",       .red.opacity(0.8)))
            result.append(("tablecells",            "Endtabelle",     .blue.opacity(0.8)))
        }
        result.append(("circle.fill",               "Meiste Aluminium-Treffer", .gray))
        result.append(("rectangle.badge.minus",     "Meiste Karten",            Color(red: 0.9, green: 0.3, blue: 0.2)))
        result.append(("shield.lefthalf.filled",    "Meiste Zu-Null-Spiele",    .teal))
        return result
    }

    private var categories: [(icon: String, title: String, color: Color)] {
        guard let enabled = enabledCategories else { return allCategoriesForLeague }
        return allCategoriesForLeague.filter { enabled.contains($0.1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: isKO ? "trophy.circle.fill" : "soccerball")
                        .font(.system(size: 20))
                        .foregroundColor(isKO ? .yellow : .oneKickNeon)
                        .frame(width: 36, height: 36)
                        .background((isKO ? Color.yellow : Color.oneKickNeon).opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(leagueName).font(.subheadline).bold().foregroundColor(.white).lineLimit(1)
                        Text(isKO ? "KO-Liga" : "Reguläre Saison").font(.caption2).foregroundColor(.gray)
                    }

                    Spacer()

                    if categories.isEmpty {
                        Text("Keine Kategorien").font(.caption).foregroundColor(.gray.opacity(0.5))
                    } else {
                        Text("\(categories.count) Kategorien").font(.caption).foregroundColor(.gray)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundColor(.gray)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded && !categories.isEmpty {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)

                VStack(spacing: 2) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 13)).foregroundColor(cat.color)
                                .frame(width: 28, height: 28)
                                .background(cat.color.opacity(0.12)).clipShape(Circle())
                            Text(cat.title).font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.oneKickDarkGray)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - BonusAnswerCard (Punkteübersicht: zeigt alle Tipps nach Ligastart)

struct BonusAnswerCard: View {
    let leagueName: String
    var enabledCategories: Set<String>? = nil
    let entries: [UserBonusEntry]

    @State private var isExpanded = false

    private var isKO: Bool { koLeagueNames.contains(leagueName) }

    private var categories: [String] {
        var cats: [String] = isKO
            ? ["Finalisten tippen", "Halbfinalisten tippen", "Torschützenkönig", "Meiste Vorlagen",
               "Meiste Tore (Team)", "Meiste Gegentore"]
            : ["Torschützenkönig", "Meiste Vorlagen", "Meiste Tore (Team)", "Meiste Gegentore", "Endtabelle"]
        cats += ["Meiste Aluminium-Treffer", "Meiste Karten", "Meiste Zu-Null-Spiele"]
        guard let enabled = enabledCategories else { return cats }
        return cats.filter { enabled.contains($0) }
    }

    private struct AnswerItem {
        let name: String
        let answer: String
        let isEmpty: Bool
    }

    private func answers(for category: String) -> [AnswerItem] {
        let key = "\(leagueName)|\(category)"
        return entries.map { e in
            let a = e.answers[key] ?? ""
            return AnswerItem(name: e.displayName, answer: a.isEmpty ? "–" : a, isEmpty: a.isEmpty)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14)).foregroundColor(.gray)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.12)).clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(leagueName).font(.subheadline).bold().foregroundColor(.white).lineLimit(1)
                        Text("Gestartet – Tipps aller sichtbar").font(.caption2).foregroundColor(.gray)
                    }

                    Spacer()
                    Text("\(entries.count) Tipper").font(.caption).foregroundColor(.gray)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundColor(.gray)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        let items = answers(for: category)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(category)
                                .font(.caption.bold()).foregroundColor(.gray)
                                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)

                            ForEach(items, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                    Text(item.answer)
                                        .font(.subheadline)
                                        .foregroundColor(item.isEmpty ? .gray.opacity(0.5) : .oneKickNeon)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 5)
                            }
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.oneKickDarkGray)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
