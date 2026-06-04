//
//  StartseiteView.swift
//  One Kick
//
//  UPDATE:
//  - Upcoming-Matches werden einmalig geladen und für offene Tipps UND Top-Spiele geteilt.
//  - Top Spiele nutzen Smart-Algorithmus (Lieblingsteams → Lieblingsligen → aktive Ligen).
//

import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class StartseiteViewModel: ObservableObject {
    @Published var openTips: [OpenTipItem] = []
    @Published var topMatches: [MatchData] = []
    @Published var topMatchTips: [Int: (home: Int, away: Int)] = [:]
    @Published var odds: [Int: MatchWinnerOdds] = [:]
    @Published var isLoadingTips = false
    @Published var isLoadingTop = false

    private let api = APIFootballService()
    private let betManager = BetManager()

    func loadData(communities: [CommunityModel]) async {
        guard !communities.isEmpty else { return }
        var seen = Set<Int>()
        var activeLeagueIds: [Int] = []
        for community in communities {
            for leagueName in community.activeLeagues {
                let id = LeagueMapper.getID(for: leagueName)
                if seen.insert(id).inserted { activeLeagueIds.append(id) }
            }
        }
        let settings = UserSettings.shared
        let allNeededIds = Array(Set(activeLeagueIds + settings.favoriteLeagueIds))
        let playoffKw = ["relegation", "playoff", "play-off", "barrage", "qualifying",
                         "promotion", "qualification", "playout", "maintien"]

        // Phase 1: Playoff-Runden klassifizieren (parallel, fetchAllRounds hat 24h-Cache)
        var playoffRoundsByLeagueId: [Int: Set<String>] = [:]
        let leaguesToClassify = allNeededIds.filter {
            $0 != 9999 && LeagueMapper.hasRelegationPlayoff(leagueID: $0) && LeagueMapper.getMaxMatchday(for: $0) > 0
        }
        await withTaskGroup(of: (Int, Set<String>).self) { group in
            for id in leaguesToClassify {
                let maxMd = LeagueMapper.getMaxMatchday(for: id)
                group.addTask {
                    let allRounds = await self.api.fetchAllRounds(for: id)
                    let (_, rawPlayoff) = self.api.classifyRounds(allRounds, maxMatchday: maxMd)
                    let intraExclude = ["championship round", "championship group", "relegation group"]
                    let playoff = Set(rawPlayoff.filter { r in
                        !intraExclude.contains(where: { r.lowercased().contains($0) })
                    })
                    return (id, playoff)
                }
            }
            for await (id, rounds) in group {
                if !rounds.isEmpty { playoffRoundsByLeagueId[id] = rounds }
            }
        }

        // Phase 2: Current Matches laden (sequenziell – verhindert Rate-Limit-Pile-up)
        var fullPreloaded: [Int: [MatchData]] = [:]
        var tipsPreloaded: [Int: [MatchData]] = [:]
        for id in allNeededIds {
            guard id != 9999 else { continue }
            let matches = await api.fetchCurrentAndUpcomingMatches(for: id)
            fullPreloaded[id] = matches
            tipsPreloaded[id] = matches.filter { ["NS", "TBD"].contains($0.fixture.status.short) }
        }

        // Phase 3: Playoff-Matches aus tipsPreloaded herausfiltern → relegation pool
        var relegationPool: [MatchData] = []
        var seenInPool = Set<Int>()
        for id in leaguesToClassify {
            let playoffRounds = playoffRoundsByLeagueId[id] ?? []
            guard !playoffRounds.isEmpty, let matches = tipsPreloaded[id] else { continue }
            var regular: [MatchData] = []
            let maxMd = LeagueMapper.getMaxMatchday(for: id)
            for m in matches {
                let round = m.league.round ?? ""
                let lower = round.lowercased()
                let roundNum = lower.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }.last ?? 0
                let isPlayoff = playoffRounds.contains(round)
                    || playoffKw.contains(where: { lower.contains($0) })
                    || (maxMd > 0 && roundNum > 0 && roundNum > maxMd)
                if isPlayoff {
                    if seenInPool.insert(m.fixture.id).inserted { relegationPool.append(m) }
                } else {
                    regular.append(m)
                }
            }
            tipsPreloaded[id] = regular
        }

        // UI sofort nach Phase 3 aktualisieren (ohne auf Phase 4 zu warten)
        tipsPreloaded[9999] = relegationPool.filter { ["NS", "TBD"].contains($0.fixture.status.short) }
        await loadOpenTips(communities: communities, preloaded: tipsPreloaded)
        await loadTopMatches(preloaded: fullPreloaded, activeLeagueIds: activeLeagueIds)
        await loadTopMatchTips(communities: communities)
        await loadPredictions()

        // Phase 4: DateRange-Fallback im Hintergrund (erweitert Relegations-Pool)
        let relDateFmt = DateFormatter(); relDateFmt.dateFormat = "yyyy-MM-dd"
        let relFrom = relDateFmt.string(from: Date().addingTimeInterval(-21 * 86400))
        let relTo   = relDateFmt.string(from: Date().addingTimeInterval(21 * 86400))
        for id in allNeededIds where id != 9999 && LeagueMapper.hasRelegationPlayoff(leagueID: id) {
            let all = await api.fetchMatchesByDateRange(for: id, from: relFrom, to: relTo)
            let maxMd = LeagueMapper.getMaxMatchday(for: id)
            let playoffRounds = playoffRoundsByLeagueId[id]
            for m in all {
                guard seenInPool.insert(m.fixture.id).inserted else { continue }
                let round = m.league.round ?? ""
                let lower = round.lowercased()
                let roundNum = lower.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }.last ?? 0
                var isP = playoffRounds?.contains(round) ?? false
                if !isP { isP = playoffKw.contains(where: { lower.contains($0) }) }
                if !isP, maxMd > 0, roundNum > 0 { isP = roundNum > maxMd }
                if isP { relegationPool.append(m) }
            }
        }
        // Stilles Update: Relegations-Daten nach Phase 4 einarbeiten (falls vorhanden)
        let updatedPool = relegationPool.filter { ["NS", "TBD"].contains($0.fixture.status.short) }
        if updatedPool.count != (tipsPreloaded[9999]?.count ?? 0) {
            tipsPreloaded[9999] = updatedPool
            await loadOpenTips(communities: communities, preloaded: tipsPreloaded)
        }
    }

    func removeTip(_ tip: OpenTipItem) {
        openTips.removeAll { $0.id == tip.id }
    }

    private func loadOpenTips(communities: [CommunityModel], preloaded: [Int: [MatchData]]) async {
        isLoadingTips = true
        defer { isLoadingTips = false }

        var communityBets: [String: Set<Int>] = [:]
        for community in communities {
            guard let cid = community.id else { continue }
            communityBets[cid] = await betManager.loadBets(communityId: cid)
        }

        let playoffKw = ["relegation", "playoff", "play-off", "barrage", "qualifying",
                         "promotion", "qualification", "playout", "maintien"]

        let relegationIds = Set((preloaded[9999] ?? []).map { $0.fixture.id })

        var tips: [OpenTipItem] = []
        var seen = Set<String>()
        for community in communities {
            guard let cid = community.id else { continue }
            let tipped = communityBets[cid] ?? []
            let hasRelegation = community.activeLeagues.contains("Relegation")
            for leagueName in community.activeLeagues {
                let leagueID = LeagueMapper.getID(for: leagueName)
                guard let matches = preloaded[leagueID] else { continue }
                for match in matches where !tipped.contains(match.fixture.id) {
                    let key = "\(match.fixture.id)_\(cid)"
                    guard seen.insert(key).inserted else { continue }
                    var displayName = leagueName
                    if leagueID != 9999 && LeagueMapper.hasRelegationPlayoff(leagueID: leagueID) {
                        let round = match.league.round ?? ""
                        let lower = round.lowercased()
                        // Check 1: Match ist im Relegations-Pool (zuverlässigste Methode)
                        var isPlayoff = relegationIds.contains(match.fixture.id)
                        // Check 2: Keyword-basiert
                        if !isPlayoff { isPlayoff = lower.isEmpty || playoffKw.contains(where: { lower.contains($0) }) }
                        // Check 3: RoundNum > maxMatchday
                        if !isPlayoff {
                            let maxMd = LeagueMapper.getMaxMatchday(for: leagueName)
                            if maxMd > 0 {
                                let roundNum = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                    .compactMap { Int($0) }.last ?? 0
                                if roundNum > maxMd { isPlayoff = true }
                            }
                        }
                        if isPlayoff {
                            if hasRelegation {
                                displayName = "Relegation"
                            } else {
                                continue
                            }
                        }
                    }
                    tips.append(OpenTipItem(id: key, match: match, community: community, leagueName: displayName))
                }
            }
        }

        let iso = ISO8601DateFormatter()
        tips.sort {
            (iso.date(from: $0.match.fixture.date) ?? .distantFuture) <
            (iso.date(from: $1.match.fixture.date) ?? .distantFuture)
        }
        openTips = Array(tips.prefix(3))
    }

    private func loadTopMatchTips(communities: [CommunityModel]) async {
        var merged: [Int: (home: Int, away: Int)] = [:]
        for community in communities {
            guard let cid = community.id else { continue }
            let scores = await betManager.loadBetScores(communityId: cid)
            for (fixtureId, tip) in scores where merged[fixtureId] == nil {
                merged[fixtureId] = tip
            }
        }
        topMatchTips = merged
    }

    private func loadPredictions() async {
        var ids = Set(openTips.map { $0.match.fixture.id })
        for m in topMatches where ["NS", "TBD"].contains(m.fixture.status.short) {
            ids.insert(m.fixture.id)
        }
        // Sequenziell laden um Rate-Limiting zu vermeiden
        var result: [Int: MatchWinnerOdds] = odds  // bestehende Odds behalten
        for id in ids {
            if let o = await api.fetchOdds(for: id) {
                result[id] = o
            }
        }
        odds = result
    }

    private func loadTopMatches(preloaded: [Int: [MatchData]], activeLeagueIds: [Int]) async {
        isLoadingTop = true
        defer { isLoadingTop = false }
        let settings = UserSettings.shared
        topMatches = await api.fetchSmartTopMatches(
            favoriteTeamIds: settings.favoriteTeamIds,
            favoriteLeagueIds: settings.favoriteLeagueIds,
            activeLeagueIds: activeLeagueIds,
            preloaded: preloaded
        )
    }
}

