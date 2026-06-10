//
//  GlobalPollViewModel.swift
//  One Kick
//
//  App-weite Umfragen ("Abstimmung" im News-Tab). Komplett getrennt von den
//  Community-Chat-Umfragen. Erstellen nur durch den Entwickler-Account.
//  Speicherort: Top-Level-Collection `globalPolls`.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GlobalPollViewModel: ObservableObject {

    /// E-Mail des Entwickler-Accounts, der Umfragen erstellen/schließen darf.
    static let developerEmail = "benni.diedrich@gmail.com"

    static var isDeveloper: Bool {
        Auth.auth().currentUser?.email?.lowercased() == developerEmail
    }

    @Published var polls: [String: CommunityPoll] = [:]  // pollId → poll

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    /// Nur live Umfragen (nicht geschlossen, Ablauf nicht erreicht), neueste zuerst.
    var activePolls: [CommunityPoll] {
        polls.values
            .filter { $0.isLive }
            .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
    }

    func startListening() {
        listener?.remove()
        listener = db.collection("globalPolls")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                var map: [String: CommunityPoll] = [:]
                for doc in snapshot.documents {
                    if let poll = CommunityPoll.from(doc: doc) {
                        map[poll.id] = poll
                    }
                }
                self.polls = map
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Entwickler-Aktionen

    func createPoll(question: String, options: [String], multiSelect: Bool,
                    endsAt: Date?, completion: ((String) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var data: [String: Any] = [
            "type": CommunityPoll.PollType.free.rawValue,
            "question": question,
            "options": options,
            "matchIds": [Int](),
            "multiSelect": multiSelect,
            "createdBy": uid,
            "createdAt": Timestamp(),
            "status": "active",
            "votes": [String: [Int]]()
        ]
        if let endsAt { data["endsAt"] = Timestamp(date: endsAt) }
        var ref: DocumentReference?
        ref = db.collection("globalPolls").addDocument(data: data) { _ in
            if let id = ref?.documentID { completion?(id) }
        }
    }

    func closePoll(pollId: String) {
        db.collection("globalPolls").document(pollId)
            .updateData(["status": "closed"])
    }

    func deletePoll(pollId: String) {
        db.collection("globalPolls").document(pollId).delete()
    }

    // MARK: - Voten (alle Nutzer)

    func vote(pollId: String, selectedIndices: [Int]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("globalPolls").document(pollId)
            .updateData(["votes.\(uid)": selectedIndices])
    }

    deinit { listener?.remove() }
}
