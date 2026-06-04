//
//  StatistikView.swift
//  One Kick
//

import SwiftUI
import Charts
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Cache-Modelle

struct StatsData: Codable {
    var loadedAt: Date = Date()
    var totalTips: Int = 0
    var evaluatedTips: Int = 0
    var totalPoints: Int = 0
    var avgPointsPerTip: Double = 0
    var correctWinner: Int = 0
    var correctDraw: Int = 0
    var exactScore: Int = 0
    var correctHomeGoals: Int = 0
    var correctAwayGoals: Int = 0
    var correctGoalDiff: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var bestLeague: BestLeagueEntry? = nil
    var leagueBreakdown: [LeagueStatsEntry] = []
    var pointsOverTime: [PointEntry] = []
}

struct BestLeagueEntry: Codable {
    let leagueName: String
    let points: Int
    let tips: Int
}

struct LeagueStatsEntry: Codable, Identifiable {
    var id: String { leagueName }
    let leagueName: String
    let points: Int
    let evaluated: Int
}

struct PointEntry: Codable, Identifiable {
    var id: Double { date.timeIntervalSince1970 }
    let date: Date
    let cumulativePoints: Int
    let matchPoints: Int
}

// MARK: - ViewModel

@MainActor
class StatistikViewModel: ObservableObject {
    @Published var stats: StatsData? = nil
    @Published var isLoading = false
    @Published var isRefreshing = false

    private let api = APIFootballService()
    private let db  = Firestore.firestore()
    private let cacheTTL: TimeInterval = 12 * 3600  // 12h — abgeschlossene Spielergebnisse ändern sich nicht

    private var cacheKey: String {
        let uid = Auth.auth().currentUser?.uid ?? "anon"
        return "statsCache_v2_\(uid)"
    }

    func load(communities: [CommunityModel]) async {
        guard !communities.isEmpty else { return }
        if let cached = loadFromCache(),
           Date().timeIntervalSince(cached.loadedAt) < cacheTTL,
           cached.evaluatedTips > 0 {
            stats = cached
            return
        }
        isLoading = true
        let fresh = await compute(communities: communities)
        if fresh.evaluatedTips > 0 {
            // Normale Berechnung erfolgreich
            stats = fresh
            saveToCache(fresh)
        } else if fresh.totalTips > 0 {
            // Bets vorhanden aber Matches noch nicht über API verfügbar → teilweise cachen
            saveToCache(fresh)
            // Alten Cache behalten falls vorhanden (stabiler als leere Anzeige)
            if let cached = loadFromCache(), cached.evaluatedTips > 0 {
                stats = cached
            } else {
                stats = fresh
            }
        } else if let cached = loadFromCache() {
            // Keine Bets geladen (Netzwerkfehler) → alten Stand zeigen
            stats = cached
        } else {
            stats = fresh
        }
        await BadgeSystem.shared.checkAndUnlock(from: fresh)
        isLoading = false
    }

    func refresh(communities: [CommunityModel]) async {
        isRefreshing = true
        let fresh = await compute(communities: communities)
        stats = fresh
        saveToCache(fresh)
        await BadgeSystem.shared.checkAndUnlock(from: fresh)
        isRefreshing = false
    }

