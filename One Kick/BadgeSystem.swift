//
//  BadgeSystem.swift
//  One Kick
//
//  Badge-Definitionen, Unlock-Logik und Firestore-Persistenz.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Badge Modell

/// Metrik, auf der Fortschritt & Freischaltung eines Badges beruhen.
enum BadgeMetric: String, Codable {
    case exactScore, bestStreak, totalTips, totalPoints
    case correctWinner, correctDraw, correctGoalDiff
    case communityRank1, communityTop3        // binär getrackt – kein Fortschrittsbalken
    case bonusTorschuetze, bonusFinalisten     // extern getrackt – kein Fortschrittsbalken

    /// true = numerische Metrik aus StatsData → Fortschrittsbalken möglich.
    var isProgressable: Bool {
        switch self {
        case .communityRank1, .communityTop3, .bonusTorschuetze, .bonusFinalisten:
            return false
        default:
            return true
        }
    }
}

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String          // SF-Symbol
    let category: String
    let tier: Int             // 1 = Bronze, 2 = Silber, 3 = Gold
    let metric: BadgeMetric
    let goal: Int             // Zielwert (für nicht-numerische Metriken irrelevant)
}

// MARK: - Vollständiger Badge-Katalog
// Eigene Gestaltung: nur Apple SF-Symbols + Tier-Farben, keine fremden Logos/Marken.

let allBadges: [Badge] = [
    // Genauigkeit – exakte Tipps
    Badge(id: "volltreffer_rookie",  name: "Volltreffer-Rookie", description: "1 exakter Tipp",   icon: "target",              category: "Genauigkeit", tier: 1, metric: .exactScore, goal: 1),
    Badge(id: "volltreffer_profi",   name: "Volltreffer-Profi",  description: "10 exakte Tipps",  icon: "scope",               category: "Genauigkeit", tier: 2, metric: .exactScore, goal: 10),
    Badge(id: "volltreffer_legende", name: "Tipp-Legende",       description: "50 exakte Tipps",  icon: "dot.scope",           category: "Genauigkeit", tier: 3, metric: .exactScore, goal: 50),

    // Tendenz (Sieger/Unentschieden richtig)
    Badge(id: "tendenz_kenner",  name: "Tendenz-Kenner",  description: "25 richtige Tendenzen",  icon: "arrow.triangle.branch", category: "Tendenz", tier: 1, metric: .correctWinner, goal: 25),
    Badge(id: "tendenz_profi",   name: "Tendenz-Profi",   description: "100 richtige Tendenzen", icon: "arrow.triangle.swap",   category: "Tendenz", tier: 2, metric: .correctWinner, goal: 100),
    Badge(id: "tendenz_meister", name: "Tendenz-Meister", description: "250 richtige Tendenzen", icon: "checkmark.seal.fill",   category: "Tendenz", tier: 3, metric: .correctWinner, goal: 250),

    // Unentschieden-Spürnase
    Badge(id: "remis_spuersinn", name: "Remis-Spürsinn", description: "5 Unentschieden richtig",  icon: "equal.circle.fill", category: "Spezial", tier: 1, metric: .correctDraw, goal: 5),
    Badge(id: "remis_experte",   name: "Remis-Experte",  description: "20 Unentschieden richtig", icon: "equal.square.fill", category: "Spezial", tier: 2, metric: .correctDraw, goal: 20),

    // Tordifferenz
    Badge(id: "diff_kenner", name: "Tordifferenz-Kenner", description: "25 Tordifferenzen richtig",  icon: "plusminus.circle.fill", category: "Spezial", tier: 1, metric: .correctGoalDiff, goal: 25),
    Badge(id: "diff_profi",  name: "Tordifferenz-Profi",  description: "100 Tordifferenzen richtig", icon: "plusminus",             category: "Spezial", tier: 2, metric: .correctGoalDiff, goal: 100),

    // Punktesammler
    Badge(id: "punkte_100",  name: "Punktesammler", description: "100 Punkte gesammelt",  icon: "star.fill",        category: "Punkte", tier: 1, metric: .totalPoints, goal: 100),
    Badge(id: "punkte_500",  name: "Punkte-Jäger",  description: "500 Punkte gesammelt",  icon: "star.circle.fill", category: "Punkte", tier: 2, metric: .totalPoints, goal: 500),
    Badge(id: "punkte_1000", name: "Punkte-Magnat", description: "1000 Punkte gesammelt", icon: "sparkles",         category: "Punkte", tier: 3, metric: .totalPoints, goal: 1000),

    // Serien
    Badge(id: "streak_5",  name: "Heißer Lauf",  description: "5 Spiele in Folge mit Punkten",  icon: "flame",      category: "Serien", tier: 1, metric: .bestStreak, goal: 5),
    Badge(id: "streak_10", name: "Feuersträhne", description: "10 Spiele in Folge mit Punkten", icon: "flame.fill", category: "Serien", tier: 2, metric: .bestStreak, goal: 10),
    Badge(id: "streak_20", name: "Unaufhaltbar", description: "20 Spiele in Folge mit Punkten", icon: "bolt.fill",  category: "Serien", tier: 3, metric: .bestStreak, goal: 20),

    // Aktivität
    Badge(id: "fleissig", name: "Fleißiger Tipper", description: "50 Tipps abgegeben",  icon: "square.and.pencil",    category: "Aktivität", tier: 1, metric: .totalTips, goal: 50),
    Badge(id: "veteran",  name: "Tipp-Veteran",     description: "200 Tipps abgegeben", icon: "calendar.badge.clock", category: "Aktivität", tier: 2, metric: .totalTips, goal: 200),
    Badge(id: "marathon", name: "Marathon-Tipper",  description: "500 Tipps abgegeben", icon: "figure.run",           category: "Aktivität", tier: 3, metric: .totalTips, goal: 500),

    // Bonus-Tipps (extern getrackt)
    Badge(id: "torjaeger_radar",   name: "Torjäger-Radar",   description: "1× Torschützenkönig richtig",   icon: "soccerball",         category: "Bonus", tier: 1, metric: .bonusTorschuetze, goal: 1),
    Badge(id: "torjaeger_experte", name: "Torjäger-Experte", description: "3× Torschützenkönig richtig",   icon: "soccerball.inverse", category: "Bonus", tier: 2, metric: .bonusTorschuetze, goal: 3),
    Badge(id: "finale_vision",     name: "Finale-Vision",    description: "1× Finalisten richtig getippt", icon: "trophy",             category: "Bonus", tier: 1, metric: .bonusFinalisten, goal: 1),
    Badge(id: "pokal_orakel",      name: "Pokal-Orakel",     description: "3× Finalisten richtig getippt", icon: "trophy.fill",        category: "Bonus", tier: 3, metric: .bonusFinalisten, goal: 3),

    // Community
    Badge(id: "community_gold", name: "Community-Champion", description: "1× Platz 1 in einer Community", icon: "crown.fill", category: "Community", tier: 3, metric: .communityRank1, goal: 1),
    Badge(id: "top_three",      name: "Podiums-Platz",      description: "3× Top-3 in einer Community",   icon: "medal.fill", category: "Community", tier: 2, metric: .communityTop3, goal: 3),
]

