//
//  BonusScoringEngine.swift
//  One Kick
//
//  Berechnet Bonus-Punkte pro Kategorie anhand von Admin-Musterlösungen.
//  Punktwerte (festgelegt vom Community-Admin):
//    • Einzelwert-Kategorien:   10 Pkt bei exakter Übereinstimmung
//    • Endtabelle:              5 Pkt pro korrekt getippter Position,
//                               +25 Pkt Bonus wenn ALLE Positionen korrekt
//    • Finalisten tippen:       10 Pkt pro korrekt getipptem Team (max 20)
//    • Halbfinalisten tippen:   10 Pkt pro korrekt getipptem Team (max 40)
//

import Foundation

struct BonusScoringEngine {

    static func score(
        userAnswer: String,
        correctAnswer: String,
        category: String
    ) -> Int {
        let user    = userAnswer.trimmingCharacters(in: .whitespaces)
        let correct = correctAnswer.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty, !correct.isEmpty else { return 0 }

        switch category {
        case "Sieger tippen":
            return user.lowercased() == correct.lowercased() ? 20 : 0

        case "Torschützenkönig",
             "Meiste Vorlagen",
             "Meiste Tore (Team)",
             "Meiste Gegentore",
             "Meiste Aluminium-Treffer",
             "Meiste Karten",
             "Meiste Zu-Null-Spiele":
            return user.lowercased() == correct.lowercased() ? 10 : 0

        case "Endtabelle":
            return scoreEndtabelle(user: user, correct: correct)

        case "Finalisten tippen":
            return scoreMultiPick(user: user, correct: correct, ptsEach: 10)

        case "Halbfinalisten tippen":
            return scoreMultiPick(user: user, correct: correct, ptsEach: 10)

        default:
            if category.hasPrefix("WM Gruppe ") {
                return scoreWmGroup(user: user, correct: correct)
            }
            return 0
        }
    }

    /// WM-Gruppen: 2 Punkte pro korrekt platzierter Nation
    private static func scoreWmGroup(user: String, correct: String) -> Int {
        let u = user.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let c = correct.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var pts = 0
        for (i, team) in c.enumerated() {
            if i < u.count && u[i] == team { pts += 2 }
        }
        return pts
    }

    private static func scoreEndtabelle(user: String, correct: String) -> Int {
        let u = user.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let c = correct.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var pts = 0
        for (i, team) in c.enumerated() {
            if i < u.count && u[i] == team { pts += 5 }
        }
        if u == c { pts += 25 }
        return pts
    }

    private static func scoreMultiPick(user: String, correct: String, ptsEach: Int) -> Int {
        let u = Set(user.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        let c = Set(correct.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        return u.intersection(c).count * ptsEach
    }
}
