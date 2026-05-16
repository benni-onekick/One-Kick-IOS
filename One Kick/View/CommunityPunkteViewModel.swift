//
//  CommunityPunkteViewModel.swift
//  One Kick
//
//  ViewModel für Leaderboard, Spielwoche und Bonus-Tab.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - ViewModel

@MainActor
class CommunityPunkteViewModel: ObservableObject {
    @Published var totalLeaderboard:    [UserPointsEntry]  = []
    @Published var liveLeagues:         Set<String>        = []
    @Published var isLoading           = false

    // Spielwoche-Tab
    @Published var spielwocheLeaderboard: [UserPointsEntry]    = []
    @Published var currentWeekLabel:      String               = ""
    @Published var weekMatchesByLeague:   [String: [MatchData]] = [:]

    // Gesamt-Tab
    @Published var isLoadingGesamt     = false

    // Bonus-Tab
    @Published var bonusEntries:        [UserBonusEntry]   = []
    @Published var bonusLockedLeagues:  Set<String>        = []
    @Published var isLoadingBonus      = false

    private let db  = Firestore.firestore()
    private let api = APIFootballService()
    let community: CommunityModel

    // Cache für Wochen-Navigation ohne erneutes Bets-Laden
    private var cachedBetsByUser:             [String: [CommunityBet]] = [:]
    private var cachedLeagueIdToDisplayName:  [Int: String]            = [:]
    private var cachedMemberNames:            [String: String]         = [:]

    @Published var isLoadingSpielwoche = false

    init(community: CommunityModel) {
        self.community = community
    }

    // MARK: Bonus-Daten laden

    func loadBonusData() async {
        guard let communityId = community.id else { return }
        isLoadingBonus = true

        var locked = Set<String>()
        await withTaskGroup(of: (String, Bool).self) { group in
            for leagueName in community.activeLeagues {
                group.addTask {
                    let lid = LeagueMapper.getID(for: leagueName)
                    let max = LeagueMapper.getMaxMatchday(for: leagueName)
                    let r   = await self.api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                    var isLocked = r.matchday > 1 ||
                        r.matches.contains { !["NS", "TBD"].contains($0.fixture.status.short) }
                    if !isLocked && max == 0 {
                        let iso = ISO8601DateFormatter()
                        let from = String(iso.string(from: Date().addingTimeInterval(-90 * 86400)).prefix(10))
                        let to   = String(iso.string(from: Date()).prefix(10))
                        let recent = await self.api.fetchMatchesByDateRange(for: lid, from: from, to: to)
                        let done: Set<String> = ["FT", "AET", "PEN", "AWD", "WO", "1H", "2H", "HT", "ET", "P", "LIVE"]
                        if recent.contains(where: { done.contains($0.fixture.status.short) }) {
                            isLocked = true
                        }
                    }
                    return (leagueName, isLocked)
                }
            }
            for await (name, isLocked) in group {
                if isLocked { locked.insert(name) }
            }
        }
        bonusLockedLeagues = locked

        if let snap = try? await db.collection("communities")
            .document(communityId).collection("bonusBets").getDocuments() {
            bonusEntries = snap.documents.compactMap { doc in
                let d = doc.data()
                guard let answers = d["answers"] as? [String: String] else { return nil }
                let raw  = d["email"] as? String ?? doc.documentID
                let name = raw.components(separatedBy: "@").first.map {
                    $0.prefix(1).uppercased() + $0.dropFirst()
                } ?? raw
                return UserBonusEntry(id: doc.documentID, displayName: String(name), answers: answers)
            }.sorted { $0.displayName < $1.displayName }
        }

        isLoadingBonus = false
    }

    // MARK: Ligen-Rankings

    func leagueRanking(for leagueName: String) -> [UserPointsEntry] {
        totalLeaderboard.compactMap { entry in
            guard let lp = entry.leagueBreakdown.first(where: { $0.leagueName == leagueName })
            else { return nil }
            return UserPointsEntry(id: entry.id, displayName: entry.displayName,
                                   points: lp.points, leagueBreakdown: [lp])
        }.sorted { $0.points > $1.points }
    }

    func leagueLeader(for leagueName: String) -> (name: String, points: Int)? {
        leagueRanking(for: leagueName).first.map { ($0.displayName, $0.points) }
    }

    // MARK: Load

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        guard let communityId = community.id else { return }