// MARK: - BadgeSystem

@MainActor
class BadgeSystem: ObservableObject {
    static let shared = BadgeSystem()

    @Published var earnedBadgeIds:   [String] = []
    @Published var selectedBadgeIds: [String] = []
    @Published var newlyUnlocked:    [Badge]  = []
    /// Letzter Statistik-Stand für Fortschrittsbalken (aus checkAndUnlock + Cache).
    @Published var progressStats:    StatsData? = nil

    private let db = Firestore.firestore()

    // Lookup
    func badge(for id: String) -> Badge? { allBadges.first { $0.id == id } }
    var earnedBadges:   [Badge] { earnedBadgeIds.compactMap { badge(for: $0) } }
    var selectedBadges: [Badge] { selectedBadgeIds.compactMap { badge(for: $0) } }

    // MARK: Fortschritt

    /// Aktueller Wert einer Metrik aus StatsData (nil = nicht numerisch trackbar).
    func current(_ metric: BadgeMetric, stats: StatsData) -> Int? {
        switch metric {
        case .exactScore:      return stats.exactScore
        case .bestStreak:      return stats.bestStreak
        case .totalTips:       return stats.totalTips
        case .totalPoints:     return stats.totalPoints
        case .correctWinner:   return stats.correctWinner
        case .correctDraw:     return stats.correctDraw
        case .correctGoalDiff: return stats.correctGoalDiff
        case .communityRank1, .communityTop3, .bonusTorschuetze, .bonusFinalisten:
            return nil
        }
    }

