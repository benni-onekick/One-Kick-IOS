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
    @Published var isLoadingTips = false
    @Published var isLoadingTop = false

    private let api = APIFootballService()
    private let betManager = BetManager()

    func loadData(communities: [CommunityModel]) async {
        // Alle benötigten Liga-IDs berechnen
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

        // Für jede Liga einmalig laden: Live + Upcoming (spart API-Calls)
        var fullPreloaded: [Int: [MatchData]] = [:]   // NS/TBD + Live → für Top-Spiele
        var tipsPreloaded: [Int: [MatchData]] = [:]   // nur NS/TBD → für offene Tipps
        for id in allNeededIds {
            let matches = await api.fetchCurrentAndUpcomingMatches(for: id)
            fullPreloaded[id] = matches
            tipsPreloaded[id] = matches.filter { ["NS", "TBD"].contains($0.fixture.status.short) }
        }

        await loadOpenTips(communities: communities, preloaded: tipsPreloaded)
        await loadTopMatches(preloaded: fullPreloaded, activeLeagueIds: activeLeagueIds)
        await loadTopMatchTips(communities: communities)
    }

    func removeTip(_ tip: OpenTipItem) {
        openTips.removeAll { $0.id == tip.id }
    }

    private func loadOpenTips(communities: [CommunityModel], preloaded: [Int: [MatchData]]) async {
        isLoadingTips = true
        defer { isLoadingTips = false }

        // Bereits getippte Spiele laden
        var communityBets: [String: Set<Int>] = [:]
        for community in communities {
            guard let cid = community.id else { continue }
            communityBets[cid] = await betManager.loadBets(communityId: cid)
        }

        // Ungetippte Spiele sammeln
        var tips: [OpenTipItem] = []
        for community in communities {
            guard let cid = community.id else { continue }
            let tipped = communityBets[cid] ?? []
            for leagueName in community.activeLeagues {
                let leagueID = LeagueMapper.getID(for: leagueName)
                guard let matches = preloaded[leagueID] else { continue }
                for match in matches where !tipped.contains(match.fixture.id) {
                    tips.append(OpenTipItem(
                        id: "\(match.fixture.id)_\(cid)",
                        match: match, community: community, leagueName: leagueName
                    ))
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
    @EnvironmentObject var authManager: AuthManager

    @State private var showBettingPopup = false
    @State private var selectedTip: OpenTipItem?
    @State private var showProfileSheet = false

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

                    Text("Willkommen zurück\(greetingName)!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, -8)

                    // Offene Tipps nur anzeigen wenn in einer Community
                    if hasCommunities {
                        sectionHeader("Meine offenen Tipps")

                        if viewModel.isLoadingTips {
                            loadingRow()
                        } else if viewModel.openTips.isEmpty {
                            emptyState(icon: "checkmark.circle.fill",
                                       text: "Du hast alle Spiele für den aktuellen Spieltag getippt.")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.openTips) { tip in
                                    OpenGameCard(tip: tip) {
                                        HapticManager.instance.impact(style: .light)
                                        selectedTip = tip
                                        showBettingPopup = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionHeader("Top Spiele")

                    if viewModel.isLoadingTop {
                        loadingRow()
                    } else if viewModel.topMatches.isEmpty {
                        emptyState(icon: "sportscourt", text: "Keine Top-Spiele verfügbar.")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.topMatches, id: \.fixture.id) { match in
                                let isFuture = ["NS", "TBD"].contains(match.fixture.status.short)
                                ApiMatchRow(
                                    match: match,
                                    myTip: isFuture ? nil : viewModel.topMatchTips[match.fixture.id],
                                    showLeague: true
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 50)
                }
            }

            if showBettingPopup, let tip = selectedTip {
                BettingPopupView(
                    isPresented: $showBettingPopup,
                    match: tip.match,
                    communityId: tip.community.id ?? "",
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
        .task { await viewModel.loadData(communities: communityManager.communities) }
        .onChange(of: communityManager.communities) { _, communities in
            Task { await viewModel.loadData(communities: communities) }
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