struct StartseiteView: View {
    @StateObject private var viewModel = StartseiteViewModel()
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var lm: LanguageManager
    @EnvironmentObject var authManager: AuthManager

    @State private var showBettingPopup = false
    @State private var selectedTip: OpenTipItem?
    @State private var showProfileSheet = false
    @State private var showCommunityMenu = false
    @State private var liveMatchForInfo: MatchData?
    @State private var lastRefreshAt: Date = .distantPast

    private func refreshIfStale() {
        guard Date().timeIntervalSince(lastRefreshAt) > 30 else { return }
        lastRefreshAt = .now
        Task { await viewModel.loadData(communities: communityManager.communities) }
    }

    private var hasCommunities: Bool { !communityManager.communities.isEmpty }

    private var greetingName: String {
        if let name = authManager.displayName, !name.isEmpty { return ", \(name)" }
        return ""
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    OneKickHeader(onProfile: { showProfileSheet = true })

                    Text(authManager.isFirstLogin
                         ? "Willkommen bei OneKick\(greetingName)!"
                         : "Willkommen zurück\(greetingName)!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, -8)

                    if hasCommunities {
                        sectionHeader(lm.t("home.openTips"))

                        if viewModel.isLoadingTips {
                            loadingRow()
                        } else if viewModel.openTips.isEmpty {
                            emptyState(icon: "checkmark.circle.fill",
                                       text: "Du hast alle Spiele für den aktuellen Spieltag getippt.")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.openTips) { tip in
                                    OpenGameCard(
                                        tip: tip,
                                        odds: viewModel.odds[tip.match.fixture.id]
                                    ) {
                                        HapticManager.instance.impact(style: .light)
                                        selectedTip = tip
                                        showBettingPopup = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        sectionHeader(lm.t("home.topMatches"))

                        if viewModel.isLoadingTop {
                            loadingRow()
                        } else if viewModel.topMatches.isEmpty {
                            emptyState(icon: "sportscourt", text: "Keine Top-Spiele verfügbar.")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.topMatches, id: \.fixture.id) { match in
                                    let isFuture = ["NS", "TBD"].contains(match.fixture.status.short)
                                    let isLiveMatch = ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short)
                                    ApiMatchRow(
                                        match: match,
                                        myTip: isFuture ? nil : viewModel.topMatchTips[match.fixture.id],
                                        showLeague: true,
                                        odds: isFuture ? viewModel.odds[match.fixture.id] : nil,
                                        onLiveInfo: isLiveMatch ? { liveMatchForInfo = match } : nil
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            Spacer(minLength: 40)
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.oneKickNeon)
                            Text("Tritt einer Liga bei oder erstelle deine eigene.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showCommunityMenu = true
                            }) {
                                Text("Loslegen")
                                    .font(.headline).bold().foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.oneKickNeon)
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal, 40)
                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 50)
                }
            }

