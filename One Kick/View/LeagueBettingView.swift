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
    @Published var odds: [Int: MatchWinnerOdds] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var currentMatchday: Int = 1

    // KO-Modus (Pokal, CL, etc.)
    @Published var allRounds: [String] = []
    @Published var currentRoundIndex: Int = 0

    // Relegations-Runden (erscheinen nach Spieltag maxMatchday)
    @Published var relegationRounds: [String] = []

    var isKOLeague: Bool { maxMatchday == 0 }
    var currentRoundName: String { allRounds.indices.contains(currentRoundIndex) ? allRounds[currentRoundIndex] : "" }
    var isInRelegation: Bool { currentMatchday > maxMatchday }
    var effectiveMaxMatchday: Int { maxMatchday + relegationRounds.count }

    var currentRoundDisplayLabel: String {
        if isInRelegation {
            let idx = currentMatchday - maxMatchday - 1
            return relegationRounds[safe: idx].map { roundLegLabel($0) } ?? "Relegation"
        }
        return "\(currentMatchday)"
    }

    private let service = APIFootballService()
    private let betManager = BetManager()
    private var leagueID: Int = 78
    private(set) var maxMatchday: Int = 34
    private var communityId: String = ""
    private var activeLeagues: [String] = []
    private var currentRoundTemplate: String = "Regular Season - {n}"
    private var regularSeasonTemplate: String = "Regular Season - {n}"

    private let playoffKeywords = ["Relegation", "Playoff", "Play-off", "Play Off", "Playout",
                                    "Promotion", "Barrage", "Qualification", "Qualifying", "Maintien"]

    private let intraLeagueRoundPatterns = [
        "Championship Round", "Relegation Round",
        "Championship Group", "Relegation Group"
    ]

    private func isPlayoffRound(_ round: String) -> Bool {
        if !LeagueMapper.hasRelegationPlayoff(leagueID: leagueID) {
            if intraLeagueRoundPatterns.contains(where: { round.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }
        return playoffKeywords.contains { round.localizedCaseInsensitiveContains($0) }
    }

    private func roundLegLabel(_ round: String) -> String {
        let num = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }.last ?? 0
        switch num {
        case 1: return "Hinspiel"
        case 2: return "Rückspiel"
        default: return num > 0 ? "Spiel \(num)" : "Relegation"
        }
    }

    func loadCurrentMatchday(for leagueID: Int, maxMatchday: Int = 34, communityId: String, activeLeagues: [String] = []) async {
        self.leagueID = leagueID
        self.maxMatchday = maxMatchday
        self.communityId = communityId
        self.activeLeagues = activeLeagues
        isLoading = true
        errorMessage = nil

        // Virtuelle Relegations-Liga: strukturelle Klassifizierung via classifyRounds + Whitelist
        if leagueID == 9999 {
            var pool: [MatchData] = []
            var seenIds = Set<Int>()
            for name in activeLeagues {
                let lid = LeagueMapper.getID(for: name)
                guard lid != 9999 else { continue }
                // Nur Ligen mit echtem ligaübergreifendem Relegations-Playoff
                guard LeagueMapper.hasRelegationPlayoff(leagueID: lid) else { continue }
                let max = LeagueMapper.getMaxMatchday(for: name)
                guard max > 0 else { continue }
                // Saisonrunden aus Cache + aktuelle Runde direkt (umgeht 24h-Cache-Miss)
                let allRoundsA = await service.fetchAllRounds(for: lid)
                let allRoundsB = await service.fetchCurrentRoundsRaw(for: lid)
                let combined = Array(Set(allRoundsA + allRoundsB))
                // Dominant-Prefix-Analyse: alles außerhalb regulärer Spieltage = Playoff
                let (_, rawPlayoff) = service.classifyRounds(combined, maxMatchday: max)
                // Ligatinterne Second-Phase-Runden ausschließen
                let playoffRoundNames = rawPlayoff.filter { r in
                    !intraLeagueRoundPatterns.contains(where: { r.localizedCaseInsensitiveContains($0) })
                }
                for round in playoffRoundNames {
                    for m in await service.fetchMatchesForRoundCached(lid, round: round)
                        where seenIds.insert(m.fixture.id).inserted {
                        pool.append(m)
                    }
                }
            }
            matches = pool.sorted { $0.fixture.date < $1.fixture.date }
            isLoading = false
            await loadBets()
            await loadOdds()
            return
        }

        if maxMatchday == 0 {
            // KO-Liga: alle Runden laden, aktuelle bestimmen
            let rounds = await service.fetchAllRounds(for: leagueID)
            allRounds = rounds
            let (currentRound, _) = await service.determineDisplayRound(for: leagueID, maxMatchday: 999)
            currentRoundIndex = rounds.firstIndex(of: currentRound) ?? max(0, rounds.count - 1)
            await loadRound(allRounds[safe: currentRoundIndex] ?? currentRound)
        } else {
            let (round, matchday) = await service.determineDisplayRound(for: leagueID, maxMatchday: maxMatchday)

            // classifyRounds: dominanter Prefix = reguläre Saison, Rest = Playoff/Relegation.
            // Funktioniert für alle Ligen ohne Liga-spezifisches Hardcoding.
            let allRoundsRaw = await service.fetchAllRounds(for: leagueID)
            let (regularRounds, playoffRounds) = service.classifyRounds(allRoundsRaw, maxMatchday: maxMatchday)
            relegationRounds = []  // Playoff-Runden laufen in die virtuelle "Relegation"-Liga

            let isEffectivelyPlayoff = playoffRounds.contains(round) || isPlayoffRound(round) || matchday <= 0

            if isEffectivelyPlayoff {
                // Playoff-Runden laufen in die virtuelle "Relegation"-Liga → immer letzten regulären Spieltag zeigen
                if let lastRegular = regularRounds.last {
                    let lastMd = lastRegular.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .compactMap { Int($0) }.last ?? maxMatchday
                    regularSeasonTemplate = lastRegular.replacingOccurrences(of: "\(lastMd)", with: "{n}")
                    currentRoundTemplate = regularSeasonTemplate
                    currentMatchday = maxMatchday
                    let targetRound = regularSeasonTemplate.replacingOccurrences(of: "{n}", with: "\(maxMatchday)")
                    await loadRound(targetRound)
                } else {
                    currentMatchday = maxMatchday
                    matches = []
                }
            } else {
                currentMatchday = matchday
                regularSeasonTemplate = round.replacingOccurrences(of: "\(matchday)", with: "{n}")
                currentRoundTemplate = regularSeasonTemplate
                await loadRound(round)
                // relegationRounds bereits oben aus classifyRounds gesetzt
            }
        }
        isLoading = false
        await loadBets()
        await loadOdds()
    }

    func loadMatchday(_ matchday: Int) async {
        let clamped = max(1, min(matchday, effectiveMaxMatchday))
        currentMatchday = clamped

        if clamped > maxMatchday {
            // Relegations-Runde
            let idx = clamped - maxMatchday - 1
            if let round = relegationRounds[safe: idx] {
                await loadRound(round)
            }
        } else {
            let round = regularSeasonTemplate.replacingOccurrences(of: "{n}", with: "\(clamped)")
            await loadRound(round)
        }
        await loadBets()
        await loadOdds()
    }

    func loadKORound(_ index: Int) async {
        let clamped = max(0, min(index, allRounds.count - 1))
        currentRoundIndex = clamped
        guard let round = allRounds[safe: clamped] else { return }
        await loadRound(round)
        await loadBets()
        await loadOdds()
    }

    private func loadRound(_ round: String) async {
        isLoading = true
        errorMessage = nil
        do {
            matches = try await service.fetchMatches(for: leagueID, round: round)
                .sorted { $0.fixture.date < $1.fixture.date }
        } catch {
            let msg = (error as? URLError)?.code == .badServerResponse
                ? "API-Limit erreicht – bitte kurz warten und erneut versuchen."
                : error.localizedDescription
            errorMessage = msg
            matches = []
        }
        isLoading = false
    }

    func loadBets() async {
        guard !communityId.isEmpty else { return }
        myBets = await betManager.loadBetScores(communityId: communityId)
    }

    func loadOdds() async {
        let futureIds = matches
            .filter { ["NS", "TBD"].contains($0.fixture.status.short) }
            .map(\.fixture.id)
        guard !futureIds.isEmpty else { return }
        await withTaskGroup(of: (Int, MatchWinnerOdds?).self) { group in
            for id in futureIds {
                group.addTask { (id, await self.service.fetchOdds(for: id)) }
            }
            for await (id, o) in group {
                if let o { odds[id] = o }
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
    @State private var selectedMatchForLiveInfo: MatchData?

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .center) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left").font(.title3.bold()).foregroundColor(.white)
                                .frame(width: 40, height: 40).background(Color.oneKickDarkGray).clipShape(Circle())
                        }
                        Spacer()
                        if !viewModel.isKOLeague {
                            Button(action: {
                                HapticManager.instance.impact(style: .light)
                                showStandingsSheet = true
                            }) {
                                Text("Tabelle")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Color.oneKickNeon)
                                    .cornerRadius(20)
                            }
                        } else {
                            Color.clear.frame(width: 40, height: 40)
                        }
                    }
                    VStack(spacing: 2) {
                        Text(leagueName).font(.headline).bold().foregroundColor(.white)
                        Text(community.name).font(.caption).foregroundColor(.gray)
                    }
                    .allowsHitTesting(false)
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
                            // Reguläre Liga: Spieltag-Navigation (inkl. Relegation nach maxMatchday)
                            VStack(spacing: 8) {
                                if viewModel.isInRelegation {
                                    Text("RELEGATION")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange).tracking(1)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(6)
                                } else {
                                    Text("SPIELTAG").font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.oneKickNeon).tracking(1)
                                }
                                HStack(spacing: 20) {
                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadMatchday(viewModel.currentMatchday - 1) }
                                    }) {
                                        CircleButton(icon: "chevron.left", enabled: viewModel.currentMatchday > 1)
                                    }
                                    .disabled(viewModel.currentMatchday <= 1 || viewModel.isLoading)

                                    Text(viewModel.currentRoundDisplayLabel)
                                        .font(.headline).bold()
                                        .foregroundColor(viewModel.isInRelegation ? .orange : .white)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 120)

                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task { await viewModel.loadMatchday(viewModel.currentMatchday + 1) }
                                    }) {
                                        CircleButton(icon: "chevron.right", enabled: viewModel.currentMatchday < viewModel.effectiveMaxMatchday)
                                    }
                                    .disabled(viewModel.currentMatchday >= viewModel.effectiveMaxMatchday || viewModel.isLoading)
                                }
                            }
                            .padding(.vertical, 10)
                        }

                        VStack(spacing: 12) {
                            Text(viewModel.isKOLeague ? viewModel.currentRoundName : (maxMatchday > 0 ? (viewModel.isInRelegation ? "Relegation · \(viewModel.currentRoundDisplayLabel)" : "Spieltag \(viewModel.currentMatchday)") : "Aktuelle Spiele"))
                                .font(.headline).bold().foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
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
                    odds: viewModel.odds[match.fixture.id],
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
        .sheet(item: $selectedMatchForLiveInfo) { match in
            LiveMatchView(match: match)
        }
        .onAppear {
            Task {
                await viewModel.loadCurrentMatchday(
                    for: leagueID,
                    maxMatchday: maxMatchday,
                    communityId: community.id ?? "",
                    activeLeagues: Array(community.activeLeagues)
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
                            communityId: community.id ?? "",
                            activeLeagues: Array(community.activeLeagues)
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
                let isLiveMatch = ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short)
                VStack(spacing: 6) {
                    ApiMatchRow(
                        match: match,
                        onTapTip: {
                            selectedMatchForPopup = match
                            showBettingPopup = true
                        },
                        myTip: viewModel.myBets[match.fixture.id],
                        odds: viewModel.odds[match.fixture.id],
                        onLiveInfo: isLiveMatch ? { selectedMatchForLiveInfo = match } : nil
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
