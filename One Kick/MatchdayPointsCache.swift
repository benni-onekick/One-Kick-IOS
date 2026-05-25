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

    /// Gibt gecachte Punkte zurück: [userId: points] für Runden 1..upToMatchday dieser Liga.
    func get(communityId: String, leagueId: Int, upToMatchday: Int) -> [String: Int]? {
        let key = cacheKey(communityId: communityId, leagueId: leagueId, upTo: upToMatchday)
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return nil }
        return dict
    }

    func store(_ points: [String: Int], communityId: String, leagueId: Int, upToMatchday: Int) {
        let key = cacheKey(communityId: communityId, leagueId: leagueId, upTo: upToMatchday)
        guard let data = try? JSONEncoder().encode(points) else { return }
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
