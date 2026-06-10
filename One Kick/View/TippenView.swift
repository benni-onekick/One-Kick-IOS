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

    // Rang-Cache: Ergebnisse 10 Minuten wiederverwenden, um teure API-Calls zu vermeiden
    private var rankCache: [String: (rank: CommunityRank, date: Date)] = [:]
    private let rankCacheTTL: TimeInterval = 10 * 60

    init() {
        // Letzten bekannten Stand sofort anzeigen – Update kommt im Hintergrund
        if let data = UserDefaults.standard.data(forKey: "openTipsCache"),
           let cached = try? JSONDecoder().decode([String: Int].self, from: data) {
            openTipsPerCommunity = cached
        }
    }

    // MARK: - Offene Tipps (nutzt roundCache → schnell, kein API-Limit-Problem)

    private var isLoadingOpenTips = false

    func loadOpenTips(communities: [CommunityModel]) async {
        guard !communities.isEmpty, !isLoadingOpenTips else { return }
        isLoadingOpenTips = true
        defer { isLoadingOpenTips = false }

        // Bets laden
        var betsPerCommunity: [String: Set<Int>] = [:]
        await withTaskGroup(of: (String, Set<Int>).self) { group in
            for community in communities {
                guard let cid = community.id else { continue }
                group.addTask { (cid, await self.betManager.loadBets(communityId: cid)) }
            }
            for await (cid, ids) in group { betsPerCommunity[cid] = ids }
        }

        // Bonus-Antworten des eingeloggten Users laden (parallel, schnelle Firestore-Reads)
        let bonusManager = BonusBetManager()
        var bonusAnswersPerCommunity: [String: [String: String]] = [:]
        if let myId = Auth.auth().currentUser?.uid {
            await withTaskGroup(of: (String, [String: String]).self) { group in
                for community in communities {
                    guard let cid = community.id else { continue }
                    group.addTask { (cid, await bonusManager.loadBonusAnswers(communityId: cid, userId: myId)) }
                }
                for await (cid, answers) in group { bonusAnswersPerCommunity[cid] = answers }
            }
        }

        let now = Date()
        let isoFmt = ISO8601DateFormatter()

        // Ligen sequenziell laden – In-Flight-Dedup in fetchCurrentAndUpcomingMatches sorgt dafür,
        // dass TippenView StartseiteViews bereits laufende Tasks joined (zero extra API-Calls).
        // Parallel würde Ligen vor StartseiteView starten → Rate-Limit erschöpfen → Punkte kaputt.
        var leagueMatchCache: [Int: [MatchData]] = [:]
        var allLeagueIds = Set<Int>()
        for community in communities {
            for leagueName in community.activeLeagues {
                allLeagueIds.insert(LeagueMapper.getID(for: leagueName))
            }
        }
        for lid in allLeagueIds where lid != 9999 {
            leagueMatchCache[lid] = await api.fetchCurrentAndUpcomingMatches(for: lid)
        }

        typealias LResult = (cid: String, open: Int, live: Bool)
        var results: [LResult] = []
        for community in communities {
            guard let cid = community.id, let betIds = betsPerCommunity[cid] else { continue }
            var totalOpen = 0
            var isLive    = false
            for leagueName in community.activeLeagues {
                let lid        = LeagueMapper.getID(for: leagueName)
                let allMatches = leagueMatchCache[lid] ?? []
                let maxMd      = LeagueMapper.getMaxMatchday(for: leagueName)

                // Nur offene Matches des aktuellen Spieltags zählen.
                // Ersten NS/TBD-Match nehmen → dessen Runde = aktueller Spieltag.
                let upcoming     = allMatches.filter { ["NS", "TBD"].contains($0.fixture.status.short) }
                let currentRound = upcoming.first?.league.round
                let forCount: [MatchData]
                if let round = currentRound {
                    let filtered = upcoming.filter { $0.league.round == round }
                    // Fallback: wenn gefiltertes Ergebnis leer (z.B. Liga zwischen Runden),
                    // alle verfügbaren NS/TBD-Matches zählen
                    forCount = filtered.isEmpty ? upcoming : filtered
                } else {
                    forCount = upcoming
                }
                let matches = allMatches  // für Live-Prüfung + Bonus-Lock weiterhin alle verwenden
                totalOpen += forCount.filter { !betIds.contains($0.fixture.id) }.count
                if !isLive {
                    isLive = matches.contains { match in
                        if liveStatuses.contains(match.fixture.status.short) { return true }
                        if let kickoff = isoFmt.date(from: match.fixture.date) {
                            let min = now.timeIntervalSince(kickoff) / 60
                            return min > 0 && min < 120
                        }
                        return false
                    }
                }
                if !matches.isEmpty && !bonusLockedForLeague(matches: matches) {
                    let activeCats = community.activeBonusCats(for: leagueName)
                    let cats = bonusCategoriesForLeague(leagueName, activeCategorySet: activeCats)
                    let answers = bonusAnswersPerCommunity[cid] ?? [:]
                    totalOpen += cats.filter { (answers["\(leagueName)|\($0)"] ?? "").isEmpty }.count
                }
            }
            results.append((cid: cid, open: totalOpen, live: isLive))
        }

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
        if let data = try? JSONEncoder().encode(openTipsPerCommunity) {
            UserDefaults.standard.set(data, forKey: "openTipsCache")
        }

        // Erinnerungen planen — nur wenn Nutzer mindestens eine Zeit ausgewählt hat
        let selectedMinutes = ReminderInterval.load()
        if !selectedMinutes.isEmpty {
            var untippedMap: [Int: (match: MatchData, communityIds: [String])] = [:]
            for community in communities {
                guard let cid = community.id, let betIds = betsPerCommunity[cid] else { continue }
                for leagueName in community.activeLeagues {
                    let lid = LeagueMapper.getID(for: leagueName)
                    for match in leagueMatchCache[lid] ?? []
                    where ["NS", "TBD"].contains(match.fixture.status.short)
                       && !betIds.contains(match.fixture.id) {
                        if var existing = untippedMap[match.fixture.id] {
                            existing.communityIds.append(cid)
                            untippedMap[match.fixture.id] = existing
                        } else {
                            untippedMap[match.fixture.id] = (match, [cid])
                        }
                    }
                }
            }
            let entries = untippedMap.values.map {
                UntippedMatchEntry(match: $0.match, communityIds: $0.communityIds)
            }
            NotificationManager.shared.scheduleReminders(
                untippedMatches: entries, selectedMinutes: selectedMinutes
            )
        }
    }

    func invalidateRank(for communityId: String) {
        rankCache.removeValue(forKey: communityId)
    }

    /// Sofortiges lokales Update nach Tipp-Abgabe — kein API-Call nötig
    func decrementOpenTip(communityId: String) {
        let current = openTipsPerCommunity[communityId] ?? 0
        openTipsPerCommunity[communityId] = max(0, current - 1)
        if let data = try? JSONEncoder().encode(openTipsPerCommunity) {
            UserDefaults.standard.set(data, forKey: "openTipsCache")
        }
    }

    // MARK: - Rang (gecacht, läuft im Hintergrund)

    func loadRanks(communities: [CommunityModel], forceRefresh: Bool = false) async {
        isLoadingRanks = true
        defer { isLoadingRanks = false }

        // Sequenziell: verhindert parallele API-Calls über alle Communities × alle Ligen
        for community in communities {
            guard let cid = community.id else { continue }
            if !forceRefresh,
               let cached = rankCache[cid],
               Date().timeIntervalSince(cached.date) < rankCacheTTL {
                rankPerCommunity[cid] = cached.rank
                continue
            }
            if let rank = await calculateRank(for: community) {
                rankPerCommunity[cid] = rank
                rankCache[cid] = (rank, Date())
            }
        }
    }

    /// Rang-Berechnung: Holt alle Spiele der letzten 14 Tage + nächste 8 Tage per Datumsbereich.
    /// Damit werden auch vergangene Spieltage korrekt erfasst (roundCache liefert sonst nur die nächste Runde).
    private func calculateRank(for community: CommunityModel) async -> CommunityRank? {
        guard let myId = Auth.auth().currentUser?.uid,
              let cid  = community.id else { return nil }

        // Leaderboard-Cache nutzen: kein API-Call wenn CommunityPunkteViewModel schon berechnet hat
        if let rankings = LeaderboardCache.shared.get(for: cid) {
            let myEntry = rankings.first(where: { $0.id == myId })
            let myPoints = myEntry?.totalPoints ?? 0
            let rank = rankings.filter { $0.totalPoints > myPoints }.count + 1
            return CommunityRank(rank: rank, total: max(rankings.count, 1), points: myPoints)
        }

        // Fallback: selbst berechnen (nutzt Disk-Cache → kein echter API-Call wenn gecacht)
        let allBets = await loadAllCommunityBets(communityId: cid)
        if allBets.isEmpty {
            return CommunityRank(rank: 1, total: max(community.members, 1), points: 0)
        }

        // fetchAllSeasonFixtures: permanenter Disk-Cache, teilt Cache mit loadGesamtData.
        // fetchMatchesByDateRange bricht bei Rate-Limiting nach Seite 1 ab → falsche Punkte.
        var matchDict: [Int: MatchData] = [:]
        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            guard lid != 9999 else { continue }
            let matches = await api.fetchAllSeasonFixtures(for: lid)
            for m in matches { matchDict[m.fixture.id] = m }
        }

        // Kein Ergebnis → API rate-limitiert; zeige stale Cache statt "Nicht verfügbar"
        if matchDict.isEmpty {
            if let stale = LeaderboardCache.shared.get(for: cid, staleOkay: true) {
                let myEntry = stale.first(where: { $0.id == myId })
                let myPoints = myEntry?.totalPoints ?? 0
                let rank = stale.filter { $0.totalPoints > myPoints }.count + 1
                return CommunityRank(rank: rank, total: max(stale.count, 1), points: myPoints)
            }
            return nil
        }

        var pointsPerUser: [String: Int] = [:]
        for bet in allBets {
            guard let match = matchDict[bet.fixtureId] else { continue }
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

    private func bonusLockedForLeague(matches: [MatchData]) -> Bool {
        if matches.isEmpty { return true }
        for match in matches {
            if !["NS", "TBD"].contains(match.fixture.status.short) { return true }
            if let round = match.league.round {
                if isPlayoffOrRelegationRound(round) { return true }
                let num = round.components(separatedBy: " ").compactMap { Int($0) }.last ?? 0
                if num > 1 { return true }
            } else {
                return true
            }
        }
        return false
    }

    private func isPlayoffOrRelegationRound(_ round: String) -> Bool {
        let keywords = ["relegation", "playoff", "play-off", "championship", "barrage",
                        "qualification", "qualifying", "promotion", "playout", "maintien",
                        "final"]
        return keywords.contains { round.lowercased().contains($0) }
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
    @EnvironmentObject var lm: LanguageManager
    @StateObject private var vm = TippenViewModel()
    @StateObject private var globalVM = GlobalCommunityViewModel()
    @State private var showProfileSheet = false
    @State private var showJoinSheet = false
    @State private var showCommunityMenu = false
    @State private var selectedLeague: CommunityModel?
    @State private var showGlobalCommunityDetail = false
    @State private var lastRefreshAt: Date = .distantPast

    private func refreshOpenTips() {
        // Offene Tipps sofort aktualisieren wenn > 10 Sek seit letztem Refresh
        guard Date().timeIntervalSince(lastRefreshAt) > 10 else { return }
        lastRefreshAt = .now
        Task { await vm.loadOpenTips(communities: manager.communities) }
    }

    private func refreshAll() {
        lastRefreshAt = .now
        Task {
            await vm.loadOpenTips(communities: manager.communities)
            Task { await vm.loadRanks(communities: manager.communities) }
        }
    }

    private func handleTipSaved(_ notification: Notification) {
        if let cid = notification.userInfo?["communityId"] as? String {
            vm.decrementOpenTip(communityId: cid)
        }
        lastRefreshAt = .distantPast
    }

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
                        EmptyStateView(
                            onJoin: { showJoinSheet = true },
                            onStart: { showCommunityMenu = true }
                        )
                    } else {
                        CommunitySelectionView(
                            communities: manager.communities,
                            openTipsPerCommunity: vm.openTipsPerCommunity,
                            liveCommunitiesIds: vm.liveCommunitiesIds,
                            rankPerCommunity: vm.rankPerCommunity,
                            isLoadingRanks: vm.isLoadingRanks,
                            onJoin: { showJoinSheet = true },
                            onSelect: { self.selectedLeague = $0 },
                            globalLeagueCount: globalVM.selectedLeagues.count,
                            onGlobalCommunity: { showGlobalCommunityDetail = true }
                        )
                    }
                }
            }
            .navigationDestination(item: $selectedLeague) { community in
                CommunityLeaguesView(community: community)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinCommunitySheet().environmentObject(manager).environmentObject(lm)
            }
            .sheet(isPresented: $showCommunityMenu) {
                CommunityStartMenu().environmentObject(manager)
            }
            .sheet(isPresented: $showGlobalCommunityDetail) {
                GlobalCommunityTippenDetailView(vm: globalVM)
                    .environmentObject(manager)
            }
            .task {
                await vm.loadOpenTips(communities: manager.communities)
                Task { await vm.loadRanks(communities: manager.communities) }
                await globalVM.load()
            }
            .onAppear { refreshOpenTips() }
            .onChange(of: manager.communities) { _, communities in
                // Communities werden async geladen – sobald sie bereit sind sofort laden
                guard !communities.isEmpty else { return }
                lastRefreshAt = .distantPast
                Task {
                    await vm.loadOpenTips(communities: communities)
                    Task { await vm.loadRanks(communities: communities) }
                }
            }
            .onChange(of: manager.appBecameActive) { _, _ in refreshAll() }
            .onReceive(NotificationCenter.default.publisher(for: .tipSaved)) { handleTipSaved($0) }
            .onReceive(NotificationCenter.default.publisher(for: .leaderboardUpdated)) { notification in
                guard let cid = notification.userInfo?["communityId"] as? String else { return }
                vm.invalidateRank(for: cid)
                Task { await vm.loadRanks(communities: manager.communities, forceRefresh: false) }
            }
            .task(id: "live-rank-refresh") {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { break }
                    guard !vm.liveCommunitiesIds.isEmpty else { continue }
                    await vm.loadRanks(communities: manager.communities, forceRefresh: true)
                }
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let tipSaved         = Notification.Name("tipSaved")
    static let openTippenTab    = Notification.Name("openTippenTab")
    static let leaderboardUpdated = Notification.Name("leaderboardUpdated")
}