    private func compute(communities: [CommunityModel]) async -> StatsData {
        guard let userId = Auth.auth().currentUser?.uid else { return StatsData() }

        // 1. Alle Tipps aus allen Communities laden (kein Dedup — gleiche Partie aus 2 Communities zählt 2x)
        var allBets: [(fixtureId: Int, tip: (home: Int, away: Int))] = []
        await withTaskGroup(of: [Int: (home: Int, away: Int)].self) { group in
            for community in communities {
                guard let cid = community.id else { continue }
                group.addTask { await self.fetchBets(communityId: cid, userId: userId) }
            }
            for await bets in group {
                for (k, v) in bets { allBets.append((fixtureId: k, tip: v)) }
            }
        }

        guard !allBets.isEmpty else { return StatsData() }

        // 2. Alle Saisonspiele pro Liga laden (1 API-Call pro Liga)
        let allLeagueNames = Set(communities.flatMap { $0.activeLeagues })
        var fixtureMap: [Int: MatchData] = [:]
        var leagueForFixture: [Int: String] = [:]

        let seasonStart = "\(APIConfig.currentSeason)-01-01"
        let seasonEnd   = "\(APIConfig.currentSeason + 1)-06-30"

        await withTaskGroup(of: ([MatchData], String).self) { group in
            for leagueName in allLeagueNames {
                let leagueID = LeagueMapper.getID(for: leagueName)
                guard leagueID != 9999 else { continue }
                let maxMd = LeagueMapper.getMaxMatchday(for: leagueName)
                group.addTask {
                    // Layer 1: Vollständige Saison (eigener Disk-Cache)
                    var matches = await self.api.fetchAllSeasonFixtures(for: leagueID)

                    // Layer 2: Runden-Cache (teilt 30-Tage-Disk-Cache mit CommunityPunkteView)
                    if matches.isEmpty && maxMd > 0 {
                        var roundMatches: [MatchData] = []
                        for n in 1...maxMd {
                            roundMatches += await self.api.fetchMatchesForRoundCached(
                                leagueID, round: "Regular Season - \(n)"
                            )
                        }
                        if !roundMatches.isEmpty { matches = roundMatches }
                    }

                    // Layer 3: Datums-Bereich als letzter Ausweg
                    if matches.isEmpty {
                        matches = await self.api.fetchMatchesByDateRange(
                            for: leagueID, from: seasonStart, to: seasonEnd
                        )
                    }
                    return (matches, leagueName)
                }
            }
            for await (matches, leagueName) in group {
                for match in matches where fixtureMap[match.fixture.id] == nil {
                    fixtureMap[match.fixture.id] = match
                    leagueForFixture[match.fixture.id] = leagueName
                }
            }
        }

        // 3. Statistiken berechnen
        var data = StatsData()
        data.totalTips = allBets.count

        var leagueAcc: [String: (pts: Int, evaluated: Int)] = [:]
        var timeEntries: [(date: Date, pts: Int)] = []
        let iso = ISO8601DateFormatter()
        let finishedStatuses: Set<String> = ["FT", "AET", "PEN", "AWD", "WO"]

        for (fixtureId, tip) in allBets {
            guard let match = fixtureMap[fixtureId],
                  finishedStatuses.contains(match.fixture.status.short),
                  let aH = match.goals.home,
                  let aA = match.goals.away else { continue }

            data.evaluatedTips += 1
            let pts = calcPoints(tip: tip, aH: aH, aA: aA)
            data.totalPoints += pts

            let td = tip.home - tip.away
            let ad = aH - aA
            let tr = td > 0 ? 1 : (td < 0 ? -1 : 0)
            let ar = ad > 0 ? 1 : (ad < 0 ? -1 : 0)

            if tr == ar                        { data.correctWinner += 1 }
            if td == 0 && ad == 0              { data.correctDraw   += 1 }
            if tip.home == aH && tip.away == aA { data.exactScore   += 1 }
            if tip.home == aH                  { data.correctHomeGoals += 1 }
            if tip.away == aA                  { data.correctAwayGoals += 1 }
            if td == ad                        { data.correctGoalDiff  += 1 }

            let league = leagueForFixture[fixtureId] ?? match.league.name
            var entry = leagueAcc[league] ?? (pts: 0, evaluated: 0)
            entry.pts += pts
            entry.evaluated += 1
            leagueAcc[league] = entry

            if let date = iso.date(from: match.fixture.date) {
                timeEntries.append((date: date, pts: pts))
            }
        }

        data.avgPointsPerTip = data.evaluatedTips > 0
            ? Double(data.totalPoints) / Double(data.evaluatedTips) : 0

        data.leagueBreakdown = leagueAcc.map {
            LeagueStatsEntry(leagueName: $0.key, points: $0.value.pts, evaluated: $0.value.evaluated)
        }.sorted {
            let a0 = $0.evaluated > 0 ? Double($0.points) / Double($0.evaluated) : 0
            let a1 = $1.evaluated > 0 ? Double($1.points) / Double($1.evaluated) : 0
            return a0 > a1
        }

        data.bestLeague = data.leagueBreakdown.first.map {
            BestLeagueEntry(leagueName: $0.leagueName, points: $0.points, tips: $0.evaluated)
        }

        // Punkteverlauf aufsteigend nach Datum
        let sorted = timeEntries.sorted { $0.date < $1.date }
        var cum = 0
        data.pointsOverTime = sorted.map {
            cum += $0.pts
            return PointEntry(date: $0.date, cumulativePoints: cum, matchPoints: $0.pts)
        }

        // Streak berechnen
        var streak = 0; var best = 0
        for e in sorted { streak = e.pts > 0 ? streak + 1 : 0; best = max(best, streak) }
        data.bestStreak = best

        var current = 0
        for e in sorted.reversed() {
            if e.pts > 0 { current += 1 } else { break }
        }
        data.currentStreak = current
        data.loadedAt = Date()
        return data
    }