    /// Fortschritt 0…1 in Richtung Freischaltung (1 = erreicht/freigeschaltet).
    func progress(for badge: Badge) -> Double {
        if earnedBadgeIds.contains(badge.id) { return 1 }
        guard badge.metric.isProgressable, badge.goal > 0,
              let stats = progressStats,
              let value = current(badge.metric, stats: stats) else { return 0 }
        return min(1, Double(value) / Double(badge.goal))
    }

    /// Aktueller Zählerstand für die Fortschrittsanzeige (nil wenn nicht trackbar).
    func currentValue(for badge: Badge) -> Int? {
        guard badge.metric.isProgressable, let stats = progressStats else { return nil }
        return current(badge.metric, stats: stats)
    }

    // MARK: Laden

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = try? await db.collection("users").document(uid).getDocument()
        let data = doc?.data() ?? [:]
        earnedBadgeIds   = data["earnedBadges"]   as? [String] ?? []
        selectedBadgeIds = data["selectedBadges"] as? [String] ?? []
        loadCachedStats(uid: uid)
        // Bereits zu 100 % erreichte Badges nachträglich freischalten (idempotent),
        // damit der Picker sie unter „Freigeschaltet" zeigt – nicht nur als 100%-Balken.
        if let stats = progressStats {
            await checkAndUnlock(from: stats)
        }
    }

    /// Lädt den gecachten Statistik-Stand (StatistikViewModel `statsCache_v3_<uid>`)
    /// für die Fortschrittsbalken – auch ohne Besuch des Statistik-Tabs.
    private func loadCachedStats(uid: String) {
        guard let d = UserDefaults.standard.data(forKey: "statsCache_v3_\(uid)"),
              let stats = try? JSONDecoder().decode(StatsData.self, from: d) else { return }
        progressStats = stats
    }

    // MARK: Fremdes Profil

    func loadForUser(uid: String) async -> (earned: [String], selected: [String]) {
        let doc = try? await db.collection("users").document(uid).getDocument()
        let data = doc?.data() ?? [:]
        return (
            data["earnedBadges"]   as? [String] ?? [],
            data["selectedBadges"] as? [String] ?? []
        )
    }

    // MARK: Freischalten (aus Stats)

    func checkAndUnlock(from stats: StatsData) async {
        progressStats = stats   // für Fortschrittsbalken

        // Katalog-getrieben: alle Badges mit numerischer Metrik prüfen.
        let newIds = allBadges.compactMap { badge -> String? in
            guard badge.metric.isProgressable,
                  let value = current(badge.metric, stats: stats),
                  value >= badge.goal else { return nil }
            return badge.id
        }
        await unlock(ids: newIds)
    }

    func checkAndUnlockCommunity(rank: Int, totalUsers: Int) async {
        var newIds: [String] = []
        if rank == 1 { newIds.append("community_gold") }
        if rank <= 3 { newIds.append("top_three") }
        await unlock(ids: newIds)
    }

    func checkAndUnlockBonusTorschuetze(correctCount: Int) async {
        var newIds: [String] = []
        if correctCount >= 1 { newIds.append("torjaeger_radar") }
        if correctCount >= 3 { newIds.append("torjaeger_experte") }
        await unlock(ids: newIds)
    }

    func checkAndUnlockBonusFinalisten(correctCount: Int) async {
        var newIds: [String] = []
        if correctCount >= 1 { newIds.append("finale_vision") }
        if correctCount >= 3 { newIds.append("pokal_orakel") }
        await unlock(ids: newIds)
    }

    // MARK: Persistenz

    private func unlock(ids: [String]) async {
        guard let uid = Auth.auth().currentUser?.uid, !ids.isEmpty else { return }
        let genuinelyNew = ids.filter { !earnedBadgeIds.contains($0) }
        guard !genuinelyNew.isEmpty else { return }

        earnedBadgeIds.append(contentsOf: genuinelyNew)
        newlyUnlocked = genuinelyNew.compactMap { badge(for: $0) }

        try? await db.collection("users").document(uid)
            .setData(["earnedBadges": earnedBadgeIds], merge: true)
    }

    func saveSelectedBadges(_ ids: [String]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let limited = Array(ids.prefix(3))
        selectedBadgeIds = limited
        try? await db.collection("users").document(uid)
            .setData(["selectedBadges": limited], merge: true)
    }
}