// MARK: - Community-Auswahl

struct CommunitySelectionView: View {
    @EnvironmentObject var lm: LanguageManager
    let communities: [CommunityModel]
    let openTipsPerCommunity: [String: Int]
    let liveCommunitiesIds: Set<String>
    let rankPerCommunity: [String: CommunityRank]
    let isLoadingRanks: Bool
    let onJoin: () -> Void
    let onSelect: (CommunityModel) -> Void
    var globalLeagueCount: Int = 0
    var onGlobalCommunity: () -> Void = {}

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
                                AvatarView(displayName: community.name,
                                           photoBase64: community.photoBase64,
                                           size: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(community.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("\(community.members) \(lm.t("community.tipper"))")
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

            if globalLeagueCount > 0 {
                Button(action: {
                    HapticManager.instance.impact(style: .light)
                    onGlobalCommunity()
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.oneKickNeon.opacity(0.15)).frame(width: 44, height: 44)
                            Image(systemName: "globe.europe.africa.fill")
                                .foregroundColor(.oneKickNeon).font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Globale Community")
                                .font(.headline).foregroundColor(.white)
                            Text("\(globalLeagueCount) Wettbewerb\(globalLeagueCount == 1 ? "" : "e")")
                                .font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color.oneKickDarkGray)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.oneKickNeon.opacity(0.25), lineWidth: 1))
                .padding(.horizontal)
            }

