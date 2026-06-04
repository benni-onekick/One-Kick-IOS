import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class CommunityPollViewModel: ObservableObject {

    @Published var polls: [String: CommunityPoll] = [:]  // pollId → poll

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening(communityId: String) {
        listener?.remove()
        listener = db.collection("communities")
            .document(communityId)
            .collection("polls")
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

    func createPoll(
        communityId: String,
        type: CommunityPoll.PollType,
        question: String,
        options: [String],
        matchIds: [Int] = [],
        multiSelect: Bool = false,
        completion: ((String) -> Void)? = nil
    ) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "type": type.rawValue,
            "question": question,
            "options": options,
            "matchIds": matchIds,
            "multiSelect": multiSelect,
            "createdBy": uid,
            "createdAt": Timestamp(),
            "status": "active",
            "votes": [String: [Int]]()
        ]
        var ref: DocumentReference?
        ref = db.collection("communities").document(communityId)
            .collection("polls")
            .addDocument(data: data) { _ in
                if let id = ref?.documentID { completion?(id) }
            }
    }

    func vote(communityId: String, pollId: String, selectedIndices: [Int]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("communities").document(communityId)
            .collection("polls").document(pollId)
            .updateData(["votes.\(uid)": selectedIndices])
    }

    func closePoll(communityId: String, pollId: String) {
        db.collection("communities").document(communityId)
            .collection("polls").document(pollId)
            .updateData(["status": "closed"])
    }

    func applyResult(communityId: String, poll: CommunityPoll, community: CommunityModel) {
        let winning = poll.winningIndices()
        let winningOptions = winning.compactMap { poll.options[safe: $0] }
        var updates: [String: Any] = [:]

        switch poll.type {
        case .leagues:
            updates["activeLeagues"] = winningOptions
        case .bonus:
            updates["activeBonusCategories"] = winningOptions
        case .matches:
            let leagueName = poll.question
                .replacingOccurrences(of: "Welche Spiele sollen getippt werden? (", with: "")
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)
            let selectedIds = winning.compactMap { poll.matchIds[safe: $0] }
            var current = community.selectedMatchIds ?? [:]
            if selectedIds.isEmpty {
                current.removeValue(forKey: leagueName)
            } else {
                current[leagueName] = selectedIds
            }
            updates["selectedMatchIds"] = current
        case .free:
            break
        }

        if !updates.isEmpty {
            db.collection("communities").document(communityId).updateData(updates)
            db.collection("communities").document(communityId)
                .collection("polls").document(poll.id)
                .updateData(["appliedAt": Timestamp()])
        }
    }

    deinit { listener?.remove() }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
