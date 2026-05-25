//
//  AllOpenGamesView.swift
//  One Kick
//

import SwiftUI

struct AllOpenGamesView: View {
    let matches: [MatchData]
    var communityId: String = ""

    @Environment(\.dismiss) var dismiss

    @State private var showPopup = false
    @State private var selectedMatchForPopup: MatchData?
    @State private var odds: [Int: MatchWinnerOdds] = [:]

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.oneKickDarkGray)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Offene Tipps")
                        .font(.headline).bold()
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 40, height: 40)
                }
                .padding()

                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(matches, id: \.fixture.id) { match in
                            ApiMatchRow(
                                match: match,
                                onTapTip: {
                                    selectedMatchForPopup = match
                                    showPopup = true
                                },
                                odds: odds[match.fixture.id]
                            )
                        }
                    }
                    .padding()
                }
            }

            if showPopup, let match = selectedMatchForPopup {
                BettingPopupView(
                    isPresented: $showPopup,
                    match: match,
                    communityId: communityId,
                    odds: odds[match.fixture.id]
                )
                .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .task { await loadOdds() }
    }

    private func loadOdds() async {
        let api = APIFootballService()
        let futureIds = matches
            .filter { ["NS", "TBD"].contains($0.fixture.status.short) }
            .map(\.fixture.id)
        guard !futureIds.isEmpty else { return }
        await withTaskGroup(of: (Int, MatchWinnerOdds?).self) { group in
            for id in futureIds {
                group.addTask { (id, await api.fetchOdds(for: id)) }
            }
            for await (id, o) in group {
                if let o { odds[id] = o }
            }
        }
    }
}
