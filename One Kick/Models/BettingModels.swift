//
//  BettingModels.swift
//  One Kick
//
//  ZENTRALE DATENMODELLE:
//  Hier liegen alle Strukturen für das Tippspiel und die API.
//  Das verhindert "Redeclaration" und "Ambiguous Type" Fehler.
//

import Foundation

// --- UI MODELL (Wird in der View angezeigt) ---
enum MatchState {
    case future   // Spiel liegt in der Zukunft
    case live     // Spiel läuft gerade
    case finished // Spiel ist beendet
}

struct BettingMatch: Identifiable {
    let id: UUID
    let home: String
    let away: String
    let homeIcon: String
    let awayIcon: String
    let date: String    // z.B. "Sa. 12.01."
    let time: String    // z.B. "15:30"
    let league: String
    let state: MatchState
    var resultScore: String? // z.B. "2:1"
    var userPoints: Int?     // z.B. 3 (für Volltreffer)
}

// --- JSON MODELLE (Nur für den API-Download nötig) ---
// Diese spiegeln exakt die Struktur von api.openligadb.de wider

struct OLMatch: Codable {
    let matchID: Int
    let team1: OLTeam
    let team2: OLTeam
    let matchDateTime: String
    // 🚨 HIER IST DER FIX: Das Fragezeichen macht das Feld optional!
    let isFinished: Bool?
    let matchResults: [OLResult]
}

struct OLTeam: Codable {
    let teamName: String
    let teamIconUrl: String
}

struct OLResult: Codable {
    let pointsTeam1: Int
    let pointsTeam2: Int
}