            if showBettingPopup, let tip = selectedTip {
                BettingPopupView(
                    isPresented: $showBettingPopup,
                    match: tip.match,
                    communityId: tip.community.id ?? "",
                    odds: viewModel.odds[tip.match.fixture.id],
                    onSaved: {
                        viewModel.removeTip(tip)
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            await viewModel.loadData(communities: communityManager.communities)
                        }
                    }
                )
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
        .sheet(isPresented: $showCommunityMenu) {
            CommunityStartMenu()
                .environmentObject(communityManager)
        }
        .sheet(item: $liveMatchForInfo) { match in
            LiveMatchView(match: match)
        }
        .task { await viewModel.loadData(communities: communityManager.communities) }
        .onChange(of: communityManager.communities) { _, communities in
            Task { await viewModel.loadData(communities: communities) }
        }
        .onAppear { refreshIfStale() }
        .onChange(of: communityManager.appBecameActive) { _, _ in
            Task { await viewModel.loadData(communities: communityManager.communities) }
        }
    }

    @ViewBuilder private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.headline).bold().foregroundColor(.white).padding(.horizontal)
    }

    @ViewBuilder private func loadingRow() -> some View {
        ProgressView().tint(.oneKickNeon).frame(maxWidth: .infinity).padding(.vertical, 20)
    }

    @ViewBuilder private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 30)).foregroundColor(.gray)
            Text(text).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20).padding(.horizontal)
    }
}