    private func calcPoints(tip: (home: Int, away: Int), aH: Int, aA: Int) -> Int {
        var pts = 0
        if tip.home == aH { pts += 1 }
        if tip.away == aA { pts += 1 }
        let td = tip.home - tip.away; let ad = aH - aA
        if td == ad { pts += 2 }
        let tr = td > 0 ? 1 : (td < 0 ? -1 : 0)
        let ar = ad > 0 ? 1 : (ad < 0 ? -1 : 0)
        if tr == ar { pts += 3 }
        return pts
    }

    private func fetchBets(communityId: String, userId: String) async -> [Int: (home: Int, away: Int)] {
        do {
            let snapshot = try await db.collection("communities")
                .document(communityId).collection("bets")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            var result: [Int: (home: Int, away: Int)] = [:]
            for doc in snapshot.documents {
                let d = doc.data()
                if let fId = d["fixtureId"] as? Int,
                   let h = d["homeGoals"] as? Int,
                   let a = d["awayGoals"] as? Int {
                    result[fId] = (home: h, away: a)
                }
            }
            return result
        } catch { return [:] }
    }

    private func saveToCache(_ data: StatsData) {
        if let enc = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(enc, forKey: cacheKey)
        }
    }

    private func loadFromCache() -> StatsData? {
        guard let d = UserDefaults.standard.data(forKey: cacheKey),
              let dec = try? JSONDecoder().decode(StatsData.self, from: d) else { return nil }
        return dec
    }
}

// MARK: - StatistikView

