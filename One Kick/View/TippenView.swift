//
//  TippenView.swift
//  One Kick
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - ViewModel

struct CommunityRank {
    let rank: Int
    let total: Int
    let points: Int
}

@MainActor
class TippenViewModel: ObservableObject {
    @Published var openTipsPerCommunity: [String: Int] = [:]
    @Published var liveCommunitiesIds: Set<String> = []
    @Published var rankPerCommunity: [String: CommunityRank] = [:]
    @Published var isLoadingRanks = false

    private let api = APIFootballService()
    private let betManager = BetManager()
    private let db = Firestore.firestore()
    private let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]

    func loadOpenTips(communities: [CommunityModel]) async {
        // Phase 1: Bet-IDs aller Communities parallel laden
        var betsPerCommunity: [String: Set<Int>] = [:]
        await withTaskGroup(of: (String, Set<Int>).self) { group in
            for community in communities {
                guard let cid = community.id else { continue }
                group.addTask { (cid, await self.betManager.loadBets(communityId: cid)) }
            }
            for await (cid, ids) in group { betsPerCommunity[cid] = ids }
        }

        // Phase 2: Alle Ligen aller Communities parallel abrufen
        typealias LResult = (cid: String, open: Int, live: Bool)
        var results: [LResult] = []
        await withTaskGroup(of: LResult.self) { group in
            for community in communities {
                guard let cid = community.id, let betIds = betsPerCommunity[cid] else { continue }
                for leagueName in community.activeLeagues {
                    group.addTask {
                        let lid = LeagueMapper.getID(for: leagueName)
                        let max = LeagueMapper.getMaxMatchday(for: leagueName)
                        let res = await self.api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                        let open = res.matches.filter {
                            ["NS", "TBD"].contains($0.fixture.status.short) && !betIds.contains($0.fixture.id)
                        }.count
                        let live = res.matches.contains { self.liveStatuses.contains($0.fixture.status.short) }
                        return (cid: cid, open: open, live: live)
                    }
                }
            }
            for await r in group { results.append(r) }
        }

        // Ergebnisse aggregieren
        var totalOpen: [String: Int] = [:]
        var liveIds   = Set<String>()
        for r in results {
            totalOpen[r.cid, default: 0] += r.open
            if r.live { liveIds.insert(r.cid) }
        }
        for (cid, total) in totalOpen { openTipsPerCommunity[cid] = total }
        for community in communities {
            guard let cid = community.id else { continue }
            if liveIds.contains(cid) { liveCommunitiesIds.insert(cid) } else { liveCommunitiesIds.remove(cid) }
        }
    }

    // MARK: - Rank Calculation

    func loadRanks(communities: [CommunityModel]) async {
        isLoadingRanks = true
        await withTaskGroup(of: (String, CommunityRank?).self) { group in
            for community in communities {
                guard let cid = community.id else { continue }
                group.addTask { (cid, await self.calculateRank(for: community)) }
            }
            for await (cid, rank) in group {
                if let r = rank { rankPerCommunity[cid] = r }
            }
        }
        isLoadingRanks = false
    }

    private func calculateRank(for community: CommunityModel) async -> CommunityRank? {
        guard let myId = Auth.auth().currentUser?.uid,
              let cid  = community.id else { return nil }

        let allBets = await loadAllCommunityBets(communityId: cid)
        if allBets.isEmpty {
            return CommunityRank(rank: 1, total: max(community.members, 1), points: 0)
        }

        let iso = ISO8601DateFormatter()
        let seasonStart = "\(APIConfig.currentSeason)-08-01"
        let toStr = String(iso.string(from: Date()).prefix(10))

        // Identisch zu CommunityPunkteView.loadData() – sequentielle Loops die nachweislich funktionieren
        var currentMatches: [MatchData] = []
        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            let max = LeagueMapper.getMaxMatchday(for: leagueName)
            guard max > 0 else { continue }
            let r = await api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
            currentMatches += r.matches
        }

        var fullSeasonMatches: [MatchData] = []
        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            let m = await api.fetchMatchesByDateRange(for: lid, from: seasonStart, to: toStr)
            fullSeasonMatches += m
        }

        var totalDict: [Int: MatchData] = [:]
        for m in fullSeasonMatches { totalDict[m.fixture.id] = m }
        for m in currentMatches    { totalDict[m.fixture.id] = m }

        var pointsPerUser: [String: Int] = [:]
        for bet in allBets {
            guard let match = totalDict[bet.fixtureId] else { continue }
            let pts = calcPoints(tip: (bet.homeGoals, bet.awayGoals), match: match)
            pointsPerUser[bet.userId, default: 0] += pts
        }

        let myPoints = pointsPerUser[myId] ?? 0
        let rank  = pointsPerUser.values.filter { $0 > myPoints }.count + 1
        let total = max(pointsPerUser.count, 1)
        return CommunityRank(rank: rank, total: total, points: myPoints)
    }

    private func loadAllCommunityBets(communityId: String) async -> [CommunityBet] {
        guard let snap = try? await db.collection("communities")
            .document(communityId).collection("bets").getDocuments()
        else { return [] }
        return snap.documents.compactMap { doc in
            let d = doc.data()
            guard let userId    = d["userId"]    as? String,
                  let fixtureId = d["fixtureId"] as? Int,
                  let home      = d["homeGoals"] as? Int,
                  let away      = d["awayGoals"] as? Int else { return nil }
            return CommunityBet(id: doc.documentID, userId: userId,
                                displayName: d["email"] as? String ?? userId,
                                fixtureId: fixtureId, homeGoals: home, awayGoals: away)
        }
    }

    private func calcPoints(tip: (home: Int, away: Int), match: MatchData) -> Int {
        let live: Set<String> = ["1H","2H","HT","ET","P","LIVE"]
        let done: Set<String> = ["FT","AET","PEN","AWD","WO"]
        let s = match.fixture.status.short
        guard live.contains(s) || done.contains(s) else { return 0 }
        let aH = match.goals.home ?? -1
        let aA = match.goals.away ?? -1
        guard aH >= 0, aA >= 0 else { return 0 }
        var p = 0
        if tip.home == aH { p += 1 }
        if tip.away == aA { p += 1 }
        let td = tip.home - tip.away; let ad = aH - aA
        if td == ad { p += 2 }
        let tr = td > 0 ? 1 : (td < 0 ? -1 : 0)
        let ar = ad > 0 ? 1 : (ad < 0 ? -1 : 0)
        if tr == ar { p += 3 }
        return p
    }
}

