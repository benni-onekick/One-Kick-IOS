//
//  GlobalWmViewModel.swift
//  One Kick
//
//  Globaler WM-Score: liest und lädt das Ranking aller Nutzer
//  basierend auf ihren Weltmeisterschaft-Tipps.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Model

struct GlobalWmEntry: Identifiable {
    let id: String
    let displayName: String
    let points: Int
    let photoBase64: String?
}

// MARK: - ViewModel

@MainActor
class GlobalWmViewModel: ObservableObject {
    @Published var userPoints: Int  = 0
    @Published var userRank:   Int? = nil
    @Published var isLoading        = true

    private let db = Firestore.firestore()

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        let doc = try? await db.collection("globalWmScores").document(uid).getDocument()
        let pts = doc?.data()?["points"] as? Int ?? 0
        userPoints = pts

        if let countSnap = try? await db.collection("globalWmScores")
            .whereField("points", isGreaterThan: pts)
            .count.getAggregation(source: .server) {
            userRank = Int(truncating: countSnap.count) + 1
        } else {
            userRank = nil
        }
        isLoading = false
    }

    func loadLeaderboard() async -> [GlobalWmEntry] {
        guard let snap = try? await db.collection("globalWmScores")
            .order(by: "points", descending: true)
            .limit(to: 100)
            .getDocuments() else { return [] }

        return snap.documents.enumerated().compactMap { _, doc in
            guard let name = doc.data()["displayName"] as? String,
                  let pts  = doc.data()["points"] as? Int else { return nil }
            return GlobalWmEntry(
                id:           doc.documentID,
                displayName:  name,
                points:       pts,
                photoBase64:  doc.data()["photoBase64"] as? String
            )
        }
    }
}
