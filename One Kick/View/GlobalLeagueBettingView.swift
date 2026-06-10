//
//  GlobalLeagueBettingView.swift
//  One Kick
//
//  Eigenständiges Spieltage-Tippen für die Globale Community – ohne reguläre Community.
//  Tipps gehen in den globalen Tipp-Speicher (GlobalBetManager); Score wird neu berechnet.
//

import SwiftUI

struct GlobalLeagueBettingView: View {
    let leagueName: String
    @ObservedObject var globalVM: GlobalCommunityViewModel

    private let api = APIFootballService()
    private var leagueID: Int { LeagueMapper.getID(for: leagueName) }
    private var maxMatchday: Int { LeagueMapper.getMaxMatchday(for: leagueName) }
    private var isKO: Bool { maxMatchday == 0 }

    @State private var matches: [MatchData] = []
    @State private var myBets: [Int: (home: Int, away: Int)] = [:]
    @State private var currentMatchday = 1
    @State private var roundTemplate = ""        // "Regular Season - {n}"
    @State private var allRounds: [String] = []  // KO
    @State private var currentRoundIndex = 0
    @State private var currentRoundName = ""
    @State private var isLoading = true
    @State private var showPopup = false
    @State private var selectedMatch: MatchData?

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    navHeader

                    if isLoading {
                        ProgressView().tint(.oneKickNeon)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if matches.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "sportscourt").font(.system(size: 40)).foregroundColor(.gray)
                            Text("Keine Spiele gefunden").font(.headline).bold().foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        ForEach(matches, id: \.fixture.id) { match in
                            ApiMatchRow(
                                match: match,
                                onTapTip: {
                                    selectedMatch = match
                                    showPopup = true
                                },
                                myTip: myBets[match.fixture.id]
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }

            if showPopup, let match = selectedMatch {
                BettingPopupView(
                    isPresented: $showPopup,
                    match: match,
                    communityId: "",
                    globalLeague: leagueName,
                    onSaved: {
                        Task {
                            myBets = await globalVM.loadGlobalBets(for: leagueName)
                            await globalVM.recomputeScore(for: leagueName)
                        }
                    }
                )
            }
        }
        .task { await loadCurrent() }
    }

    // MARK: - Navigation Header

    @ViewBuilder
    private var navHeader: some View {
        if isKO {
            HStack(spacing: 20) {
                Button(action: { Task { await loadRound(currentRoundIndex - 1) } }) {
                    CircleButton(icon: "chevron.left", enabled: currentRoundIndex > 0)
                }.disabled(currentRoundIndex <= 0 || isLoading)

                Text(localizedRoundName(currentRoundName))
                    .font(.headline).bold().foregroundColor(.white)
                    .multilineTextAlignment(.center).frame(minWidth: 140)

                Button(action: { Task { await loadRound(currentRoundIndex + 1) } }) {
                    CircleButton(icon: "chevron.right", enabled: currentRoundIndex < allRounds.count - 1)
                }.disabled(currentRoundIndex >= allRounds.count - 1 || isLoading)
            }
            .padding(.vertical, 10)
        } else {
            VStack(spacing: 8) {
                Text("SPIELTAG").font(.system(size: 10, weight: .bold))
                    .foregroundColor(.oneKickNeon).tracking(1)
                HStack(spacing: 20) {
                    Button(action: { Task { await loadMatchday(currentMatchday - 1) } }) {
                        CircleButton(icon: "chevron.left", enabled: currentMatchday > 1)
                    }.disabled(currentMatchday <= 1 || isLoading)

                    Text("Spieltag \(currentMatchday)")
                        .font(.headline).bold().foregroundColor(.white)
                        .frame(width: 120)

                    Button(action: { Task { await loadMatchday(currentMatchday + 1) } }) {
                        CircleButton(icon: "chevron.right", enabled: currentMatchday < maxMatchday)
                    }.disabled(currentMatchday >= maxMatchday || isLoading)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Laden

    private func loadCurrent() async {
        isLoading = true
        myBets = await globalVM.loadGlobalBets(for: leagueName)
        if isKO {
            allRounds = await api.fetchAllRounds(for: leagueID)
            let (round, _) = await api.determineDisplayRound(for: leagueID, maxMatchday: 999)
            currentRoundIndex = allRounds.firstIndex(of: round) ?? max(0, allRounds.count - 1)
            currentRoundName = allRounds[safe: currentRoundIndex] ?? round
            matches = ((try? await api.fetchMatches(for: leagueID, round: currentRoundName)) ?? [])
                .sorted { $0.fixture.date < $1.fixture.date }
        } else {
            let r = await api.determineDisplayRoundWithMatches(for: leagueID, maxMatchday: maxMatchday)
            currentMatchday = r.matchday
            roundTemplate = r.round.replacingOccurrences(of: "\(r.matchday)", with: "{n}")
            matches = r.matches.sorted { $0.fixture.date < $1.fixture.date }
        }
        isLoading = false
    }

    private func loadMatchday(_ md: Int) async {
        let clamped = max(1, min(md, maxMatchday))
        currentMatchday = clamped
        isLoading = true
        let round = roundTemplate.replacingOccurrences(of: "{n}", with: "\(clamped)")
        matches = ((try? await api.fetchMatches(for: leagueID, round: round)) ?? [])
            .sorted { $0.fixture.date < $1.fixture.date }
        isLoading = false
    }

    private func loadRound(_ idx: Int) async {
        let clamped = max(0, min(idx, allRounds.count - 1))
        currentRoundIndex = clamped
        guard let round = allRounds[safe: clamped] else { return }
        currentRoundName = round
        isLoading = true
        matches = ((try? await api.fetchMatches(for: leagueID, round: round)) ?? [])
            .sorted { $0.fixture.date < $1.fixture.date }
        isLoading = false
    }
}
