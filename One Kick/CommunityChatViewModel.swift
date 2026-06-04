import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ChatMessage: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let text: String
    let timestamp: Timestamp?
    let reported: Bool
    let type: String       // "text" | "poll"
    let pollId: String?

    var timeString: String {
        guard let date = timestamp?.dateValue() else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

@MainActor
class CommunityChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String?
    @Published var blockedUserIds: Set<String> = []

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func loadBlockedUsers() async {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let snap = try? await db.collection("users").document(myUid)
            .collection("blockedUsers").getDocuments()
        blockedUserIds = Set(snap?.documents.map { $0.documentID } ?? [])
    }

    func blockUser(uid: String) async {
        guard let myUid = Auth.auth().currentUser?.uid, uid != myUid else { return }
        try? await db.collection("users").document(myUid)
            .collection("blockedUsers").document(uid)
            .setData(["blockedAt": FieldValue.serverTimestamp()])
        blockedUserIds.insert(uid)
    }

    func startListening(communityId: String) {
        listener?.remove()
        listener = db.collection("communities")
            .document(communityId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, error == nil, let snapshot else { return }
                let all = snapshot.documents.compactMap { doc -> ChatMessage? in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        userId: data["userId"] as? String ?? "",
                        displayName: data["displayName"] as? String ?? "Unbekannt",
                        text: data["text"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp,
                        reported: data["reported"] as? Bool ?? false,
                        type: data["type"] as? String ?? "text",
                        pollId: data["pollId"] as? String
                    )
                }
                self.messages = all.filter { !self.blockedUserIds.contains($0.userId) }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func sendMessage(communityId: String, text: String) {
        guard let user = Auth.auth().currentUser else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { return }

        let displayName = user.displayName
            ?? user.email?.components(separatedBy: "@").first
            ?? "Anonym"

        let data: [String: Any] = [
            "userId": user.uid,
            "displayName": displayName,
            "text": trimmed,
            "timestamp": Timestamp(),
            "reported": false
        ]

        db.collection("communities")
            .document(communityId)
            .collection("messages")
            .addDocument(data: data) { [weak self] error in
                if error != nil {
                    self?.errorMessage = "Nachricht konnte nicht gesendet werden"
                }
            }
    }

    func sendPollMessage(communityId: String, pollId: String) {
        guard let user = Auth.auth().currentUser else { return }
        let displayName = user.displayName ?? user.email?.components(separatedBy: "@").first ?? "Anonym"
        let data: [String: Any] = [
            "userId": user.uid,
            "displayName": displayName,
            "text": "",
            "type": "poll",
            "pollId": pollId,
            "timestamp": Timestamp(),
            "reported": false
        ]
        db.collection("communities").document(communityId).collection("messages").addDocument(data: data)
    }

    func reportMessage(communityId: String, messageId: String) {
        db.collection("communities")
            .document(communityId)
            .collection("messages")
            .document(messageId)
            .updateData(["reported": true])
    }

    deinit {
        listener?.remove()
    }
}
