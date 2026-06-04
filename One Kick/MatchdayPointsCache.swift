//
//  MatchdayPointsCache.swift
//  One Kick
//
//  Speichert vorberechnete Punkte pro Liga und Spieltag in UserDefaults.
//  Ermöglicht inkrementelle Berechnung: stabile Runden (alle FT) werden gecacht,
//  nur der aktuelle Spieltag wird frisch berechnet.
//

import Foundation

struct MatchdayPointsCache {
    static let shared = MatchdayPointsCache()
    private init() {}

    // Cache-Einträge laufen nach 36h ab → stellt sicher dass nachträglich korrigierte
    // Ergebnisse (z.B. Live-Scores die gecacht wurden) beim nächsten Öffnen neu berechnet werden
    private let ttl: TimeInterval = 36 * 3600

    private struct CacheEntry: Codable {
        let points: [String: Int]
        let savedAt: Date
    }

    /// Gibt gecachte Punkte zurück: [userId: points] für Runden 1..upToMatchday dieser Liga.
    func get(communityId: String, leagueId: Int, upToMatchday: Int) -> [String: Int]? {
        let key = cacheKey(communityId: communityId, leagueId: leagueId, upTo: upToMatchday)
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < ttl else { return nil }
        return entry.points
    }

    func store(_ points: [String: Int], communityId: String, leagueId: Int, upToMatchday: Int) {
        let key = cacheKey(communityId: communityId, leagueId: leagueId, upTo: upToMatchday)
        let entry = CacheEntry(points: points, savedAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func clearAll() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("mpc_") }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    func clearForLeague(leagueId: Int) {
        let defaults = UserDefaults.standard
        let marker = "_\(leagueId)_upTo_"
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("mpc_") && $0.contains(marker) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    private func cacheKey(communityId: String, leagueId: Int, upTo: Int) -> String {
        "mpc_\(communityId)_\(leagueId)_upTo_\(upTo)"
    }
}
