//
//  BetManager.swift
//  One Kick
//
//  Milestone B: Tipps in Firestore speichern und laden.
//  Pfad: communities/{communityId}/bets/{fixtureId}_{userId}
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class BetManager {
    private let db = Firestore.firestore()

    func saveBet(fixtureId: Int, communityId: String, homeGoals: Int, awayGoals: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let email = Auth.auth().currentUser?.email ?? ""
        let data: [String: Any] = [
            "userId":      userId,
            "email":       email,
            "fixtureId":   fixtureId,
            "communityId": communityId,
            "homeGoals":   homeGoals,
            "awayGoals":   awayGoals,
            "createdAt":   Timestamp()
        ]

        try await db.collection("communities")
            .document(communityId)
            .collection("bets")
            .document("\(fixtureId)_\(userId)")
            .setData(data, merge: true)

        print("✅ Tipp gespeichert: Fixture \(fixtureId) in Community \(communityId)")
    }

    func loadBets(communityId: String) async -> Set<Int> {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }

        do {
            let snapshot = try await db.collection("communities")
                .document(communityId)
                .collection("bets")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            let ids = snapshot.documents.compactMap { $0.data()["fixtureId"] as? Int }
            return Set(ids)
        } catch {
            print("🚨 Fehler beim Laden der Bets: \(error)")
            return []
        }
    }

    func loadBetScores(communityId: String) async -> [Int: (home: Int, away: Int)] {
        guard let userId = Auth.auth().currentUser?.uid else { return [:] }

        do {
            let snapshot = try await db.collection("communities")
                .document(communityId)
                .collection("bets")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            var result: [Int: (home: Int, away: Int)] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                if let fixtureId = data["fixtureId"] as? Int,
                   let home = data["homeGoals"] as? Int,
                   let away = data["awayGoals"] as? Int {
                    result[fixtureId] = (home: home, away: away)
                }
            }
            return result
        } catch {
            print("🚨 Fehler beim Laden der Bet-Scores: \(error)")
            return [:]
        }
    }
}
