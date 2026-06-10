//
//  GlobalBetManager.swift
//  One Kick
//
//  Eigenständiger Tipp-Speicher für die Globale Community (unabhängig von regulären Communities).
//  Pfad: globalCommunityBets/{leagueKey}/bets/{fixtureId}_{userId}
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct GlobalBetManager {
    private let db = Firestore.firestore()

    /// Liga-Name → Firestore-sicherer Schlüssel (identisch zur Score-Logik).
    static func leagueKey(_ league: String) -> String {
        league.replacingOccurrences(of: "/", with: "_")
              .replacingOccurrences(of: " ", with: "_")
              .lowercased()
    }

    /// Speichert/aktualisiert den globalen Tipp des aktuellen Users für ein Spiel.
    func saveGlobalBet(league: String, fixtureId: Int, homeGoals: Int, awayGoals: Int) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let key = Self.leagueKey(league)

        var data: [String: Any] = [
            "userId":    uid,
            "fixtureId": fixtureId,
            "homeGoals": homeGoals,
            "awayGoals": awayGoals,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        // Anzeigename/Bild für die globale Rangliste mitschreiben
        if let userDoc = try? await db.collection("users").document(uid).getDocument() {
            data["displayName"] = userDoc.data()?["displayName"] as? String
                ?? Auth.auth().currentUser?.email?.components(separatedBy: "@").first
                ?? String(uid.prefix(8))
            if let photo = userDoc.data()?["photoBase64"] as? String { data["photoBase64"] = photo }
        }

        try await db.collection("globalCommunityBets")
            .document(key)
            .collection("bets")
            .document("\(fixtureId)_\(uid)")
            .setData(data, merge: true)
    }

    /// Lädt die globalen Tipps des aktuellen Users für eine Liga.
    func loadGlobalBets(league: String) async -> [Int: (home: Int, away: Int)] {
        guard let uid = Auth.auth().currentUser?.uid else { return [:] }
        let key = Self.leagueKey(league)
        do {
            let snap = try await db.collection("globalCommunityBets")
                .document(key)
                .collection("bets")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            var result: [Int: (home: Int, away: Int)] = [:]
            for doc in snap.documents {
                let d = doc.data()
                if let fid = d["fixtureId"] as? Int,
                   let h = d["homeGoals"] as? Int,
                   let a = d["awayGoals"] as? Int {
                    result[fid] = (home: h, away: a)
                }
            }
            return result
        } catch {
            return [:]
        }
    }
}