struct StatistikView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @StateObject private var viewModel = StatistikViewModel()
    @State private var showProfileSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    OneKickHeader(onProfile: {
                        HapticManager.instance.impact(style: .light)
                        showProfileSheet = true
                    })

                    if viewModel.isLoading {
                        loadingView
                    } else if let stats = viewModel.stats, stats.evaluatedTips > 0 {
                        ScrollView {
                            LazyVStack(spacing: 18) {
                                summaryCard(stats)
                                praezisionSection(stats)
                                streakCard(stats)
                                if !stats.leagueBreakdown.isEmpty {
                                    ligaSection(stats)
                                }
                                if stats.pointsOverTime.count >= 2 {
                                    chartSection(stats)
                                }
                                Spacer(minLength: 80)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        .refreshable { await viewModel.refresh(communities: communityManager.communities) }
                    } else {
                        emptyState
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .task { await viewModel.load(communities: communityManager.communities) }
            .onChange(of: communityManager.communities) { _, communities in
                guard !communities.isEmpty else { return }
                Task { await viewModel.load(communities: communities) }
            }
        }
    }

    // MARK: - Summary

    private func summaryCard(_ s: StatsData) -> some View {
        HStack(spacing: 0) {
            summaryCol(value: "\(s.totalPoints)", label: LanguageManager.shared.t("stats.totalPoints"), color: .oneKickNeon)
            Divider().background(Color.white.opacity(0.08)).frame(height: 50)
            summaryCol(value: String(format: "%.1f", s.avgPointsPerTip), label: LanguageManager.shared.t("stats.perGame"), sublabel: LanguageManager.shared.t("stats.maxPts"), color: .white)
            Divider().background(Color.white.opacity(0.08)).frame(height: 50)
            summaryCol(value: "\(s.evaluatedTips)", label: LanguageManager.shared.t("stats.evaluated"), sublabel: LanguageManager.shared.t("stats.tipsEvaluated"), color: .gray)
        }
        .padding(.vertical, 18)
        .background(Color.oneKickDarkGray)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.oneKickNeon.opacity(0.3), lineWidth: 1))
    }

    private func summaryCol(value: String, label: String, sublabel: String? = nil, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 26, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            if let sub = sublabel {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Präzisions-Grid

    private func praezisionSection(_ s: StatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(LanguageManager.shared.t("stats.precision"))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                praezisionCard(
                    title: LanguageManager.shared.t("stats.correctTrend"),
                    count: s.correctWinner,
                    total: s.evaluatedTips,
                    color: .oneKickNeon
                )
                praezisionCard(
                    title: LanguageManager.shared.t("stats.draw"),
                    count: s.correctDraw,
                    total: s.evaluatedTips,
                    color: Color(red: 0.6, green: 0.6, blue: 1.0)
                )
                praezisionCard(
                    title: LanguageManager.shared.t("stats.exactScore"),
                    count: s.exactScore,
                    total: s.evaluatedTips,
                    color: Color(red: 1.0, green: 0.7, blue: 0.2)
                )
                praezisionCard(
                    title: LanguageManager.shared.t("stats.goalRatio"),
                    count: s.correctGoalDiff,
                    total: s.evaluatedTips,
                    color: Color(red: 0.35, green: 0.85, blue: 0.55)
                )
                praezisionCard(
                    title: LanguageManager.shared.t("stats.homeGoals"),
                    count: s.correctHomeGoals,
                    total: s.evaluatedTips,
                    color: Color(red: 0.4, green: 0.8, blue: 1.0)
                )
                praezisionCard(
                    title: LanguageManager.shared.t("stats.awayGoals"),
                    count: s.correctAwayGoals,
                    total: s.evaluatedTips,
                    color: Color(red: 1.0, green: 0.45, blue: 0.45)
                )
            }
        }
    }

    private func praezisionCard(title: String, count: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(color)
            }

            Text("\(count) / \(total)")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * pct), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    // MARK: - Streak

    private func streakCard(_ s: StatsData) -> some View {
        HStack(spacing: 0) {
            streakCol(
                value: "\(s.currentStreak)",
                label: LanguageManager.shared.t("stats.currentStreak"),
                sublabel: LanguageManager.shared.t("stats.consecutivePts"),
                icon: "flame.fill",
                color: s.currentStreak > 0 ? .orange : .gray
            )
            Divider().background(Color.white.opacity(0.08)).frame(height: 50)
            streakCol(
                value: "\(s.bestStreak)",
                label: LanguageManager.shared.t("stats.bestStreak"),
                sublabel: LanguageManager.shared.t("stats.longestStreak"),
                icon: "star.fill",
                color: .oneKickNeon
            )
        }
        .padding(.vertical, 16)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func streakCol(value: String, label: String, sublabel: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            Text(sublabel)
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Liga-Breakdown

    private func ligaSection(_ s: StatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(LanguageManager.shared.t("stats.top5Leagues"))

            VStack(spacing: 0) {
                let top5 = Array(s.leagueBreakdown.prefix(5))
                ForEach(Array(top5.enumerated()), id: \.element.id) { idx, entry in
                    let avg = entry.evaluated > 0 ? Double(entry.points) / Double(entry.evaluated) : 0.0
                    HStack(spacing: 12) {
                        Text("#\(idx + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(idx == 0 ? .oneKickNeon : .gray)
                            .frame(width: 28)

                        Text(entry.leagueName)
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f Ø/Spiel", avg))
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(idx == 0 ? .oneKickNeon : .white)
                            Text("\(entry.evaluated) Spiele")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if idx < top5.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - Chart

    private func chartSection(_ s: StatsData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Punkteverlauf")

            Chart(s.pointsOverTime) { entry in
                LineMark(
                    x: .value("Datum", entry.date),
                    y: .value("Punkte", entry.cumulativePoints)
                )
                .foregroundStyle(Color.oneKickNeon)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Datum", entry.date),
                    y: .value("Punkte", entry.cumulativePoints)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.oneKickNeon.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisValueLabel()
                        .foregroundStyle(Color.gray)
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.06))
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray)
            .tracking(0.5)
            .padding(.leading, 4)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.oneKickNeon).scaleEffect(1.2)
            Text("Statistiken werden berechnet…")
                .font(.caption).foregroundColor(.gray)
            Text("Das kann beim ersten Mal etwas länger dauern.")
                .font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.4))
            Text("Noch keine Statistiken")
                .font(.headline).bold().foregroundColor(.white)
            Text("Sobald du deine ersten Tipps abgegeben hast und Spiele bewertet wurden, erscheinen hier deine Statistiken.")
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}
