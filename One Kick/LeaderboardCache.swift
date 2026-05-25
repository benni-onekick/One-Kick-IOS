//
//  LeaderboardCache.swift
//  One Kick
//
//  Singleton-Cache: CommunityPunkteViewModel schreibt nach der Leaderboard-Berechnung rein.
//  TippenViewModel liest daraus → keine doppelten API-Calls für Rang-Berechnung.
//
//  Zwei Schichten:
//  • In-Memory (15 min TTL) – sofort verfügbar
//  • UserDefaults (24h TTL) – überlebt App-Neustart
//

import Foundation

final class LeaderboardCache {
    static let shared = LeaderboardCache()
    private init() {}

    // MARK: - In-Memory

    private struct Entry {
        let rankings: [UserPointsEntry]
        let date: Date
    }

    private var cache: [String: Entry] = [:]
    private let memoryTTL: TimeInterval = 15 * 60   // 15 Minuten
    private let diskTTL: TimeInterval    = 24 * 60 * 60 // 24 Stunden

    // MARK: - Codable Slim-Struct für UserDefaults

    private struct CachedEntry: Codable {
        let id: String
        let displayName: String
        let points: Int
        let bonusPoints: Int
        let photoBase64: String?
    }

    private struct CachedPayload: Codable {
        let entries: [CachedEntry]
        let date: Date
    }

    // MARK: - Store

    func store(_ rankings: [UserPointsEntry], for communityId: String) {
        cache[communityId] = Entry(rankings: rankings, date: Date())
        persistToDefaults(rankings, for: communityId)
    }

    private func persistToDefaults(_ rankings: [UserPointsEntry], for communityId: String) {
        let slim = rankings.map {
            CachedEntry(id: $0.id, displayName: $0.displayName, points: $0.points,
                        bonusPoints: $0.bonusPoints, photoBase64: $0.photoBase64)
        }
        let payload = CachedPayload(entries: slim, date: Date())
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: defaultsKey(communityId))
        }
    }

    // MARK: - Get

    /// staleOkay = true → ignoriert TTL; zeigt veraltete Daten statt nil (Fallback bei Rate-Limiting)
    func get(for communityId: String, staleOkay: Bool = false) -> [UserPointsEntry]? {
        if let entry = cache[communityId] {
            if staleOkay || Date().timeIntervalSince(entry.date) < memoryTTL {
                return entry.rankings
            }
        }

        if let loaded = loadFromDefaults(for: communityId, staleOkay: staleOkay) {
            cache[communityId] = Entry(rankings: loaded, date: Date())
            return loaded
        }

        return nil
    }

    private func loadFromDefaults(for communityId: String, staleOkay: Bool = false) -> [UserPointsEntry]? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(communityId)),
              let payload = try? JSONDecoder().decode(CachedPayload.self, from: data) else { return nil }
        guard staleOkay || Date().timeIntervalSince(payload.date) < diskTTL else { return nil }

        return payload.entries.map {
            UserPointsEntry(
                id: $0.id,
                displayName: $0.displayName,
                points: $0.points,
                bonusPoints: $0.bonusPoints,
                leagueBreakdown: [],
                photoBase64: $0.photoBase64
            )
        }
    }

    private func defaultsKey(_ communityId: String) -> String {
        "leaderboardCache_\(communityId)"
    }
}
