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
    // bonusCorrectAnswers: leagueName → { category → correctAnswer }
    @Published var bonusCorrectAnswers: [String: [String: String]] = [:]

    private let db  = Firestore.firestore()
    private let api = APIFootballService()
    let community: CommunityModel

    // Cache für Wochen-Navigation ohne erneutes Bets-Laden
    private var cachedBetsByUser:             [String: [CommunityBet]] = [:]
    private var cachedLeagueIdToDisplayName:  [Int: String]            = [:]
    private var cachedMemberNames:            [String: String]         = [:]
    private var cachedMemberPhotos:           [String: String?]        = [:]

    // Gespeicherte Wochengrenzen – loadGesamtData aktualisiert damit die Spielwoche
    private var storedWeekFrom = ""
    private var storedWeekTo   = ""

    // Verhindert Race Conditions: kein zweiter loadGesamtData startet während einer läuft
    private var gesamtTask: Task<Void, Never>?

    @Published var isLoadingSpielwoche = false
    var weekOffsetForRefresh = 0   // Wird vom View gesetzt; verhindert Auto-Refresh bei vergangenen Wochen

    // Kickoff-Heuristik: true wenn Live-Badges sichtbar sein könnten (auch ohne expliziten Live-Status)
    var hasPotentiallyLive: Bool {
        if !liveLeagues.isEmpty { return true }
        let now = Date()
        let isoFmt = ISO8601DateFormatter()
        return weekMatchesByLeague.values.flatMap { $0 }.contains { match in
            if ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short) { return true }
            guard let kickoff = isoFmt.date(from: match.fixture.date) else { return false }
            let elapsed = now.timeIntervalSince(kickoff) / 60
            return elapsed > -5 && elapsed < 120
        }
    }

    init(community: CommunityModel) {
        self.community = community
    }

    // MARK: Bonus-Daten laden

    nonisolated private func isPlayoffRoundName(_ round: String) -> Bool {
        let intra = ["championship round", "relegation round", "championship group", "relegation group"]
        if intra.contains(where: { round.lowercased().contains($0) }) { return false }
        let kw = ["relegation", "playoff", "play-off", "barrage",
                  "qualification", "qualifying", "promotion", "playout", "maintien"]
        // "final" entfernt: Finale-Runden sind reguläre Saisonspiele, keine Playoffs
        return kw.contains { round.lowercased().contains($0) }
    }

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
                    let roundName = r.matches.first?.league.round ?? ""
                    var isLocked = r.matchday > 1 ||
                        r.matches.contains { !["NS", "TBD"].contains($0.fixture.status.short) } ||
                        (max > 0 && self.isPlayoffRoundName(roundName))
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

        async let betsSnap    = db.collection("communities").document(communityId)
            .collection("bonusBets").getDocuments()
        async let resultsSnap = db.collection("communities").document(communityId)
            .collection("bonusCorrectAnswers").getDocuments()
        let (bets, results) = (try? await betsSnap, try? await resultsSnap)

        if let snap = bets {
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

        if let snap = results {
            var correct: [String: [String: String]] = [:]
            for doc in snap.documents {
                guard let answers = doc.data()["answers"] as? [String: String] else { continue }
                correct[doc.documentID] = answers
            }
            bonusCorrectAnswers = correct
        }

        isLoadingBonus = false
    }

    // MARK: Ligen-Rankings

    func leagueRanking(for leagueName: String) -> [UserPointsEntry] {
        totalLeaderboard.map { entry in
            if let lp = entry.leagueBreakdown.first(where: { $0.leagueName == leagueName }) {
                return UserPointsEntry(id: entry.id, displayName: entry.displayName,
                                       points: lp.points, leagueBreakdown: [lp],
                                       photoBase64: entry.photoBase64)
            }
            return UserPointsEntry(id: entry.id, displayName: entry.displayName,
                                   points: 0, leagueBreakdown: [],
                                   photoBase64: entry.photoBase64)
        }.sorted { $0.points > $1.points }
    }

    func leagueLeader(for leagueName: String) -> (name: String, points: Int)? {
        leagueRanking(for: leagueName).first.map { ($0.displayName, $0.points) }
    }

    // MARK: Load

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let communityId = community.id else { return }

        // Member-Namen + Fotos + Bets parallel laden
        async let memberDataTask = loadMemberDisplayNames()
        async let allBetsTask    = loadAllBets(communityId: communityId)
        let (memberData, allBets) = await (memberDataTask, allBetsTask)
        let memberNames  = memberData.names
        let memberPhotos = memberData.photos

        var leagueIdToDisplayName: [Int: String] = [:]
        for name in community.activeLeagues {
            leagueIdToDisplayName[LeagueMapper.getID(for: name)] = name
        }

        var betsByUser: [String: [CommunityBet]] = [:]
        for bet in allBets { betsByUser[bet.userId, default: []].append(bet) }

        cachedBetsByUser            = betsByUser
        cachedLeagueIdToDisplayName = leagueIdToDisplayName
        cachedMemberNames           = memberNames
        cachedMemberPhotos          = memberPhotos

        // Lokale Datumsformatierung: verhindert UTC-Verschiebung (Mo 00:00 CET → So 22:00 UTC → "Sonntag")
        let localDateFmt = DateFormatter()
        localDateFmt.dateFormat = "yyyy-MM-dd"

        let isoCalendar = Calendar(identifier: .iso8601)
        var weekFromStr = localDateFmt.string(from: Date())
        var weekToStr   = localDateFmt.string(from: Date())
        if let interval = isoCalendar.dateInterval(of: .weekOfYear, for: Date()) {
            weekFromStr = localDateFmt.string(from: interval.start)
            let sunday = interval.start.addingTimeInterval(7 * 86400 - 1)
            weekToStr  = localDateFmt.string(from: sunday)
            let df = DateFormatter()
            df.locale = Locale(identifier: "de_DE")
            df.dateFormat = "d. MMM"
            currentWeekLabel = "\(df.string(from: interval.start)) – \(df.string(from: sunday))"
        }

        storedWeekFrom = weekFromStr
        storedWeekTo   = weekToStr

        // Phase "vollständig" (sequenziell, rate-limit-sicher) als parallelen Task starten
        let weekMatchesTask = Task<[MatchData], Never> {
            var wm: [MatchData] = []
            for leagueName in self.community.activeLeagues {
                let lid = LeagueMapper.getID(for: leagueName)
                wm += await self.api.fetchMatchesByDateRange(for: lid, from: weekFromStr, to: weekToStr)
            }
            return wm
        }

        // Phase "schnell" (parallel, meist gecacht) gleichzeitig abarbeiten.
        // Datums-basiert: alle Spiele der aktuellen KW, unabhängig vom Spieltag.
        var currentMatches: [MatchData] = []
        await withTaskGroup(of: [MatchData].self) { group in
            for leagueName in community.activeLeagues {
                let lid = LeagueMapper.getID(for: leagueName)
                group.addTask {
                    return await self.api.fetchCurrentAndUpcomingMatches(for: lid)
                }
            }
            for await m in group { currentMatches += m }
        }

        let weekMatches = await weekMatchesTask.value

        applyWeekData(
            weekMatches: weekMatches,
            currentMatches: currentMatches,
            leagueIdToDisplayName: leagueIdToDisplayName,
            betsByUser: betsByUser,
            memberNames: memberNames,
            memberPhotos: memberPhotos,
            weekFrom: weekFromStr,
            weekTo: weekToStr
        )

        // Gecachten Stand sofort anzeigen (max 15min alt) — loadGesamtData() aktualisiert im Hintergrund
        if let cached = LeaderboardCache.shared.get(for: communityId) {
            totalLeaderboard = cached
            isLoadingGesamt = false
        } else if totalLeaderboard.isEmpty {
            totalLeaderboard = memberNames.map { uid, name in
                UserPointsEntry(id: uid, displayName: name, points: 0, leagueBreakdown: [],
                                photoBase64: memberPhotos[uid] ?? nil)
            }.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
            isLoadingGesamt = true
        }

        gesamtTask?.cancel()
        gesamtTask = Task { await loadGesamtData() }
    }

    // Gemeinsame Auswertung für loadData + loadSpielwoche
    private func applyWeekData(
        weekMatches: [MatchData],
        currentMatches: [MatchData],
        leagueIdToDisplayName: [Int: String],
        betsByUser: [String: [CommunityBet]],
        memberNames: [String: String],
        memberPhotos: [String: String?] = [:],
        weekFrom: String = "",
        weekTo: String = ""
    ) {
        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]

        // currentMatches (roundCache, ggf. veraltet) als Basis.
        // Filterung auf Wochengrenzen verhindert, dass die nächste Runde (z.B. Mo/Do) in die
        // aktuelle Woche (Mo–So) läuft, wenn determineDisplayRoundWithMatches bereits vorausschaut.
        let filteredCurrent: [MatchData]
        if !weekFrom.isEmpty && !weekTo.isEmpty {
            filteredCurrent = currentMatches.filter { match in
                let d = String(match.fixture.date.prefix(10))
                return d >= weekFrom && d <= weekTo
            }
        } else {
            filteredCurrent = currentMatches
        }

        // weekMatches (immer frischer API-Call, kein Cache) überschreibt → verhindert,
        // dass veraltete NS-Cache-Daten Live/FT-Ergebnisse zunichte machen.
        var weekDict: [Int: MatchData] = [:]
        for m in filteredCurrent { weekDict[m.fixture.id] = m }
        for m in weekMatches     { weekDict[m.fixture.id] = m }

        // liveLeagues aus ALLEN Matches (inkl. max==0 Ligen wie CL, Conference)
        liveLeagues = Set(weekDict.values
            .filter { liveStatuses.contains($0.fixture.status.short) }
            .map { leagueIdToDisplayName[$0.league.id] ?? $0.league.name }
        )

        var wml: [String: [MatchData]] = [:]
        for m in weekDict.values {
            let lName = leagueIdToDisplayName[m.league.id] ?? m.league.name
            wml[lName, default: []].append(m)
        }
        weekMatchesByLeague = wml.mapValues { $0.sorted { $0.fixture.date < $1.fixture.date } }

        spielwocheLeaderboard = buildSpielwocheLeaderboard(
            betsByUser: betsByUser, matchDict: weekDict,
            nameOverride: leagueIdToDisplayName,
            memberNames: memberNames,
            memberPhotos: memberPhotos
        ).sorted { $0.points > $1.points }
    }

    // Jeden Spieltag einzeln durchgehen: abgeschlossene Spieltage permanent cachen,
    // offene Spieltage live tracken.
    func loadGesamtData() async {
        guard !cachedMemberNames.isEmpty else {
            isLoadingGesamt = false
            return
        }
        defer { isLoadingGesamt = false }

        guard let cid = community.id else { return }

        let seasonStart = "\(APIConfig.currentSeason)-01-01"
        let toStr = "\(APIConfig.currentSeason + 1)-06-30"
        let finishedStatuses: Set<String> = ["FT", "AET", "PEN", "AWD", "WO"]

        var stablePointsPerUser: [String: Int] = [:]
        var stableLeaguePointsPerUser: [String: [String: Int]] = [:]
        var currentDict: [Int: MatchData] = [:]
        var currentMatchesList: [MatchData] = []
        var processedLeagueIds = Set<Int>()
        var stableFixtureIds = Set<Int>()

        func matchdayNumber(from round: String) -> Int {
            guard let dash = round.lastIndex(of: "-") else { return 0 }
            let s = round[round.index(after: dash)...].trimmingCharacters(in: .whitespaces)
            return Int(s) ?? 0
        }

        var allPlayoffMatchesPool: [MatchData] = []
        let hasRelegation = community.activeLeagues.contains("Relegation")

        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            guard lid != 9999 else { continue }
            let max = LeagueMapper.getMaxMatchday(for: leagueName)
            guard processedLeagueIds.insert(lid).inserted else { continue }

            if max > 0 {
                // Alle Saisondaten laden (permanenter Disk-Cache nach erstem Laden)
                var allMatches = await api.fetchAllSeasonFixtures(for: lid)

                // Fallback: Runden-Disk-Cache parallel wenn season_v2_ leer
                if allMatches.isEmpty {
                    var fallback: [MatchData] = []
                    await withTaskGroup(of: [MatchData].self) { group in
                        for n in 1...max {
                            group.addTask {
                                await self.api.fetchMatchesForRoundCached(lid, round: "Regular Season - \(n)")
                            }
                        }
                        for await rm in group { fallback += rm }
                    }
                    allMatches = fallback
                }

                // Letzter Fallback: date-range (hat Stale-Support, nutzt TippenView-Cache)
                if allMatches.isEmpty {
                    allMatches = await api.fetchMatchesByDateRange(for: lid, from: seasonStart, to: toStr)
                }

                // Nach Spieltag gruppieren; Playoff-Runden nur für Relegations-fähige Ligen sammeln
                var playoffMatches: [MatchData] = []
                var byMatchday: [Int: [MatchData]] = [:]
                let canContributeToRelegation = LeagueMapper.hasRelegationPlayoff(leagueID: lid)
                let intraRoundPatterns = ["championship round", "relegation round",
                                         "championship group", "relegation group"]
                for m in allMatches {
                    let r = m.league.round ?? ""
                    let n = matchdayNumber(from: r)
                    let isIntra = intraRoundPatterns.contains(where: { r.lowercased().contains($0) })
                    if n > 0 && n <= max {
                        byMatchday[n, default: []].append(m)
                    } else if canContributeToRelegation && !isIntra && isPlayoffRoundName(r) {
                        // Nur echte Playoff/Relegations-Runden → Pool (Finale gehört NICHT dazu)
                        playoffMatches.append(m)
                    } else {
                        // Alle anderen Runden (incl. Finale) → reguläres Scoring
                        currentDict[m.fixture.id] = m
                        if !currentMatchesList.contains(where: { $0.fixture.id == m.fixture.id }) {
                            currentMatchesList.append(m)
                        }
                    }
                }

                for n in 1...max {
                    guard let mdMatches = byMatchday[n], !mdMatches.isEmpty else { continue }
                    let allFT = mdMatches.allSatisfy { finishedStatuses.contains($0.fixture.status.short) }

                    if allFT {
                        for m in mdMatches { stableFixtureIds.insert(m.fixture.id) }
                        if let cached = MatchdayPointsCache.shared.get(
                            communityId: cid, leagueId: lid, upToMatchday: n
                        ) {
                            for (uid, pts) in cached {
                                stablePointsPerUser[uid, default: 0] += pts
                                stableLeaguePointsPerUser[uid, default: [:]][leagueName, default: 0] += pts
                            }
                        } else {
                            let matchDict = Dictionary(uniqueKeysWithValues: mdMatches.map { ($0.fixture.id, $0) })
                            let lb = buildLeaderboard(
                                betsByUser: cachedBetsByUser,
                                matchDict: matchDict,
                                nameOverride: cachedLeagueIdToDisplayName,
                                memberNames: cachedMemberNames,
                                memberPhotos: cachedMemberPhotos
                            )
                            var mdPts: [String: Int] = [:]
                            for e in lb where e.points > 0 { mdPts[e.id] = e.points }
                            if !mdPts.isEmpty {
                                MatchdayPointsCache.shared.store(
                                    mdPts, communityId: cid, leagueId: lid, upToMatchday: n
                                )
                            }
                            for (uid, pts) in mdPts {
                                stablePointsPerUser[uid, default: 0] += pts
                                stableLeaguePointsPerUser[uid, default: [:]][leagueName, default: 0] += pts
                            }
                        }
                    } else {
                        for m in mdMatches {
                            currentDict[m.fixture.id] = m
                            currentMatchesList.append(m)
                        }
                    }
                }

                // Playoff/Relegations-Matches: nur in Pool (zählen nur wenn "Relegation"-Liga aktiv)
                for m in playoffMatches where !stableFixtureIds.contains(m.fixture.id) {
                    allPlayoffMatchesPool.append(m)
                }

                // Playoff-Runden direkt laden: nur für Relegations-fähige Ligen, classifyRounds statt Keywords
                if hasRelegation && canContributeToRelegation {
                    let allRounds = await api.fetchAllRounds(for: lid)
                    let (_, rawPlayoff) = api.classifyRounds(allRounds, maxMatchday: max)
                    for roundName in rawPlayoff where !intraRoundPatterns.contains(where: { roundName.lowercased().contains($0) }) {
                        let rm = await api.fetchMatchesForRoundCached(lid, round: roundName)
                        for m in rm
                            where !stableFixtureIds.contains(m.fixture.id)
                            && !allPlayoffMatchesPool.contains(where: { $0.fixture.id == m.fixture.id }) {
                            allPlayoffMatchesPool.append(m)
                        }
                    }
                }

                // Live- und bevorstehende Spiele ergänzen (2-Min-TTL, überschreibt stale NS)
                let liveMatches = await api.fetchCurrentAndUpcomingMatches(for: lid)
                for m in liveMatches where !stableFixtureIds.contains(m.fixture.id) {
                    currentDict[m.fixture.id] = m
                    if !currentMatchesList.contains(where: { $0.fixture.id == m.fixture.id }) {
                        currentMatchesList.append(m)
                    }
                }

            } else {
                // Cup/KO-Turnier: date-range
                let m = await api.fetchMatchesByDateRange(for: lid, from: seasonStart, to: toStr)
                for match in m { currentDict[match.fixture.id] = match }
                currentMatchesList += m
                let upcoming = await api.fetchCurrentAndUpcomingMatches(for: lid)
                for u in upcoming { currentDict[u.fixture.id] = u }
                currentMatchesList += upcoming
            }
        }

        // Playoff-Matches bleiben NICHT in currentDict — sie werden separat unter "Relegation" gescort

        // Keine Daten geladen → stale Cache nutzen
        if currentDict.isEmpty && stablePointsPerUser.isEmpty {
            if let stale = LeaderboardCache.shared.get(for: cid, staleOkay: true) {
                totalLeaderboard = stale
            }
            return
        }

        // Supplemental: Alle Bet-FixtureIDs direkt nachladen die nicht stabil gecacht sind.
        // → entspricht Android-Logik (fetchFixturesByIds) und stellt sicher dass keine Bet-Fixtures
        //   fehlen die nicht in regulären „Regular Season - N" Runden gelistet sind.
        let allBetIds = Set(cachedBetsByUser.values.flatMap { $0 }.map { $0.fixtureId })
        let nonStableIds = Array(allBetIds.subtracting(stableFixtureIds))
        if !nonStableIds.isEmpty {
            let playoffIds = Set(allPlayoffMatchesPool.map { $0.fixture.id })
            let freshMatches = await api.fetchFixturesByIds(nonStableIds)
            for m in freshMatches {
                guard !playoffIds.contains(m.fixture.id) else { continue }
                currentDict[m.fixture.id] = m
                if !currentMatchesList.contains(where: { $0.fixture.id == m.fixture.id }) {
                    currentMatchesList.append(m)
                }
            }
        }

        // Leaderboard aus offenen/aktuellen Spielen
        var leaderboard = buildLeaderboard(
            betsByUser: cachedBetsByUser,
            matchDict: currentDict,
            nameOverride: cachedLeagueIdToDisplayName,
            memberNames: cachedMemberNames,
            memberPhotos: cachedMemberPhotos
        )

        // Gecachte stabile Punkte addieren
        for i in leaderboard.indices {
            let uid = leaderboard[i].id
            leaderboard[i].points += stablePointsPerUser[uid] ?? 0
            if let leagueStable = stableLeaguePointsPerUser[uid] {
                for (lName, stablePts) in leagueStable {
                    if let idx = leaderboard[i].leagueBreakdown.firstIndex(where: { $0.leagueName == lName }) {
                        leaderboard[i].leagueBreakdown[idx].points += stablePts
                    } else {
                        leaderboard[i].leagueBreakdown.append(
                            LeaguePointsEntry(id: lName, leagueName: lName, points: stablePts, matchTips: [])
                        )
                    }
                }
            }
        }

        // Playoff-Matches separat unter "Relegation" scoren (nie unter Elternliga)
        if hasRelegation && !allPlayoffMatchesPool.isEmpty {
            let playoffDict = Dictionary(uniqueKeysWithValues: allPlayoffMatchesPool.map { ($0.fixture.id, $0) })
            var playoffNameOverride = cachedLeagueIdToDisplayName
            for m in allPlayoffMatchesPool { playoffNameOverride[m.league.id] = "Relegation" }
            let playoffLb = buildLeaderboard(
                betsByUser: cachedBetsByUser,
                matchDict: playoffDict,
                nameOverride: playoffNameOverride,
                memberNames: cachedMemberNames,
                memberPhotos: cachedMemberPhotos
            )
            for pEntry in playoffLb where pEntry.points > 0 {
                if let idx = leaderboard.firstIndex(where: { $0.id == pEntry.id }) {
                    leaderboard[idx].points += pEntry.points
                    for bd in pEntry.leagueBreakdown {
                        if let bIdx = leaderboard[idx].leagueBreakdown.firstIndex(where: { $0.leagueName == bd.leagueName }) {
                            leaderboard[idx].leagueBreakdown[bIdx].points += bd.points
                            leaderboard[idx].leagueBreakdown[bIdx].matchTips.append(contentsOf: bd.matchTips)
                        } else {
                            leaderboard[idx].leagueBreakdown.append(bd)
                        }
                    }
                }
            }
        }

        totalLeaderboard = leaderboard.sorted { $0.totalPoints > $1.totalPoints }
        LeaderboardCache.shared.store(totalLeaderboard, for: cid)
        NotificationCenter.default.post(name: .leaderboardUpdated, object: nil,
                                        userInfo: ["communityId": cid])

        // Community-Rang für Badges prüfen
        if let uid = Auth.auth().currentUser?.uid,
           let rank = totalLeaderboard.firstIndex(where: { $0.id == uid }) {
            await BadgeSystem.shared.checkAndUnlockCommunity(
                rank: rank + 1, totalUsers: totalLeaderboard.count)
        }
        // Globale Community ist jetzt eigenständig (eigene Tipps) – kein Score-Übertrag mehr
        // aus regulären Communities.
    }

    // MARK: Spielwoche-Navigation

    func loadSpielwoche(offset: Int) async {
        guard !cachedBetsByUser.isEmpty else { return }
        isLoadingSpielwoche = true
        defer { isLoadingSpielwoche = false }

        let isoCalendar = Calendar(identifier: .iso8601)
        guard let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: Date()),
              let interval   = isoCalendar.dateInterval(of: .weekOfYear, for: targetDate) else { return }

        let localDateFmt = DateFormatter()
        localDateFmt.dateFormat = "yyyy-MM-dd"
        let weekFromStr = localDateFmt.string(from: interval.start)
        let sunday      = interval.start.addingTimeInterval(7 * 86400 - 1)
        let weekToStr   = localDateFmt.string(from: sunday)

        storedWeekFrom = weekFromStr
        storedWeekTo   = weekToStr

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "d. MMM"
        currentWeekLabel = "\(df.string(from: interval.start)) – \(df.string(from: sunday))"

        let weekMatchesTask = Task<[MatchData], Never> {
            var wm: [MatchData] = []
            await withTaskGroup(of: [MatchData].self) { group in
                for leagueName in self.community.activeLeagues {
                    let lid = LeagueMapper.getID(for: leagueName)
                    guard lid != 9999 else { continue }
                    group.addTask {
                        await self.api.fetchMatchesByDateRange(for: lid, from: weekFromStr, to: weekToStr)
                    }
                }
                for await matches in group { wm += matches }
            }
            return wm
        }

        let weekMatches = await weekMatchesTask.value

        applyWeekData(
            weekMatches: weekMatches,
            currentMatches: [],
            leagueIdToDisplayName: cachedLeagueIdToDisplayName,
            betsByUser: cachedBetsByUser,
            memberNames: cachedMemberNames,
            memberPhotos: cachedMemberPhotos,
            weekFrom: weekFromStr,
            weekTo: weekToStr
        )
    }

    // MARK: Builder

    private func buildLeaderboard(
        betsByUser: [String: [CommunityBet]],
        matchDict: [Int: MatchData],
        nameOverride: [Int: String],
        memberNames: [String: String],
        memberPhotos: [String: String?] = [:]
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

            for name in community.activeLeagues where leaguePointsMap[name] == nil {
                leaguePointsMap[name] = 0
            }

            let breakdown = leaguePointsMap.map { name, pts in
                LeaguePointsEntry(id: name, leagueName: name, points: pts,
                                  matchTips: (leagueTipsMap[name] ?? []).sorted {
                                      $0.match.fixture.date < $1.match.fixture.date
                                  })
            }.sorted { LeagueMapper.sortOrder(for: $0.leagueName) < LeagueMapper.sortOrder(for: $1.leagueName) }

            let matchPts = leaguePointsMap.values.reduce(0, +)
            let bonusPts = calcBonusPoints(userId: userId)

            return UserPointsEntry(id: userId, displayName: displayName,
                                   points: matchPts,
                                   bonusPoints: bonusPts,
                                   leagueBreakdown: breakdown,
                                   photoBase64: memberPhotos[userId] ?? nil)
        }
    }

    private func calcBonusPoints(userId: String) -> Int {
        guard !bonusCorrectAnswers.isEmpty else { return 0 }
        let userAnswers = bonusEntries.first(where: { $0.id == userId })?.answers ?? [:]
        var total = 0
        for leagueName in community.activeLeagues {
            guard let correct = bonusCorrectAnswers[leagueName] else { continue }
            let activeCatSet = community.activeBonusCats(for: leagueName)
            for cat in bonusCategoriesForLeague(leagueName, activeCategorySet: activeCatSet) {
                let ua = userAnswers["\(leagueName)|\(cat)"] ?? ""
                let ca = correct[cat] ?? ""
                guard !ua.isEmpty, !ca.isEmpty else { continue }
                total += BonusScoringEngine.score(userAnswer: ua, correctAnswer: ca, category: cat)
            }
        }
        return total
    }

    private func buildSpielwocheLeaderboard(
        betsByUser: [String: [CommunityBet]],
        matchDict: [Int: MatchData],
        nameOverride: [Int: String],
        memberNames: [String: String],
        memberPhotos: [String: String?] = [:]
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
            }.sorted { LeagueMapper.sortOrder(for: $0.leagueName) < LeagueMapper.sortOrder(for: $1.leagueName) }

            return UserPointsEntry(id: userId, displayName: displayName,
                                   points: leaguePointsMap.values.reduce(0, +),
                                   leagueBreakdown: breakdown,
                                   photoBase64: memberPhotos[userId] ?? nil)
        }
    }

    // MARK: Member-Namen laden

    private func loadMemberDisplayNames() async -> (names: [String: String], photos: [String: String?]) {
        var names:  [String: String]  = [:]
        var photos: [String: String?] = [:]
        await withTaskGroup(of: (String, String, String?).self) { group in
            for uid in community.memberIds {
                group.addTask {
                    let doc  = try? await self.db.collection("users").document(uid).getDocument()
                    let data = doc?.data()
                    let name: String
                    if let displayName = data?["displayName"] as? String, !displayName.isEmpty {
                        name = displayName
                    } else if let email = data?["email"] as? String {
                        let local = email.components(separatedBy: "@").first ?? email
                        name = local.prefix(1).uppercased() + local.dropFirst()
                    } else {
                        name = String(uid.prefix(8))
                    }
                    let photo = data?["photoBase64"] as? String
                    return (uid, name, photo)
                }
            }
            for await (uid, name, photo) in group {
                names[uid]  = name
                photos[uid] = photo
            }
        }
        return (names, photos)
    }

    // MARK: Firestore

    private func loadAllBets(communityId: String) async -> [CommunityBet] {
        let betsRef = db.collection("communities").document(communityId).collection("bets")
        let myUid = Auth.auth().currentUser?.uid

        // Spicken-Schutz: eigene Tipps immer; fremde Tipps nur, wenn das Spiel bereits angepfiffen
        // ist (kickoff <= jetzt). Beide Queries werden UNABHÄNGIG behandelt – schlägt eine fehl,
        // darf das nicht die ganze Rangliste leeren (die andere trägt weiterhin bei).
        let mineQuery = (myUid != nil)
            ? betsRef.whereField("userId", isEqualTo: myUid!)
            : betsRef.whereField("userId", isEqualTo: "__none__")
        let startedQuery = betsRef.whereField("kickoff", isLessThanOrEqualTo: Timestamp(date: Date()))

        func docs(_ query: Query) async -> [QueryDocumentSnapshot] {
            do { return try await query.getDocuments().documents }
            catch { print("🚨 loadAllBets query: \(error)"); return [] }
        }

        async let mineDocsTask = docs(mineQuery)
        async let startedDocsTask = docs(startedQuery)
        let (mineDocs, startedDocs) = await (mineDocsTask, startedDocsTask)

        var byId: [String: QueryDocumentSnapshot] = [:]
        for doc in mineDocs    { byId[doc.documentID] = doc }
        for doc in startedDocs { byId[doc.documentID] = doc }

        return byId.values.compactMap { doc in
            let d = doc.data()
            guard let userId    = d["userId"]    as? String,
                  let fixtureId = d["fixtureId"] as? Int,
                  let home      = d["homeGoals"] as? Int,
                  let away      = d["awayGoals"] as? Int else { return nil }
            let email = d["email"] as? String ?? userId
            return CommunityBet(id: doc.documentID, userId: userId, displayName: email,
                                fixtureId: fixtureId, homeGoals: home, awayGoals: away)
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
