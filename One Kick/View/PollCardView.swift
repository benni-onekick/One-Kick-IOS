import SwiftUI
import FirebaseAuth

struct PollCardView: View {

    let poll: CommunityPoll
    let communityId: String
    let community: CommunityModel
    let pollViewModel: CommunityPollViewModel

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var isAdmin: Bool { community.adminId == myUid }
    @State private var selectedIndices: Set<Int> = []

    init(poll: CommunityPoll, communityId: String, community: CommunityModel, pollViewModel: CommunityPollViewModel) {
        self.poll = poll
        self.communityId = communityId
        self.community = community
        self.pollViewModel = pollViewModel
        _selectedIndices = State(initialValue: Set(poll.myVotes(uid: Auth.auth().currentUser?.uid ?? "")))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 6) {
                Text("📊").font(.system(size: 15))
                Text("Abstimmung" + (poll.isClosed ? " · Geschlossen" : ""))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(poll.isClosed ? .gray : .oneKickNeon)
            }

            Text(poll.question)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            // Optionen
            ForEach(Array(poll.options.enumerated()), id: \.offset) { idx, option in
                let pct = poll.percentForOption(idx)
                let isSelected = selectedIndices.contains(idx)

                HStack {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.oneKickNeon.opacity(0.2) : Color.white.opacity(0.06))
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                        .frame(height: 28)
                        .animation(.easeInOut(duration: 0.3), value: pct)

                        Text(option)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? .oneKickNeon : .white)
                            .padding(.leading, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.oneKickNeon : Color.clear, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.04))
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !poll.isClosed else { return }
                        if poll.multiSelect {
                            if selectedIndices.contains(idx) { selectedIndices.remove(idx) }
                            else { selectedIndices.insert(idx) }
                        } else {
                            selectedIndices = [idx]
                        }
                    }

                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .oneKickNeon : .gray)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            // Footer
            HStack {
                Text("\(poll.totalVotes) Stimme\(poll.totalVotes == 1 ? "" : "n")")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                // Abstimmen
                let myVotesCurrent = poll.myVotes(uid: myUid)
                if !poll.isClosed && !selectedIndices.isEmpty && Array(selectedIndices).sorted() != myVotesCurrent.sorted() {
                    Button("Abstimmen") {
                        pollViewModel.vote(communityId: communityId, pollId: poll.id, selectedIndices: Array(selectedIndices))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.oneKickNeon)
                }

                // Admin-Buttons
                if isAdmin {
                    if !poll.isClosed {
                        Button("Schließen") {
                            pollViewModel.closePoll(communityId: communityId, pollId: poll.id)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    } else if poll.appliedAt == nil && poll.type != .free {
                        Button("Anwenden ✓") {
                            pollViewModel.applyResult(communityId: communityId, poll: poll, community: community)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.oneKickNeon)
                    } else if poll.appliedAt != nil {
                        Text("✓ Angewendet")
                            .font(.system(size: 11))
                            .foregroundColor(.oneKickNeon.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(12)
    }
}
