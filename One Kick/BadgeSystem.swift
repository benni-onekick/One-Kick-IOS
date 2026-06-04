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

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let category: String
}

// MARK: - Vollständiger Badge-Katalog

let allBadges: [Badge] = [
    // Tipp-Genauigkeit
    Badge(id: "volltreffer_rookie",  name: "Volltreffer-Rookie",  description: "1 exakter Tipp",   emoji: "🎯", category: "Genauigkeit"),
    Badge(id: "volltreffer_profi",   name: "Volltreffer-Profi",   description: "10 exakte Tipps",  emoji: "🎯", category: "Genauigkeit"),
    Badge(id: "volltreffer_legende", name: "Tipp-Legende",        description: "50 exakte Tipps",  emoji: "🎯", category: "Genauigkeit"),

    // Serien
    Badge(id: "streak_5",  name: "Heißer Lauf",   description: "5 Spiele in Folge mit Punkten",  emoji: "🔥", category: "Serien"),
    Badge(id: "streak_10", name: "Feuersträhne",   description: "10 Spiele in Folge mit Punkten", emoji: "🔥", category: "Serien"),
    Badge(id: "streak_20", name: "Unaufhaltbar",   description: "20 Spiele in Folge mit Punkten", emoji: "🔥", category: "Serien"),

    // Bonus-Tipps
    Badge(id: "torjaeger_radar",   name: "Torjäger-Radar",   description: "1× Torschützenkönig richtig",  emoji: "⚽", category: "Bonus"),
    Badge(id: "torjaeger_experte", name: "Torjäger-Experte", description: "3× Torschützenkönig richtig",  emoji: "⚽", category: "Bonus"),
    Badge(id: "finale_vision",     name: "Finale-Vision",    description: "1× Finalisten richtig getippt", emoji: "🏆", category: "Bonus"),
    Badge(id: "pokal_orakel",      name: "Pokal-Orakel",     description: "3× Finalisten richtig getippt", emoji: "🏆", category: "Bonus"),

    // Aktivität
    Badge(id: "fleissig", name: "Fleißiger Tipper", description: "50 Tipps abgegeben",  emoji: "📊", category: "Aktivität"),
    Badge(id: "veteran",  name: "Tipp-Veteran",     description: "200 Tipps abgegeben", emoji: "📊", category: "Aktivität"),
    Badge(id: "marathon", name: "Marathon-Tipper",  description: "500 Tipps abgegeben", emoji: "📊", category: "Aktivität"),

    // Community
    Badge(id: "community_gold", name: "Community-Champion", description: "1× Platz 1 in einer Community", emoji: "🥇", category: "Community"),
    Badge(id: "top_three",      name: "Podiums-Platz",      description: "3× Top-3 in einer Community",   emoji: "🥈", category: "Community"),
]

// MARK: - BadgeSystem

@MainActor
class BadgeSystem: ObservableObject {
    static let shared = BadgeSystem()

    @Published var earnedBadgeIds:   [String] = []
    @Published var selectedBadgeIds: [String] = []
    @Published var newlyUnlocked:    [Badge]  = []

    private let db = Firestore.firestore()

    // Lookup
    func badge(for id: String) -> Badge? { allBadges.first { $0.id == id } }
    var earnedBadges:   [Badge] { earnedBadgeIds.compactMap { badge(for: $0) } }
    var selectedBadges: [Badge] { selectedBadgeIds.compactMap { badge(for: $0) } }

    // MARK: Laden

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = try? await db.collection("users").document(uid).getDocument()
        let data = doc?.data() ?? [:]
        earnedBadgeIds   = data["earnedBadges"]   as? [String] ?? []
        selectedBadgeIds = data["selectedBadges"] as? [String] ?? []
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
        var newIds: [String] = []

        if stats.exactScore >= 1  { newIds.append("volltreffer_rookie") }
        if stats.exactScore >= 10 { newIds.append("volltreffer_profi") }
        if stats.exactScore >= 50 { newIds.append("volltreffer_legende") }

        if stats.bestStreak >= 5  { newIds.append("streak_5") }
        if stats.bestStreak >= 10 { newIds.append("streak_10") }
        if stats.bestStreak >= 20 { newIds.append("streak_20") }

        if stats.totalTips >= 50  { newIds.append("fleissig") }
        if stats.totalTips >= 200 { newIds.append("veteran") }
        if stats.totalTips >= 500 { newIds.append("marathon") }

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
