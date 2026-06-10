//
//  GlobalPollCardView.swift
//  One Kick
//
//  Karte für app-weite Umfragen ("Abstimmung" in News). Ergebnis erscheint erst,
//  nachdem der Nutzer selbst abgestimmt hat.
//

import SwiftUI
import FirebaseAuth

struct GlobalPollCardView: View {

    let poll: CommunityPoll
    @ObservedObject var viewModel: GlobalPollViewModel

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var hasVoted: Bool { poll.hasVoted(uid: myUid) }
    private var isDeveloper: Bool { GlobalPollViewModel.isDeveloper }

    @State private var selectedIndices: Set<Int> = []

    init(poll: CommunityPoll, viewModel: GlobalPollViewModel) {
        self.poll = poll
        self.viewModel = viewModel
        _selectedIndices = State(initialValue: Set(poll.myVotes(uid: Auth.auth().currentUser?.uid ?? "")))
    }

    private var endsText: String? {
        guard let end = poll.endsAt?.dateValue() else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: LanguageManager.shared.currentLanguage)
        f.dateFormat = "d.M. HH:mm"
        return f.string(from: end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 6) {
                Text("📊").font(.system(size: 15))
                Text(LanguageManager.shared.t("news.polls"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.oneKickNeon)
                Spacer()
                if let endsText {
                    Text("⏱ \(endsText)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Text(poll.question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Optionen
            ForEach(Array(poll.options.enumerated()), id: \.offset) { idx, option in
                let isSelected = selectedIndices.contains(idx)
                let pct = poll.percentForOption(idx)

                ZStack(alignment: .leading) {
                    // Ergebnis-Balken nur nach eigener Stimme
                    if hasVoted {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.oneKickNeon.opacity(0.22) : Color.white.opacity(0.06))
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                        .frame(height: 32)
                        .animation(.easeInOut(duration: 0.3), value: pct)
                    }

                    HStack {
                        Text(option)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? .oneKickNeon : .white)
                            .padding(.leading, 10)
                        Spacer()
                        if hasVoted {
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isSelected ? .oneKickNeon : .gray)
                                .padding(.trailing, 10)
                        } else if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.oneKickNeon)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.oneKickNeon : Color.white.opacity(0.08), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !hasVoted else { return }   // nach eigener Stimme gesperrt
                    if poll.multiSelect {
                        if isSelected { selectedIndices.remove(idx) } else { selectedIndices.insert(idx) }
                    } else {
                        selectedIndices = [idx]
                    }
                }
            }

            // Footer
            HStack {
                if hasVoted {
                    Text("\(poll.totalVotes) " + (poll.totalVotes == 1
                        ? LanguageManager.shared.t("poll.vote")
                        : LanguageManager.shared.t("poll.votes")))
                        .font(.caption).foregroundColor(.gray)
                }

                Spacer()

                if !hasVoted {
                    Button(LanguageManager.shared.t("poll.submit")) {
                        guard !selectedIndices.isEmpty else { return }
                        HapticManager.instance.impact(style: .light)
                        viewModel.vote(pollId: poll.id, selectedIndices: Array(selectedIndices))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(selectedIndices.isEmpty ? .gray : .oneKickNeon)
                    .disabled(selectedIndices.isEmpty)
                }

                if isDeveloper {
                    Button(LanguageManager.shared.t("action.close")) {
                        viewModel.closePoll(pollId: poll.id)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.leading, 12)

                    Button(LanguageManager.shared.t("action.delete")) {
                        viewModel.deletePoll(pollId: poll.id)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.leading, 8)
                }
            }
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(12)
    }
}
