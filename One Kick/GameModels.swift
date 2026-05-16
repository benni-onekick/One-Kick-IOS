//
//  GameModels.swift
//  One Kick
//
//  ROBUST: Vorbereitet für JSON/API (Codable) und sichere Identifizierung.
//

import Foundation

// Modell für den Ticker
struct TickerGame: Identifiable, Codable {
    let id: UUID
    let homeClean: String
    let guestClean: String
    let scoreHome: Int
    let scoreGuest: Int
    let status: String
    let isLive: Bool
}

// Modell für offene Tipps
struct OpenGame: Identifiable, Codable {
    let id: UUID
    let community: String
    let league: String
    let home: String
    let guest: String
    let date: String
}
