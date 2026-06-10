import Foundation
import FirebaseFirestore

struct CommunityPoll: Identifiable {
    let id: String
    var type: PollType
    var question: String
    var options: [String]
    var matchIds: [Int]          // index-parallel zu options, nur bei type=matches
    var multiSelect: Bool
    var createdBy: String
    var createdAt: Timestamp?
    var status: String           // "active" | "closed"
    var votes: [String: [Int]]  // userId → [optionIndices]
    var appliedAt: Timestamp?
    var endsAt: Timestamp? = nil // nur globale Umfragen: aktiv bis zu diesem Zeitpunkt

    enum PollType: String {
        case free, leagues, bonus, matches
        var label: String {
            switch self {
            case .free:    return "Freie Abstimmung"
            case .leagues: return "Welche Ligen?"
            case .bonus:   return "Welche Bonus-Kategorien?"
            case .matches: return "Welche Spiele tippen?"
            }
        }
    }

    var totalVotes: Int { votes.count }
    var isClosed: Bool { status == "closed" }

    /// Globale Umfrage: läuft noch (nicht geschlossen und Ablaufzeitpunkt nicht erreicht).
    var isLive: Bool {
        guard !isClosed else { return false }
        if let end = endsAt?.dateValue() { return end > Date() }
        return true
    }

    func votesForOption(_ index: Int) -> Int {
        votes.values.filter { $0.contains(index) }.count
    }

    func percentForOption(_ index: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(votesForOption(index)) / Double(totalVotes)
    }

    func myVotes(uid: String) -> [Int] { votes[uid] ?? [] }
    func hasVoted(uid: String) -> Bool { votes[uid] != nil }

    func winningIndices() -> [Int] {
        guard !options.isEmpty else { return [] }
        let max = (0 ..< options.count).map { votesForOption($0) }.max() ?? 0
        return (0 ..< options.count).filter { votesForOption($0) == max }
    }

    static func from(doc: QueryDocumentSnapshot) -> CommunityPoll? {
        let data = doc.data()
        guard let question = data["question"] as? String else { return nil }
        let rawVotes = data["votes"] as? [String: [Int]] ?? [:]
        let rawMatchIds = (data["matchIds"] as? [Int]) ?? []
        return CommunityPoll(
            id: doc.documentID,
            type: PollType(rawValue: data["type"] as? String ?? "free") ?? .free,
            question: question,
            options: data["options"] as? [String] ?? [],
            matchIds: rawMatchIds,
            multiSelect: data["multiSelect"] as? Bool ?? false,
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp,
            status: data["status"] as? String ?? "active",
            votes: rawVotes,
            appliedAt: data["appliedAt"] as? Timestamp,
            endsAt: data["endsAt"] as? Timestamp
        )
    }
}