        // Member-Namen + Bets parallel laden
        async let memberNamesTask  = loadMemberDisplayNames()
        async let allBetsTask      = loadAllBets(communityId: communityId)
        let (memberNames, allBets) = await (memberNamesTask, allBetsTask)

        var leagueIdToDisplayName: [Int: String] = [:]
        for name in community.activeLeagues {
            leagueIdToDisplayName[LeagueMapper.getID(for: name)] = name
        }

        var betsByUser: [String: [CommunityBet]] = [:]
        for bet in allBets { betsByUser[bet.userId, default: []].append(bet) }

        cachedBetsByUser            = betsByUser
        cachedLeagueIdToDisplayName = leagueIdToDisplayName
        cachedMemberNames           = memberNames

        let iso = ISO8601DateFormatter()
        let toStr = String(iso.string(from: Date()).prefix(10))

        let isoCalendar = Calendar(identifier: .iso8601)
        var weekFromStr = toStr
        var weekToStr   = toStr
        if let interval = isoCalendar.dateInterval(of: .weekOfYear, for: Date()) {
            weekFromStr = String(iso.string(from: interval.start).prefix(10))
            let sunday = interval.start.addingTimeInterval(7 * 86400 - 1)
            weekToStr  = String(iso.string(from: sunday).prefix(10))
            let df = DateFormatter()
            df.locale = Locale(identifier: "de_DE")
            df.dateFormat = "d. MMM"
            currentWeekLabel = "\(df.string(from: interval.start)) – \(df.string(from: sunday))"
        }

        // Parallel: aktuelle Runde + Wochenspiele (wenige Calls, schnell)
        var currentMatches: [MatchData] = []
        var weekMatches:    [MatchData] = []

        await withTaskGroup(of: (tag: String, matches: [MatchData]).self) { group in
            for leagueName in community.activeLeagues {
                let lid = LeagueMapper.getID(for: leagueName)
                let max = LeagueMapper.getMaxMatchday(for: leagueName)
                if max > 0 {
                    group.addTask {
                        let r = await self.api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                        return ("current", r.matches)
                    }
                }
                group.addTask {
                    let m = await self.api.fetchMatchesByDateRange(for: lid, from: weekFromStr, to: weekToStr)
                    return ("week", m)
                }
            }
            for await r in group {
                if r.tag == "current" { currentMatches += r.matches }
                else                  { weekMatches    += r.matches }
            }
        }

        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        liveLeagues = Set(currentMatches
            .filter { liveStatuses.contains($0.fixture.status.short) }
            .map { leagueIdToDisplayName[$0.league.id] ?? $0.league.name }
        )

        var weekDict: [Int: MatchData] = [:]
        for m in weekMatches   { weekDict[m.fixture.id] = m }
        for m in currentMatches where weekDict[m.fixture.id] != nil { weekDict[m.fixture.id] = m }

        var wml: [String: [MatchData]] = [:]
        for m in weekDict.values {
            let lName = leagueIdToDisplayName[m.league.id] ?? m.league.name
            wml[lName, default: []].append(m)
        }
        weekMatchesByLeague = wml.mapValues { $0.sorted { $0.fixture.date < $1.fixture.date } }

        spielwocheLeaderboard = buildSpielwocheLeaderboard(
            betsByUser: betsByUser, matchDict: weekDict,
            nameOverride: leagueIdToDisplayName,
            memberNames: memberNames
        ).sorted { $0.points > $1.points }

