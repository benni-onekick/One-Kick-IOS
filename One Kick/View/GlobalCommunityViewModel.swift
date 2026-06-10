//
//  GlobalCommunityViewModel.swift
//  One Kick
//
//  Globale Community: Liga-übergreifendes Ranking aller App-Nutzer.
//  Ersetzt GlobalWmViewModel (entfernt: "WM 2026" IP-Branding).
//  Firestore: globalCommunityPoints/{leagueName}/{userId}
//             users/{userId}.globalCommunityLeagues: [String]
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Model

struct GlobalCommunityEntry: Identifiable {
    let id: String
    let displayName: String
    let points: Int
    let photoBase64: String?
}

// MARK: - ViewModel

@MainActor
class GlobalCommunityViewModel: ObservableObject {
    @Published var selectedLeagues: [String] = []
    @Published var pointsByLeague: [String: Int] = [:]
    @Published var rankByLeague: [String: Int] = [:]
    @Published var isLoading = true
    @Published var selectedLeagueForLeaderboard: String? = nil

    private let db = Firestore.firestore()

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { isLoading = false; return }
        isLoading = true

        // Gewählte Ligen aus users/{uid} laden
        if let userDoc = try? await db.collection("users").document(uid).getDocument(),
           let leagues = userDoc.data()?["globalCommunityLeagues"] as? [String] {
            selectedLeagues = leagues
        } else {
            selectedLeagues = []
        }

        // Punkte und Ränge für jede Liga laden
        var pts: [String: Int] = [:]
        var rnk: [String: Int] = [:]
        for league in selectedLeagues {
            let doc = try? await db.collection("globalCommunityPoints")
                .document(league.toFirestoreKey())
                .collection("scores")
                .document(uid)
                .getDocument()
            let p = doc?.data()?["points"] as? Int ?? 0
            pts[league] = p

            if let countSnap = try? await db.collection("globalCommunityPoints")
                .document(league.toFirestoreKey())
                .collection("scores")
                .whereField("points", isGreaterThan: p)
                .count.getAggregation(source: .server) {
                rnk[league] = Int(truncating: countSnap.count) + 1
            }
        }
        pointsByLeague = pts
        rankByLeague = rnk
        isLoading = false
    }

    func loadLeaderboard(for leagueName: String) async -> [GlobalCommunityEntry] {
        guard let snap = try? await db.collection("globalCommunityPoints")
            .document(leagueName.toFirestoreKey())
            .collection("scores")
            .order(by: "points", descending: true)
            .limit(to: 100)
            .getDocuments() else { return [] }

        return snap.documents.compactMap { doc in
            guard let name = doc.data()["displayName"] as? String,
                  let pts  = doc.data()["points"] as? Int else { return nil }
            return GlobalCommunityEntry(
                id: doc.documentID,
                displayName: name,
                points: pts,
                photoBase64: doc.data()["photoBase64"] as? String
            )
        }
    }

    private let api = APIFootballService()
    private let globalBets = GlobalBetManager()

    /// Lädt die eigenen globalen Tipps einer Liga (für die Spieltage-Ansicht).
    func loadGlobalBets(for league: String) async -> [Int: (home: Int, away: Int)] {
        await globalBets.loadGlobalBets(league: league)
    }

    /// Berechnet den eigenen Score einer globalen Liga aus den globalen Tipps + Ergebnissen
    /// und schreibt ihn nach globalCommunityPoints/{leagueKey}/scores/{uid}.
    func recomputeScore(for league: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let bets = await globalBets.loadGlobalBets(league: league)
        guard !bets.isEmpty else { return }

        let lid = LeagueMapper.getID(for: league)
        let fixtures = await api.fetchAllSeasonFixtures(for: lid)
        let finished: Set<String> = ["FT", "AET", "PEN", "AWD", "WO"]
        var results: [Int: (home: Int, away: Int)] = [:]
        for m in fixtures where finished.contains(m.fixture.status.short) {
            results[m.fixture.id] = (m.goals.home ?? 0, m.goals.away ?? 0)
        }

        var total = 0
        for (fid, tip) in bets {
            guard let res = results[fid] else { continue }
            total += Self.calcPoints(tip: tip, result: res)
        }

        // Anzeigename/Bild für die Rangliste
        let userDoc = try? await db.collection("users").document(uid).getDocument()
        var data: [String: Any] = [
            "points":    total,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["displayName"] = userDoc?.data()?["displayName"] as? String
            ?? Auth.auth().currentUser?.email?.components(separatedBy: "@").first
            ?? String(uid.prefix(8))
        if let photo = userDoc?.data()?["photoBase64"] as? String { data["photoBase64"] = photo }

        try? await db.collection("globalCommunityPoints")
            .document(league.toFirestoreKey())
            .collection("scores")
            .document(uid)
            .setData(data, merge: true)
    }

    /// Standard-Punkte: 1 Heim + 1 Auswärts + 2 Tordifferenz + 3 Tendenz.
    static func calcPoints(tip: (home: Int, away: Int), result: (home: Int, away: Int)) -> Int {
        var p = 0
        if tip.home == result.home { p += 1 }
        if tip.away == result.away { p += 1 }
        let td = tip.home - tip.away, rd = result.home - result.away
        if td == rd { p += 2 }
        let tr = td > 0 ? 1 : (td < 0 ? -1 : 0)
        let rr = rd > 0 ? 1 : (rd < 0 ? -1 : 0)
        if tr == rr { p += 3 }
        return p
    }

    func saveLeagues(_ leagues: [String]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let current = Set(selectedLeagues)
        let new = Set(leagues)
        let removed = current.subtracting(new)

        // Entfernte Ligen: Score löschen
        for league in removed {
            try? await db.collection("globalCommunityPoints")
                .document(league.toFirestoreKey())
                .collection("scores")
                .document(uid)
                .delete()
        }

        try? await db.collection("users").document(uid).setData(
            ["globalCommunityLeagues": leagues], merge: true
        )
        selectedLeagues = leagues
        await load()
    }
}

// Liga-Namen → Firestore-sichere Dokument-IDs
private extension String {
    func toFirestoreKey() -> String {
        self.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}
