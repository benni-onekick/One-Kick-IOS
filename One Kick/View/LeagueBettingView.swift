//
//  LeagueBettingView.swift
//  One Kick
//
//  UPDATE: Gespeicherte Tipps werden geladen und in ApiMatchRow angezeigt.
//

import SwiftUI
import Combine

@MainActor
class LeagueBettingViewModel: ObservableObject {
    @Published var matches: [MatchData] = []
    @Published var myBets: [Int: (home: Int, away: Int)] = [:]
    @Published var predictions: [Int: MatchPrediction] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var currentMatchday: Int = 1

    // KO-Modus (Pokal, CL, etc.)
    @Published var allRounds: [String] = []
    @Published var currentRoundIndex: Int = 0

    var isKOLeague: Bool { maxMatchday == 0 }
    var currentRoundName: String { allRounds.indices.contains(currentRoundIndex) ? allRounds[currentRoundIndex] : "" }

    private let service = APIFootballService()
    private let betManager = BetManager()
    private var leagueID: Int = 78
    private(set) var maxMatchday: Int = 34
    private var communityId: String = ""
    private var currentRoundTemplate: String = "Regular Season - {n}"

    func loadCurrentMatchday(for leagueID: Int, maxMatchday: Int = 34, communityId: String) async {
        self.leagueID = leagueID
        self.maxMatchday = maxMatchday
        self.communityId = communityId
        isLoading = true
        errorMessage = nil

        if maxMatchday == 0 {
            // KO-Liga: alle Runden laden, aktuelle bestimmen
            let rounds = await service.fetchAllRounds(for: leagueID)
            allRounds = rounds
            let (currentRound, _) = await service.determineDisplayRound(for: leagueID, maxMatchday: 999)
            currentRoundIndex = rounds.firstIndex(of: currentRound) ?? max(0, rounds.count - 1)
            await loadRound(allRounds[safe: currentRoundIndex] ?? currentRound)
        } else {
            let (round, matchday) = await service.determineDisplayRound(for: leagueID, maxMatchday: maxMatchday)
            currentMatchday = matchday
            // Template aus echtem Round-String ableiten: "Ligue 1 - 34" → "Ligue 1 - {n}"
            if matchday > 0 {
                currentRoundTemplate = round.replacingOccurrences(of: "\(matchday)", with: "{n}")
            }
            await loadRound(round)
        }
        isLoading = false
        await loadBets()
        await loadPredictions()
    }

    func loadMatchday(_ matchday: Int) async {
        let clamped = max(1, min(matchday, maxMatchday))
        currentMatchday = clamped
        let round = currentRoundTemplate.replacingOccurrences(of: "{n}", with: "\(clamped)")
        await loadRound(round)
        await loadBets()
        await loadPredictions()
    }

    func loadKORound(_ index: Int) async {
        let clamped = max(0, min(index, allRounds.count - 1))
        currentRoundIndex = clamped
        guard let round = allRounds[safe: clamped] else { return }
        await loadRound(round)
        await loadBets()
        await loadPredictions()
    }

    private func loadRound(_ round: String) async {
        isLoading = true
        errorMessage = nil
        do {
            matches = try await service.fetchMatches(for: leagueID, round: round)
        } catch {
            errorMessage = error.localizedDescription
            matches = []
        }
        isLoading = false
    }

    func loadBets() async {
        guard !communityId.isEmpty else { return }
        myBets = await betManager.loadBetScores(communityId: communityId)
    }