        // Gesamt-Leaderboard: erst alle Member bei 0 zeigen, dann echte Punkte laden
        totalLeaderboard = memberNames.map { uid, name in
            UserPointsEntry(id: uid, displayName: name, points: 0, leagueBreakdown: [])
        }.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }

        Task { await loadGesamtData() }
    }

    // Lädt Saisonspiele sequenziell um API-Rate-Limits zu vermeiden
    func loadGesamtData() async {
        guard !cachedBetsByUser.isEmpty else { return }
        isLoadingGesamt = true
        defer { isLoadingGesamt = false }

        let iso = ISO8601DateFormatter()
        let seasonStart = "\(APIConfig.currentSeason)-08-01"
        let toStr = String(iso.string(from: Date()).prefix(10))

        var fullSeasonMatches: [MatchData] = []
        var currentMatches:    [MatchData] = []

        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            let m = await api.fetchMatchesByDateRange(for: lid, from: seasonStart, to: toStr)
            fullSeasonMatches += m

            let max = LeagueMapper.getMaxMatchday(for: leagueName)
            if max > 0 {
                let r = await api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                currentMatches += r.matches
            }
        }

        var totalDict: [Int: MatchData] = [:]
        for m in fullSeasonMatches { totalDict[m.fixture.id] = m }
        for m in currentMatches    { totalDict[m.fixture.id] = m }

        totalLeaderboard = buildLeaderboard(
            betsByUser: cachedBetsByUser, matchDict: totalDict,
            nameOverride: cachedLeagueIdToDisplayName,
            memberNames: cachedMemberNames
        ).sorted { $0.points > $1.points }
    }

    // MARK: Spielwoche-Navigation

    func loadSpielwoche(offset: Int) async {
        guard !cachedBetsByUser.isEmpty else { return }
        isLoadingSpielwoche = true
        defer { isLoadingSpielwoche = false }

        let isoCalendar = Calendar(identifier: .iso8601)
        guard let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: Date()),
              let interval   = isoCalendar.dateInterval(of: .weekOfYear, for: targetDate) else { return }

        let iso = ISO8601DateFormatter()
        let weekFromStr = String(iso.string(from: interval.start).prefix(10))
        let sunday      = interval.start.addingTimeInterval(7 * 86400 - 1)
        let weekToStr   = String(iso.string(from: sunday).prefix(10))

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "d. MMM"
        currentWeekLabel = "\(df.string(from: interval.start)) – \(df.string(from: sunday))"

        var weekMatches:    [MatchData] = []
        var currentMatches: [MatchData] = []

        await withTaskGroup(of: (tag: String, matches: [MatchData]).self) { group in
            for leagueName in community.activeLeagues {
                let lid = LeagueMapper.getID(for: leagueName)
                let max = LeagueMapper.getMaxMatchday(for: leagueName)
                if max > 0 && offset == 0 {
                    group.addTask {
                        let r = await self.api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                        return ("current", r.matches)
                    }
                }
                group.addTask {
                    let m = await self.api.fetchMatchesByDateRange(for: lid, from: weekFromStr, to: weekToStr)
                    return ("week", m)
                }
            }
            for await r in group {
                if r.tag == "current" { currentMatches += r.matches }
                else                  { weekMatches    += r.matches }
            }
        }

        var weekDict: [Int: MatchData] = [:]
        for m in weekMatches   { weekDict[m.fixture.id] = m }
        for m in currentMatches where weekDict[m.fixture.id] != nil { weekDict[m.fixture.id] = m }

        var wml: [String: [MatchData]] = [:]
        for m in weekDict.values {
            let lName = cachedLeagueIdToDisplayName[m.league.id] ?? m.league.name
            wml[lName, default: []].append(m)
        }
        weekMatchesByLeague = wml.mapValues { $0.sorted { $0.fixture.date < $1.fixture.date } }

        spielwocheLeaderboard = buildSpielwocheLeaderboard(
            betsByUser:   cachedBetsByUser,
            matchDict:    weekDict,
            nameOverride: cachedLeagueIdToDisplayName,
            memberNames:  cachedMemberNames
        ).sorted { $0.points > $1.points }
    }

    // MARK: Builder

    private func buildLeaderboard(
        betsByUser: [String: [CommunityBet]],
        matchDict: [Int: MatchData],
        nameOverride: [Int: String],
        memberNames: [String: String]
    ) -> [UserPointsEntry] {
        var allIds = Set(memberNames.keys)
        allIds.formUnion(betsByUser.keys)

        return allIds.map { userId in
            let displayName = memberNames[userId]
                ?? shortName(betsByUser[userId]?.first?.displayName ?? userId)
            let userBets = betsByUser[userId] ?? []

            var leaguePointsMap: [String: Int] = [:]
            var leagueTipsMap:   [String: [MatchTipEntry]] = [:]

            for bet in userBets {
                guard let match = matchDict[bet.fixtureId] else { continue }
                let lName = nameOverride[match.league.id] ?? match.league.name
                let pts   = calcPoints(tip: (bet.homeGoals, bet.awayGoals), match: match)
                leaguePointsMap[lName, default: 0] += pts
                let isStarted = !["NS", "TBD"].contains(match.fixture.status.short)
                leagueTipsMap[lName, default: []].append(
                    MatchTipEntry(id: bet.fixtureId, match: match,
                                  tipHome: bet.homeGoals, tipAway: bet.awayGoals,
                                  points: pts, isStarted: isStarted)
                )
            }

            let breakdown = leaguePointsMap.map { name, pts in
                LeaguePointsEntry(id: name, leagueName: name, points: pts,
                                  matchTips: (leagueTipsMap[name] ?? []).sorted {
                                      $0.match.fixture.date < $1.match.fixture.date
                                  })
            }.sorted { $0.points > $1.points }

            return UserPointsEntry(id: userId, displayName: displayName,
                                   points: leaguePointsMap.values.reduce(0, +),
                                   leagueBreakdown: breakdown)
        }
    }

    // Alle Member erscheinen — mit oder ohne Tipps, mind. 0 Punkte
    private func buildSpielwocheLeaderboard(
        betsByUser: [String: [CommunityBet]],
        matchDict: [Int: MatchData],
        nameOverride: [Int: String],
        memberNames: [String: String]
    ) -> [UserPointsEntry] {
        // Alle bekannten User-IDs: Member + User mit Bets
        var allIds = Set(memberNames.keys)
        allIds.formUnion(betsByUser.keys)

        return allIds.map { userId in
            let displayName = memberNames[userId]
                ?? shortName(betsByUser[userId]?.first?.displayName ?? userId)
            let userBets = betsByUser[userId] ?? []

            var leaguePointsMap: [String: Int] = [:]
            var leagueTipsMap:   [String: [MatchTipEntry]] = [:]

            for bet in userBets {
                guard let match = matchDict[bet.fixtureId] else { continue }
                let lName = nameOverride[match.league.id] ?? match.league.name
                let pts   = calcPoints(tip: (bet.homeGoals, bet.awayGoals), match: match)
                leaguePointsMap[lName, default: 0] += pts
                let isStarted = !["NS", "TBD"].contains(match.fixture.status.short)
                leagueTipsMap[lName, default: []].append(
                    MatchTipEntry(id: bet.fixtureId, match: match,
                                  tipHome: bet.homeGoals, tipAway: bet.awayGoals,
                                  points: pts, isStarted: isStarted)
                )
            }

            let breakdown = leaguePointsMap.map { name, pts in
                LeaguePointsEntry(id: name, leagueName: name, points: pts,
                                  matchTips: (leagueTipsMap[name] ?? []).sorted {
                                      $0.match.fixture.date < $1.match.fixture.date
                                  })
            }.sorted { $0.points > $1.points }

            return UserPointsEntry(id: userId, displayName: displayName,
                                   points: leaguePointsMap.values.reduce(0, +),
                                   leagueBreakdown: breakdown)
        }
    }

    // MARK: Member-Namen laden

    private func loadMemberDisplayNames() async -> [String: String] {
        var names: [String: String] = [:]
        await withTaskGroup(of: (String, String).self) { group in
            for uid in community.memberIds {
                group.addTask {
                    let doc  = try? await self.db.collection("users").document(uid).getDocument()
                    let name = doc?.data()?["displayName"] as? String ?? uid
                    return (uid, name)
                }
            }
            for await (uid, name) in group { names[uid] = name }
        }
        return names
    }

    // MARK: Firestore

    private func loadAllBets(communityId: String) async -> [CommunityBet] {
        do {
            let snap = try await db.collection("communities")
                .document(communityId).collection("bets").getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                guard let userId    = d["userId"]    as? String,
                      let fixtureId = d["fixtureId"] as? Int,
                      let home      = d["homeGoals"] as? Int,
                      let away      = d["awayGoals"] as? Int else { return nil }
                let email = d["email"] as? String ?? userId
                return CommunityBet(id: doc.documentID, userId: userId, displayName: email,
                                    fixtureId: fixtureId, homeGoals: home, awayGoals: away)
            }
        } catch {
            print("🚨 loadAllBets: \(error)"); return []
        }
    }

    // MARK: Helpers

    private func calcPoints(tip: (home: Int, away: Int), match: MatchData) -> Int {
        let live = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        let done = ["FT", "AET", "PEN", "AWD", "WO"]
        let s = match.fixture.status.short
        guard live.contains(s) || done.contains(s) else { return 0 }
        let aH = live.contains(s) ? (match.goals.home ?? 0) : (match.goals.home ?? -1)
        let aA = live.contains(s) ? (match.goals.away ?? 0) : (match.goals.away ?? -1)
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

    func shortName(_ email: String) -> String {
        let part = email.split(separator: "@").first.map(String.init) ?? email
        return part.prefix(1).uppercased() + part.dropFirst()
    }
}
