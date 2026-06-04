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
