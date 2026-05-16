//
//  APIConfig.swift
//  One Kick
//
//  Zentrale Stelle für API-Keys.
//  WICHTIG: Wenn du dieses Projekt in Git versionierst, füge diese
//  Datei in deine .gitignore ein, damit dein Key nicht öffentlich wird.
//

import Foundation

enum APIConfig {
    
    /// API-Sports Key — siehe dashboard.api-football.com → "My Access"
    static let apiFootballKey: String = "af3eb7f8e282c69dd673e668f8ab5f67"
    
    /// Host für API-Sports Football v3 (direkt, nicht über RapidAPI).
    static let apiFootballHost: String = "v3.football.api-sports.io"
    
    /// Aktuelle Saison: 2025 = Spielzeit 2025/2026.
    /// Ab August 2026 auf 2026 hochsetzen.
    static let currentSeason: Int = 2025
}