    func loadPredictions() async {
        let futureIds = matches
            .filter { ["NS", "TBD"].contains($0.fixture.status.short) }
            .map(\.fixture.id)
        guard !futureIds.isEmpty else { return }
        await withTaskGroup(of: (Int, MatchPrediction?).self) { group in
            for id in futureIds {
                group.addTask { (id, await self.service.fetchPrediction(for: id)) }
            }
            for await (id, pred) in group {
                if let p = pred { predictions[id] = p }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct LeagueBettingView: View {
    let community: CommunityModel
    let leagueID: Int
    let leagueName: String
    var maxMatchday: Int = 34

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = LeagueBettingViewModel()

    @State private var showBettingPopup = false
    @State private var selectedMatchForPopup: MatchData?

    @State private var showStandingsSheet = false
    @State private var selectedMatchForLineup: MatchData?

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left").font(.title3.bold()).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Color.oneKickDarkGray).clipShape(Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(leagueName).font(.headline).bold().foregroundColor(.white)
                        Text(community.name).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    if !viewModel.isKOLeague {
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            showStandingsSheet = true
                        }) {
                            Text("Tabelle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.oneKickNeon)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.oneKickNeon.opacity(0.12))
                                .cornerRadius(20)
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal).padding(.top, 10).padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 25) {

                        if viewModel.isKOLeague {
                            // KO-Liga: Runden-Navigation mit Namen
                            VStack(spacing: 8) {
                                Text("RUNDE").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.oneKickNeon).tracking(1)
                                HStack(spacing: 20) {
                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadKORound(viewModel.currentRoundIndex - 1) }
                                    }) {
                                        CircleButton(icon: "chevron.left", enabled: viewModel.currentRoundIndex > 0)
                                    }
                                    .disabled(viewModel.currentRoundIndex <= 0 || viewModel.isLoading)

                                    Text(viewModel.currentRoundName)
                                        .font(.headline).bold().foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 140)

                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadKORound(viewModel.currentRoundIndex + 1) }
                                    }) {
                                        CircleButton(icon: "chevron.right", enabled: viewModel.currentRoundIndex < viewModel.allRounds.count - 1)
                                    }
                                    .disabled(viewModel.currentRoundIndex >= viewModel.allRounds.count - 1 || viewModel.isLoading)
                                }
                            }
                            .padding(.vertical, 10)
                        } else if maxMatchday > 0 {
                            // Reguläre Liga: Spieltag-Navigation
                            VStack(spacing: 8) {
                                Text("SPIELTAG").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.oneKickNeon).tracking(1)
                                HStack(spacing: 20) {
                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadMatchday(viewModel.currentMatchday - 1) }
                                    }) {
                                        CircleButton(icon: "chevron.left", enabled: viewModel.currentMatchday > 1)
                                    }
                                    .disabled(viewModel.currentMatchday <= 1 || viewModel.isLoading)

                                    Text("\(viewModel.currentMatchday)")
                                        .font(.headline).bold().foregroundColor(.white).frame(width: 100)

                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadMatchday(viewModel.currentMatchday + 1) }
                                    }) {
                                        CircleButton(icon: "chevron.right", enabled: viewModel.currentMatchday < viewModel.maxMatchday)
                                    }
                                    .disabled(viewModel.currentMatchday >= viewModel.maxMatchday || viewModel.isLoading)
                                }
                            }
                            .padding(.vertical, 10)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(viewModel.isKOLeague ? viewModel.currentRoundName : (maxMatchday > 0 ? "Spieltag \(viewModel.currentMatchday)" : "Aktuelle Spiele"))
                                .font(.headline).bold().foregroundColor(.white).padding(.horizontal)
                            contentForCurrentState
                        }

                        Spacer(minLength: 50)
                    }
                }
            }

            if showBettingPopup, let match = selectedMatchForPopup {
                BettingPopupView(
                    isPresented: $showBettingPopup,
                    match: match,
                    communityId: community.id ?? "",
                    prediction: viewModel.predictions[match.fixture.id],
                    onSaved: {
                        Task { await viewModel.loadBets() }
                    }
                )
                .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showStandingsSheet) {
            StandingsSheet(leagueID: leagueID, leagueName: leagueName)
        }
        .sheet(item: $selectedMatchForLineup) { match in
            LineupSheet(match: match)
        }
        .onAppear {
            Task {
                await viewModel.loadCurrentMatchday(
                    for: leagueID,
                    maxMatchday: maxMatchday,
                    communityId: community.id ?? ""
                )
            }
        }
    }

    @ViewBuilder
    private var contentForCurrentState: some View {
        if viewModel.isLoading {
            VStack(spacing: 10) {
                ProgressView().tint(.oneKickNeon)
                Text("Spiele werden geladen...").font(.caption).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)

        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(.orange)
                Text("Konnte keine Spiele laden").font(.headline).bold().foregroundColor(.white)
                Text(errorMessage).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                Button(action: {
                    Task {
                        await viewModel.loadCurrentMatchday(
                            for: leagueID,
                            maxMatchday: maxMatchday,
                            communityId: community.id ?? ""
                        )
                    }
                }) {
                    Text("Erneut versuchen").font(.caption).bold()
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.oneKickNeon).foregroundColor(.black).cornerRadius(8)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal)

        } else if viewModel.matches.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "sportscourt").font(.system(size: 40)).foregroundColor(.gray)
                Text("Keine Spiele gefunden").font(.headline).bold().foregroundColor(.white)
                Text(maxMatchday > 0
                     ? "Für Spieltag \(viewModel.currentMatchday) gibt es keine Daten."
                     : "Aktuell keine Spiele verfügbar.")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal)

        } else {
            ForEach(viewModel.matches, id: \.fixture.id) { match in
                VStack(spacing: 6) {
                    ApiMatchRow(
                        match: match,
                        onTapTip: {
                            selectedMatchForPopup = match
                            showBettingPopup = true
                        },
                        myTip: viewModel.myBets[match.fixture.id],
                        prediction: viewModel.predictions[match.fixture.id]
                    )

                    Button(action: {
                        HapticManager.instance.impact(style: .light)
                        selectedMatchForLineup = match
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 10))
                            Text("Aufstellung")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.oneKickDarkGray.opacity(0.5))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