// MARK: - Main View

struct TippenView: View {
    @EnvironmentObject var manager: CommunityManager
    @StateObject private var vm = TippenViewModel()
    @State private var showProfileSheet = false
    @State private var selectedLeague: CommunityModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    OneKickHeader(onProfile: {
                        HapticManager.instance.impact(style: .light)
                        showProfileSheet = true
                    })

                    if manager.communities.isEmpty {
                        EmptyStateView()
                    } else {
                        CommunitySelectionView(
                            communities: manager.communities,
                            openTipsPerCommunity: vm.openTipsPerCommunity,
                            liveCommunitiesIds: vm.liveCommunitiesIds,
                            rankPerCommunity: vm.rankPerCommunity,
                            isLoadingRanks: vm.isLoadingRanks
                        ) { community in
                            self.selectedLeague = community
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedLeague) { community in
                CommunityLeaguesView(community: community)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .task {
                await vm.loadOpenTips(communities: manager.communities)
                await vm.loadRanks(communities: manager.communities)
            }
        }
    }
}

// MARK: - Community-Auswahl

struct CommunitySelectionView: View {
    let communities: [CommunityModel]
    let openTipsPerCommunity: [String: Int]
    let liveCommunitiesIds: Set<String>
    let rankPerCommunity: [String: CommunityRank]
    let isLoadingRanks: Bool
    let onSelect: (CommunityModel) -> Void

    @State private var settingsCommunity: CommunityModel?
    @EnvironmentObject var communityManager: CommunityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(communities) { community in
                    HStack(spacing: 0) {
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            onSelect(community)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(community.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("\(community.members) Tipper")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                if let cid = community.id {
                                    if liveCommunitiesIds.contains(cid) {
                                        LiveBadge()
                                    }
                                    if let open = openTipsPerCommunity[cid], open > 0 {
                                        OpenTipsBadge(count: open)
                                    }
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity)

                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.vertical, 10)

                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            settingsCommunity = community
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .background(Color.oneKickDarkGray)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)

                // --- RANGLISTEN-ABSCHNITT ---
                if isLoadingRanks && rankPerCommunity.isEmpty {
                    HStack {
                        ProgressView().tint(.oneKickNeon).scaleEffect(0.8)
                        Text("Rangliste wird geladen …")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                } else if !rankPerCommunity.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Meine Platzierungen")
                            .font(.headline).bold().foregroundColor(.white)

                        VStack(spacing: 0) {
                            ForEach(Array(communities.enumerated()), id: \.element.id) { idx, community in
                                if let cid = community.id, let r = rankPerCommunity[cid] {
                                    HStack(spacing: 12) {
                                        // Medal / Rang-Icon
                                        ZStack {
                                            Circle()
                                                .fill(rankColor(r.rank).opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Text(rankLabel(r.rank))
                                                .font(.system(size: 16))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(community.name)
                                                .font(.subheadline).bold()
                                                .foregroundColor(.white)
                                            Text("Platz \(r.rank) von \(r.total)")
                                                .font(.caption).foregroundColor(.gray)
                                        }

                                        Spacer()

                                        Text("\(r.points) Pkt")
                                            .font(.subheadline).bold()
                                            .foregroundColor(.oneKickNeon)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if idx < communities.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.06))
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                        }
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
        }
        .sheet(item: $settingsCommunity) { community in
            CommunitySettingsView(community: community)
                .environmentObject(communityManager)
        }
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return .orange
        default: return .gray
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "sportscourt")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            Text("Keine Liga")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 10)
            Text("Tritt erst einer Community bei.")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
    }
}