                // --- RANGLISTEN-ABSCHNITT ---
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(lm.t("community.myRankings"))
                            .font(.headline).bold().foregroundColor(.white)
                        if isLoadingRanks {
                            ProgressView().tint(.oneKickNeon).scaleEffect(0.7)
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(communities.enumerated()), id: \.element.id) { idx, community in
                            if let cid = community.id {
                                let r = rankPerCommunity[cid]
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill((r != nil ? rankColor(r!.rank) : Color.gray).opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        if let r = r {
                                            Text(rankLabel(r.rank))
                                                .font(.system(size: 16))
                                        } else {
                                            Text("—")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(community.name)
                                            .font(.subheadline).bold()
                                            .foregroundColor(.white)
                                        if let r = r {
                                            Text("\(lm.t("general.rank")) \(r.rank) \(lm.t("general.of")) \(community.members)")
                                                .font(.caption).foregroundColor(.gray)
                                        } else {
                                            Text(isLoadingRanks ? lm.t("general.loading") : lm.t("general.notAvailable"))
                                                .font(.caption).foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()

                                    if let r = r {
                                        Text("\(r.points) \(lm.t("general.points"))")
                                            .font(.subheadline).bold()
                                            .foregroundColor(.oneKickNeon)
                                    }
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

                Button(action: {
                    HapticManager.instance.impact(style: .light)
                    onJoin()
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text(lm.t("community.joinCode"))
                            .font(.subheadline).bold()
                    }
                    .foregroundColor(.oneKickNeon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.oneKickNeon.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.oneKickNeon.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
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
    @EnvironmentObject var lm: LanguageManager
    let onJoin: () -> Void
    let onStart: () -> Void
    @State private var showGlobalSelection = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sportscourt")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            Text(lm.t("community.noLeague"))
                .font(.headline)
                .foregroundColor(.white)
            Text(lm.t("home.joinLeague"))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                HapticManager.instance.impact(style: .medium)
                onStart()
            }) {
                Text(lm.t("action.start"))
                    .font(.subheadline).bold().foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.oneKickNeon)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            Button(action: {
                HapticManager.instance.impact(style: .medium)
                onJoin()
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text(lm.t("community.joinCode"))
                        .font(.subheadline).bold()
                }
                .foregroundColor(.oneKickNeon)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.oneKickNeon.opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oneKickNeon.opacity(0.4), lineWidth: 1))
            }
            Button(action: {
                HapticManager.instance.impact(style: .medium)
                showGlobalSelection = true
            }) {
                HStack {
                    Image(systemName: "globe.europe.africa.fill")
                    Text("Globaler Community beitreten")
                        .font(.subheadline).bold()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.oneKickDarkGray)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .sheet(isPresented: $showGlobalSelection) {
                GlobalCommunityLeagueSelectionView()
            }
            Spacer()
        }
    }
}

// MARK: - Beitreten per Code

struct JoinCommunitySheet: View {
    var prefillCode: String = ""

    @EnvironmentObject var manager: CommunityManager
    @EnvironmentObject var lm: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    init(prefillCode: String = "") {
        self.prefillCode = prefillCode
        _code = State(initialValue: prefillCode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.oneKickNeon)

                    Text(lm.t("community.joinCode"))
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    Text("Gib den Einladungscode der Tipprunde ein.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    TextField("z. B. ABCD-1234", text: $code)
                        .font(.title3.monospaced())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(success ? Color.green : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 32)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button(action: join) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else if success {
                                Label("Beigetreten!", systemImage: "checkmark")
                                    .font(.headline).bold()
                            } else {
                                Text("Beitreten")
                                    .font(.headline).bold()
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(success ? Color.green : Color.oneKickNeon)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || success)

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func join() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await manager.joinCommunity(code: code)
                isLoading = false
                success = true
                HapticManager.instance.notification(type: .success)
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                HapticManager.instance.notification(type: .error)
            }
        }
    }
}
