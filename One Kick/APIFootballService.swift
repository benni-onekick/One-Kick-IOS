//
//  APIFootballService.swift
//  One Kick
//

import Foundation

class APIFootballService {
    private let apiKey = APIConfig.apiFootballKey
    private let baseURL = "https://v3.football.api-sports.io"

    // Standings-Cache (Instanz-Level, 6h)
    private var standingsCache: [Int: (entries: [StandingEntry], date: Date)] = [:]
    private var groupStandingsCache: [Int: (groups: [[StandingEntry]], date: Date)] = [:]
    private let cacheExpiry: TimeInterval = 6 * 3600

    // Lineups-Cache (5min – werden 1h vor Anpfiff veröffentlicht)
    private var lineupsCache: [Int: (lineups: [TeamLineup], date: Date)] = [:]
    private let lineupsCacheExpiry: TimeInterval = 5 * 60

    // Wettquoten-Cache (STATISCH, 1h) – wird zwischen allen ViewModels geteilt
    private static var oddsCache: [Int: (odds: MatchWinnerOdds, date: Date)] = [:]

    // Injuries-Cache (3h)
    private var injuriesCache: [Int: (injuries: [InjuryData], date: Date)] = [:]
    private let injuriesCacheExpiry: TimeInterval = 3 * 3600

    // Display-Round-Cache (STATISCH = wird zwischen allen ViewModels geteilt, 5min)
    // Löst "leere Liga beim ersten Tap" → zweiter Aufruf trifft sofort den Cache
    private static var roundCache: [Int: (round: String, matchday: Int, matches: [MatchData], date: Date)] = [:]
    private static let roundCacheExpiry: TimeInterval = 5 * 60

    // DateRange-Cache: In-Memory (STATISCH, 6h) + Disk-Fallback (24h)
    // Drei Schichten: Memory → Disk → API.
    // Disk-Cache überlebt App-Neustarts → verhindert 0-Punkte nach täglichem Rate-Limit.
    private static var dateRangeCache: [String: (matches: [MatchData], date: Date)] = [:]
    private static let dateRangeCacheTTL: TimeInterval     = 6 * 3600   // In-Memory: 6h
    private static let diskCacheTTL: TimeInterval          = 24 * 3600  // Disk: 24h
    private static let diskCacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OneKickMatchCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Upcoming-Cache (STATISCH, 5min) – StartseiteViewModel und TippenViewModel teilen Ergebnisse
    private static var upcomingCache: [Int: (matches: [MatchData], date: Date)] = [:]
    private static let upcomingCacheTTL: TimeInterval = 5 * 60

    // In-Flight-Deduplizierung: verhindert doppelte API-Calls wenn StartseiteView + TippenView
    // gleichzeitig dieselbe Liga laden (beide würden sonst Cache-Miss sehen und Rate-Limit auslösen)
    @MainActor private static var inFlightUpcoming: [Int: Task<[MatchData], Never>] = [:]

    // AllRounds-Cache (STATISCH, 24h) – Saisonrunden ändern sich nie → kein API-Call nötig
    private static var allRoundsCache: [Int: (rounds: [String], date: Date)] = [:]
    private static let allRoundsCacheTTL: TimeInterval = 24 * 3600

    // MLS nutzt Kalenderjahr (2026), alle anderen Saison-Startjahr (2025)
    private func season(for leagueID: Int) -> Int {
        LeagueMapper.getSeason(for: leagueID)
    }

    private let playoffKeywords = [
        "Relegation", "Playoff", "Play-off", "Play Off", "Playout",
        "Promotion", "Barrage", "Barrages",
        "Qualification", "Qualifying", "relégation", "Maintien"
    ]

    // Ligatinterne Second-Phase-Runden (Swiss Super League Championship/Relegation Round etc.)
    // bleiben in der Elternliga — sie sind kein ligaübergreifender Playoff
    private let intraLeagueRoundPatterns = [
        "Championship Round", "Relegation Round",
        "Championship Group", "Relegation Group"
    ]

    private func isPlayoffRound(_ round: String, leagueID: Int = 0) -> Bool {
        if !LeagueMapper.hasRelegationPlayoff(leagueID: leagueID) {
            if intraLeagueRoundPatterns.contains(where: { round.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }
        return playoffKeywords.contains { round.localizedCaseInsensitiveContains($0) }
    }

    // Trennt reguläre Spieltage von Playoff/Relegation-Runden ohne Liga-spezifisches Hardcoding.
    // Strategie: Runden mit dem häufigsten Text-Prefix (vor der letzten Zahl) sind die reguläre
    // Saison. Alle anderen (Championship Round, Relegation Play-offs etc.) sind Playoffs.
    // Zusätzlich: Runden mit matchday > maxMatchday werden immer als Playoff eingestuft.
    func classifyRounds(_ allRounds: [String], maxMatchday: Int) -> (regular: [String], playoff: [String]) {
        guard maxMatchday > 0, !allRounds.isEmpty else { return (allRounds, []) }

        func roundPrefix(_ round: String) -> String {
            let parts = round.components(separatedBy: CharacterSet.decimalDigits)
            return parts.dropLast().joined().trimmingCharacters(in: .whitespaces)
        }

        var counts: [String: Int] = [:]
        for r in allRounds { counts[roundPrefix(r), default: 0] += 1 }

        guard let dominantPrefix = counts.max(by: { $0.value < $1.value })?.key,
              !dominantPrefix.isEmpty else {
            let regular = allRounds.filter { !isPlayoffRound($0) }
            return (regular: regular, playoff: allRounds.filter { !regular.contains($0) })
        }

        let regular = allRounds.filter { r in
            roundPrefix(r) == dominantPrefix &&
            extractMatchday(from: r) <= maxMatchday &&
            extractMatchday(from: r) > 0
        }
        let playoff = allRounds.filter { !regular.contains($0) }
        return (regular: regular, playoff: playoff)
    }

    // MARK: - Matchday

    func determineDisplayRound(for leagueID: Int, maxMatchday: Int) async -> (round: String, matchday: Int) {
        let result = await determineDisplayRoundWithMatches(for: leagueID, maxMatchday: maxMatchday)
        return (result.round, result.matchday)
    }

    func determineDisplayRoundWithMatches(
        for leagueID: Int,
        maxMatchday: Int
    ) async -> (round: String, matchday: Int, matches: [MatchData]) {
        // Cache-Treffer → sofort zurückgeben (löst "leer beim ersten Tap")
        if let c = Self.roundCache[leagueID], Date().timeIntervalSince(c.date) < Self.roundCacheExpiry {
            return (c.round, c.matchday, c.matches)
        }

        let result: (round: String, matchday: Int, matches: [MatchData])

        guard let currentRound = await fetchCurrentRound(for: leagueID) else {
            // Letzter Ausweg: letzte reguläre Runden prüfen (Playoff/Relegation überspringen)
            let allRounds = await fetchAllRounds(for: leagueID)
            let (regularRounds, _) = classifyRounds(allRounds, maxMatchday: maxMatchday)
            for round in regularRounds.suffix(5).reversed() {
                if let matches = try? await fetchMatches(for: leagueID, round: round), !matches.isEmpty {
                    let md = extractMatchday(from: round)
                    result = (round, md, matches)
                    Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
                    UserDefaults.standard.set(["r": result.round, "md": result.matchday], forKey: "lmd_\(leagueID)")
                    return result
                }
            }
            if let d = UserDefaults.standard.dictionary(forKey: "lmd_\(leagueID)"),
               let r = d["r"] as? String, let md = d["md"] as? Int {
                return (r, md, [])
            }
            return ("Regular Season - 1", 1, [])
        }

        let matches = (try? await fetchMatches(for: leagueID, round: currentRound)) ?? []
        let currentMatchday = extractMatchday(from: currentRound)

        // Sicherheitsnetz: reguläre Liga mit nur 1 Spiel → wahrscheinlich Playoff-Runde
        // die durch den Keyword-Filter durchgerutscht ist.
        // Statt 5+ sequentielle Calls: einen Batch-Call über die letzten 90 Tage,
        // dann die Runde mit den meisten regulären Spielen nehmen (1 API-Call statt 6+)
        if maxMatchday > 0 && matches.count == 1 {
            let iso = ISO8601DateFormatter()
            let batchFrom = String(iso.string(from: Date().addingTimeInterval(-90 * 86400)).prefix(10))
            let batchTo   = String(iso.string(from: Date().addingTimeInterval( 14 * 86400)).prefix(10))
            var batchComp = URLComponents(string: "\(baseURL)/fixtures")!
            batchComp.queryItems = [
                URLQueryItem(name: "league", value: "\(leagueID)"),
                URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
                URLQueryItem(name: "from",   value: batchFrom),
                URLQueryItem(name: "to",     value: batchTo)
            ]
            if let url = batchComp.url,
               let data = try? await performRequest(url: url),
               let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) {
                let regular = resp.response.filter { !isPlayoffRound($0.league.round ?? "") }
                let byRound = Dictionary(grouping: regular) { $0.league.round ?? "" }
                if let best = byRound.max(by: { $0.value.count < $1.value.count }),
                   best.value.count > 1 {
                    let md = extractMatchday(from: best.key)
                    result = (best.key, md, best.value)
                    Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
                    UserDefaults.standard.set(["r": result.round, "md": result.matchday], forKey: "lmd_\(leagueID)")
                    return result
                }
            }
        }

        let finishedStatuses = ["FT", "AET", "PEN", "AWD", "WO"]
        let allFinished = !matches.isEmpty && matches.allSatisfy { finishedStatuses.contains($0.fixture.status.short) }

        if allFinished && currentMatchday < maxMatchday {
            let iso = ISO8601DateFormatter()
            if let lastDate = matches.compactMap({ iso.date(from: $0.fixture.date) }).max(),
               Date() > lastDate.addingTimeInterval(24 * 3600) {
                let next = currentMatchday + 1
                let nextRound = currentRound.replacingOccurrences(of: "- \(currentMatchday)", with: "- \(next)")
                let nextMatches = (try? await fetchMatches(for: leagueID, round: nextRound)) ?? []
                result = (nextRound, next, nextMatches)
                Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
                UserDefaults.standard.set(["r": result.round, "md": result.matchday], forKey: "lmd_\(leagueID)")
                return result
            }
        }

        result = (currentRound, currentMatchday, matches)
        Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
        UserDefaults.standard.set(["r": result.round, "md": result.matchday], forKey: "lmd_\(leagueID)")
        return result
    }

    func fetchMatches(for leagueID: Int, round: String) async throws -> [MatchData] {
        var components = URLComponents(string: "\(baseURL)/fixtures")!
        components.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
            URLQueryItem(name: "round", value: round)
        ]
        guard let url = components.url else { return [] }
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(APIFixturesResponse.self, from: data).response
    }

    // Lädt Matches für eine bestimmte Runde mit In-Memory (6h) + Disk-Cache (24h für abgeschlossene Runden).
    // Wiederverwendet die bestehende dateRangeCache-Infrastruktur.
    func fetchMatchesForRoundCached(_ leagueID: Int, round: String) async -> [MatchData] {
        let cacheKey = "\(leagueID)|round|\(round)"
        if let c = Self.dateRangeCache[cacheKey],
           Date().timeIntervalSince(c.date) < Self.dateRangeCacheTTL { return c.matches }
        if let cached = readDiskCache(key: cacheKey) {
            Self.dateRangeCache[cacheKey] = (cached, Date())
            return cached
        }
        var matches = (try? await fetchMatches(for: leagueID, round: round)) ?? []
        if !matches.isEmpty {
            Self.dateRangeCache[cacheKey] = (matches, Date())
            let finished: Set<String> = ["FT", "AET", "PEN", "AWD", "WO"]
            if matches.allSatisfy({ finished.contains($0.fixture.status.short) }) {
                writeDiskCache(key: cacheKey, matches: matches, ttl: 30 * 24 * 3600)
            }
        } else if let stale = readDiskCacheStale(key: cacheKey) {
            // API fehlgeschlagen (Rate-Limit) → abgelaufener Disk-Cache als Fallback
            matches = stale
        }
        return matches
    }

    // Alle Matches (alle Status) in einem Datums-Bereich – für historische Punkte-Berechnung.
    // Paginiert automatisch. Statischer Cache (15 min) verhindert Rate-Limiting bei Navigation.
    func fetchMatchesByDateRange(for leagueID: Int, from: String, to: String) async -> [MatchData] {
        let cacheKey = "\(leagueID)|\(from)|\(to)"

        // 1. In-Memory (schnellste Schicht)
        if let c = Self.dateRangeCache[cacheKey], Date().timeIntervalSince(c.date) < Self.dateRangeCacheTTL {
            return c.matches
        }

        // 2. Disk-Cache (überlebt App-Neustarts)
        if let cached = readDiskCache(key: cacheKey) {
            Self.dateRangeCache[cacheKey] = (cached, Date())
            return cached
        }

        // 3. API-Call
        var all: [MatchData] = []
        var page = 1
        var paginationComplete = false
        while true {
            var comp = URLComponents(string: "\(baseURL)/fixtures")!
            comp.queryItems = [
                URLQueryItem(name: "league",  value: "\(leagueID)"),
                URLQueryItem(name: "season",  value: "\(season(for: leagueID))"),
                URLQueryItem(name: "from",    value: from),
                URLQueryItem(name: "to",      value: to),
                URLQueryItem(name: "page",    value: "\(page)")
            ]
            guard let url = comp.url,
                  let data = try? await performRequest(url: url),
                  let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) else { break }
            all += resp.response
            let totalPages = resp.paging?.total ?? 1
            if page >= totalPages { paginationComplete = true; break }
            page += 1
        }
        if !all.isEmpty {
            Self.dateRangeCache[cacheKey] = (all, Date())
            if paginationComplete {
                // Nur vollständige Ergebnisse in den Disk-Cache schreiben
                let localFmt = DateFormatter(); localFmt.dateFormat = "yyyy-MM-dd"
                let todayStr = localFmt.string(from: Date())
                let diskTTL: TimeInterval = to < todayStr ? 30 * 24 * 3600 : 24 * 3600
                writeDiskCache(key: cacheKey, matches: all, ttl: diskTTL)
            } else if let stale = readDiskCacheStale(key: cacheKey) {
                // Pagination abgebrochen → vollständige Stale-Daten bevorzugen
                Self.dateRangeCache[cacheKey] = (stale, Date())
                return stale
            }
        } else if let stale = readDiskCacheStale(key: cacheKey) {
            // API fehlgeschlagen (rate-limit) → stale Disk-Cache statt leere Liste
            Self.dateRangeCache[cacheKey] = (stale, Date())
            return stale
        }
        return all
    }

    // MARK: - Disk-Cache Hilfsfunktionen

    private struct DiskCacheEntry: Codable {
        let savedAt: Date
        let matches: [MatchData]
        var ttl: TimeInterval = 24 * 3600  // default 24h; historische Daten: 30 Tage
    }

    private func diskCacheURL(key: String) -> URL {
        // Cache-Key zu sicherem Dateinamen umwandeln
        let safe = key.replacingOccurrences(of: "|", with: "_")
                      .replacingOccurrences(of: "/", with: "-")
        return Self.diskCacheDir.appendingPathComponent("\(safe).json")
    }

    private func readDiskCache(key: String) -> [MatchData]? {
        let url = diskCacheURL(key: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(DiskCacheEntry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < entry.ttl else { return nil }
        let iso = ISO8601DateFormatter()
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        let hasStaleNS = entry.matches.contains { match in
            guard match.fixture.status.short == "NS" else { return false }
            guard let kickoff = iso.date(from: match.fixture.date) else { return false }
            return kickoff < threeHoursAgo
        }
        // Eingefrorene Live-Scores: Match war Live als gecacht, Anpfiff >3h vergangen → Endstand fehlt
        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        let hasStaleLive = entry.matches.contains { match in
            guard liveStatuses.contains(match.fixture.status.short) else { return false }
            guard let kickoff = iso.date(from: match.fixture.date) else { return false }
            return kickoff < threeHoursAgo
        }
        if hasStaleNS || hasStaleLive { return nil }
        return entry.matches
    }

    private func readDiskCacheStale(key: String) -> [MatchData]? {
        let url = diskCacheURL(key: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(DiskCacheEntry.self, from: data)
        else { return nil }
        return entry.matches
    }

    private func writeDiskCache(key: String, matches: [MatchData], ttl: TimeInterval = 24 * 3600) {
        let url = diskCacheURL(key: key)
        let entry = DiskCacheEntry(savedAt: Date(), matches: matches, ttl: ttl)
        try? JSONEncoder().encode(entry).write(to: url, options: .atomic)
    }

    func fetchUpcomingMatches(for leagueID: Int) async -> [MatchData] {
        let iso = ISO8601DateFormatter()
        let now = Date()
        let from = String(iso.string(from: now).prefix(10))
        let to   = String(iso.string(from: now.addingTimeInterval(14 * 86400)).prefix(10))

        var comp = URLComponents(string: "\(baseURL)/fixtures")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
            URLQueryItem(name: "from",   value: from),
            URLQueryItem(name: "to",     value: to)
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) else {
            return []
        }
        let upcomingFiltered = resp.response.filter { match in
            guard ["NS", "TBD"].contains(match.fixture.status.short) else { return false }
            return !isPlayoffRound(match.league.round ?? "")
        }
        let upcomingByRound = Dictionary(grouping: upcomingFiltered) { $0.league.round ?? "" }
        let upcomingMax = upcomingByRound.values.map(\.count).max() ?? 0
        if upcomingMax >= 5 {
            return upcomingFiltered.filter { (upcomingByRound[$0.league.round ?? ""]?.count ?? 0) > 1 }
        }
        return upcomingFiltered
    }

    // Gibt NS/TBD + aktuell Live-Spiele zurück (für Top-Spiele auf der Startseite).
    // @MainActor: thread-sicherer Cache-Zugriff; Network-Call läuft im Kind-Task off-MainActor.
    @MainActor
    func fetchCurrentAndUpcomingMatches(for leagueID: Int) async -> [MatchData] {
        let iso = ISO8601DateFormatter()
        if let c = Self.upcomingCache[leagueID], Date().timeIntervalSince(c.date) < Self.upcomingCacheTTL {
            let hasStarted = c.matches.contains { m in
                guard m.fixture.status.short == "NS" else { return false }
                guard let kickoff = iso.date(from: m.fixture.date) else { return false }
                return kickoff < Date()
            }
            if !hasStarted { return c.matches }
        }

        // Laufenden Request für diese Liga abwarten statt doppelten API-Call zu machen
        if let existing = Self.inFlightUpcoming[leagueID] {
            return await existing.value
        }

        let capturedSelf = self
        let task = Task<[MatchData], Never> {
            await capturedSelf._networkFetchCurrentAndUpcoming(leagueID: leagueID)
        }
        Self.inFlightUpcoming[leagueID] = task
        let result = await task.value
        Self.upcomingCache[leagueID] = (result, Date())
        Self.inFlightUpcoming.removeValue(forKey: leagueID)
        return result
    }

    private func _networkFetchCurrentAndUpcoming(leagueID: Int) async -> [MatchData] {
        // KO-Ligen (WM, EM, CL etc.): Direkt zur aktuellen Runde springen statt alle Runden zu scannen.
        // Sequenzieller Scan von Runde 1 = bis zu 20+ uncachte Calls bei CL → Rate-Limit erschöpft.
        if LeagueMapper.getMaxMatchday(for: leagueID) == 0 {
            let valid: Set<String> = ["NS", "TBD", "1H", "2H", "HT", "ET", "P", "LIVE"]

            if let currentRound = await fetchCurrentRound(for: leagueID) {
                let matches = await fetchMatchesForRoundCached(leagueID, round: currentRound)
                let active = matches.filter { valid.contains($0.fixture.status.short) }
                if !active.isEmpty {
                    // Nächste Runde für Vorschau dazuladen (gecacht)
                    let allRounds = await fetchAllRounds(for: leagueID)
                    if let idx = allRounds.firstIndex(of: currentRound), idx + 1 < allRounds.count {
                        let next = await fetchMatchesForRoundCached(leagueID, round: allRounds[idx + 1])
                        return active + next.filter { valid.contains($0.fixture.status.short) }
                    }
                    return active
                }
            }

            // Fallback: sequenzieller Scan (nur wenn fetchCurrentRound fehlschlägt)
            let allRounds = await fetchAllRounds(for: leagueID)
            for (i, round) in allRounds.enumerated() {
                let matches = await fetchMatchesForRoundCached(leagueID, round: round)
                let active = matches.filter { valid.contains($0.fixture.status.short) }
                if !active.isEmpty {
                    var result = active
                    if i + 1 < allRounds.count {
                        let next = await fetchMatchesForRoundCached(leagueID, round: allRounds[i + 1])
                        result += next.filter { valid.contains($0.fixture.status.short) }
                    }
                    return result
                }
            }
            return []
        }

        let iso = ISO8601DateFormatter()
        let now = Date()
        let from = String(iso.string(from: now.addingTimeInterval(-86400)).prefix(10)) // -1 Tag fängt Live-Spiele
        let to   = String(iso.string(from: now.addingTimeInterval(21 * 86400)).prefix(10))

        var comp = URLComponents(string: "\(baseURL)/fixtures")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
            URLQueryItem(name: "from",   value: from),
            URLQueryItem(name: "to",     value: to)
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) else {
            return []
        }
        let valid: Set<String> = ["NS", "TBD", "1H", "2H", "HT", "ET", "P", "LIVE"]
        let filtered = resp.response.filter { match in
            guard valid.contains(match.fixture.status.short) else { return false }
            return !isPlayoffRound(match.league.round ?? "", leagueID: leagueID)
        }
        // Singleton-Runden-Filter: Runden mit nur 1 Spiel entfernen wenn andere Runden
        // ≥5 Spiele haben (reguläre Liga) → fängt Playoff-Matches mit normalem Rundennamen
        let byRound = Dictionary(grouping: filtered) { $0.league.round ?? "" }
        let maxCount = byRound.values.map(\.count).max() ?? 0
        var result: [MatchData]
        if maxCount >= 5 {
            result = filtered.filter { (byRound[$0.league.round ?? ""]?.count ?? 0) > 1 }
        } else {
            result = filtered
        }
        // Filter 3: RoundNum > maxMatchday → Playoff-Match mit unbekanntem Round-Namen herausfiltern
        let maxMd = LeagueMapper.getMaxMatchday(for: leagueID)
        if maxMd > 0 {
            result = result.filter { match in
                let r = match.league.round ?? ""
                let roundNum = r.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }.last ?? 0
                return roundNum == 0 || roundNum <= maxMd
            }
        }
        return result
    }

    // MARK: - Standings

    func fetchStandings(for leagueID: Int) async -> [StandingEntry] {
        if let cached = standingsCache[leagueID],
           Date().timeIntervalSince(cached.date) < cacheExpiry {
            return cached.entries
        }

        var comp = URLComponents(string: "\(baseURL)/standings")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))")
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIStandingsResponse.self, from: data),
              let wrapper = resp.response.first,
              !wrapper.league.standings.isEmpty else {
            return []
        }

        // Alle Gruppen flachen, Duplikate entfernen (WM/EM liefert Gruppen- + Gesamttabelle)
        var seen = Set<Int>()
        let allEntries = wrapper.league.standings
            .flatMap { $0 }
            .filter { seen.insert($0.team.id).inserted }
            .sorted { $0.team.name < $1.team.name }
        standingsCache[leagueID] = (entries: allEntries, date: Date())
        return allEntries
    }

    func fetchGroupStandings(for leagueID: Int) async -> [[StandingEntry]] {
        if let cached = groupStandingsCache[leagueID],
           Date().timeIntervalSince(cached.date) < cacheExpiry {
            return cached.groups
        }

        var comp = URLComponents(string: "\(baseURL)/standings")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))")
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIStandingsResponse.self, from: data),
              let wrapper = resp.response.first,
              !wrapper.league.standings.isEmpty else {
            return []
        }

        let groups = wrapper.league.standings.filter { !$0.isEmpty }
        groupStandingsCache[leagueID] = (groups: groups, date: Date())
        return groups
    }

    // MARK: - Wettquoten

    func fetchOdds(for fixtureId: Int) async -> MatchWinnerOdds? {
        if let cached = Self.oddsCache[fixtureId],
           Date().timeIntervalSince(cached.date) < cacheExpiry {
            return cached.odds
        }
        var comp = URLComponents(string: "\(baseURL)/odds")!
        comp.queryItems = [URLQueryItem(name: "fixture", value: "\(fixtureId)")]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIOddsResponse.self, from: data),
              let wrapper = resp.response.first else { return nil }

        for bookmaker in wrapper.bookmakers {
            guard let bet = bookmaker.bets.first(where: { $0.id == 1 || $0.name == "Match Winner" })
            else { continue }
            guard let homeVal = bet.values.first(where: { $0.value == "Home" }),
                  let drawVal = bet.values.first(where: { $0.value == "Draw" }),
                  let awayVal = bet.values.first(where: { $0.value == "Away" }),
                  let h = Double(homeVal.odd), let d = Double(drawVal.odd), let a = Double(awayVal.odd),
                  h > 1, d > 1, a > 1
            else { continue }
            let result = MatchWinnerOdds(home: h, draw: d, away: a)
            Self.oddsCache[fixtureId] = (result, Date())
            return result
        }
        return nil
    }

    // MARK: - Injuries

    func fetchInjuries(for leagueID: Int) async -> [InjuryData] {
        if let cached = injuriesCache[leagueID],
           Date().timeIntervalSince(cached.date) < injuriesCacheExpiry {
            return cached.injuries
        }
        var comp = URLComponents(string: "\(baseURL)/injuries")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))")
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIInjuriesResponse.self, from: data) else {
            return []
        }
        injuriesCache[leagueID] = (injuries: resp.response, date: Date())
        return resp.response
    }

    // MARK: - Lineups

    func fetchLineups(for fixtureId: Int) async -> [TeamLineup] {
        if let cached = lineupsCache[fixtureId],
           Date().timeIntervalSince(cached.date) < lineupsCacheExpiry {
            return cached.lineups
        }

        var comp = URLComponents(string: "\(baseURL)/fixtures/lineups")!
        comp.queryItems = [URLQueryItem(name: "fixture", value: "\(fixtureId)")]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APILineupsResponse.self, from: data) else {
            return []
        }

        lineupsCache[fixtureId] = (lineups: resp.response, date: Date())
        return resp.response
    }

    // MARK: - Players

    func searchPlayers(in leagueID: Int, query: String) async -> [PlayerBasicInfo] {
        var comp = URLComponents(string: "\(baseURL)/players")!
        comp.queryItems = [
            URLQueryItem(name: "league",  value: "\(leagueID)"),
            URLQueryItem(name: "season",  value: "\(season(for: leagueID))"),
            URLQueryItem(name: "search",  value: query)
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIPlayersResponse.self, from: data) else {
            return []
        }
        return resp.response.map(\.player)
    }

    // Alle Saisonspiele einer Liga — mit Paginierung, dateRangeCache (6h Memory + 24h Disk)
    func fetchAllSeasonFixtures(for leagueID: Int) async -> [MatchData] {
        let cacheKey = "season_v2_\(leagueID)_\(season(for: leagueID))"
        let diskURL = Self.diskCacheDir.appendingPathComponent("\(cacheKey).json")

        let iso = ISO8601DateFormatter()
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        func hasStaleNS(_ matches: [MatchData]) -> Bool {
            matches.contains { m in
                guard m.fixture.status.short == "NS" else { return false }
                guard let kickoff = iso.date(from: m.fixture.date) else { return false }
                return kickoff < threeHoursAgo
            }
        }

        if let entry = Self.dateRangeCache[cacheKey],
           Date().timeIntervalSince(entry.date) < Self.dateRangeCacheTTL,
           !hasStaleNS(entry.matches) {
            return entry.matches
        }
        if let data = try? Data(contentsOf: diskURL),
           let cached = try? JSONDecoder().decode([MatchData].self, from: data) {
            if !hasStaleNS(cached) {
                Self.dateRangeCache[cacheKey] = (cached, Date())
                return cached
            }
            try? FileManager.default.removeItem(at: diskURL)
        }

        var all: [MatchData] = []
        var page = 1
        var paginationComplete = false
        while true {
            var comp = URLComponents(string: "\(baseURL)/fixtures")!
            comp.queryItems = [
                URLQueryItem(name: "league", value: "\(leagueID)"),
                URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
                URLQueryItem(name: "page",   value: "\(page)")
            ]
            guard let url = comp.url,
                  let data = try? await performRequest(url: url),
                  let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) else { break }
            all += resp.response
            let totalPages = resp.paging?.total ?? 1
            if page >= totalPages { paginationComplete = true; break }
            page += 1
        }
        if !all.isEmpty {
            Self.dateRangeCache[cacheKey] = (all, Date())
            if paginationComplete {
                try? JSONEncoder().encode(all).write(to: diskURL)
            }
        }
        return all
    }

    // Alle Runden einer Liga (für KO-Wettbewerbe wie DFB-Pokal, CL etc.)
    func fetchAllRounds(for leagueID: Int) async -> [String] {
        if let c = Self.allRoundsCache[leagueID],
           Date().timeIntervalSince(c.date) < Self.allRoundsCacheTTL {
            return c.rounds
        }
        var comp = URLComponents(string: "\(baseURL)/fixtures/rounds")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))")
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIRoundsResponse.self, from: data) else {
            return []
        }
        let rounds = resp.response
        if !rounds.isEmpty { Self.allRoundsCache[leagueID] = (rounds, Date()) }
        return rounds
    }

    func fetchCurrentRoundsRaw(for leagueID: Int) async -> [String] {
        var comp = URLComponents(string: "\(baseURL)/fixtures/rounds")!
        comp.queryItems = [
            URLQueryItem(name: "league",  value: "\(leagueID)"),
            URLQueryItem(name: "season",  value: "\(season(for: leagueID))"),
            URLQueryItem(name: "current", value: "true")
        ]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIRoundsResponse.self, from: data) else { return [] }
        return resp.response
    }

    // MARK: - Match Events & Statistics

    // Cache: 30 Sek für Live-Spiele, 1h für abgeschlossene
    private var eventsCache: [Int: (events: [MatchEvent], date: Date)] = [:]
    private var statsCache:  [Int: (stats: [TeamStatistics], date: Date)] = [:]

    func fetchMatchEvents(for fixtureId: Int, isLive: Bool) async -> [MatchEvent] {
        let ttl: TimeInterval = isLive ? 30 : 3600
        if let c = eventsCache[fixtureId], Date().timeIntervalSince(c.date) < ttl { return c.events }
        var comp = URLComponents(string: "\(baseURL)/fixtures/events")!
        comp.queryItems = [URLQueryItem(name: "fixture", value: "\(fixtureId)")]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIEventsResponse.self, from: data) else { return [] }
        eventsCache[fixtureId] = (resp.response, Date())
        return resp.response
    }

    func fetchMatchStatistics(for fixtureId: Int, isLive: Bool) async -> [TeamStatistics] {
        let ttl: TimeInterval = isLive ? 30 : 3600
        if let c = statsCache[fixtureId], Date().timeIntervalSince(c.date) < ttl { return c.stats }
        var comp = URLComponents(string: "\(baseURL)/fixtures/statistics")!
        comp.queryItems = [URLQueryItem(name: "fixture", value: "\(fixtureId)")]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIStatisticsResponse.self, from: data) else { return [] }
        statsCache[fixtureId] = (resp.response, Date())
        return resp.response
    }

    // MARK: - Smart Top Matches
    //
    // Logik:
    //   Phase 1 – Live-Spiele, standings-basiert sortiert:
    //             Favoriten → Titelrennen (beide Top-8) → Abstiegskampf (Bottom-5) → nach kombiniertem Rang
    //   Phase 2 – Anstehende Spiele nach Anpfiff-Zeit, Favoriten zuerst
    //   Phase 3 – Fallback: Standard-Top-Ligen

    func fetchSmartTopMatches(
        favoriteTeamIds: [Int],
        favoriteLeagueIds: [Int],
        activeLeagueIds: [Int],
        preloaded: [Int: [MatchData]]
    ) async -> [MatchData] {
        let iso = ISO8601DateFormatter()
        let favTeamSet   = Set(favoriteTeamIds)
        let favLeagueSet = Set(favoriteLeagueIds)

        // Stabile Reihenfolge: InsertionOrder-Deduplizierung statt Set → verhindert wechselnde Spielreihenfolge
        var seenIds = Set<Int>()
        var allLeagueIds: [Int] = []
        for id in activeLeagueIds + favoriteLeagueIds {
            if seenIds.insert(id).inserted { allLeagueIds.append(id) }
        }

        // Fehlende Ligen nachladen
        var upcoming = preloaded
        for id in allLeagueIds where upcoming[id] == nil {
            upcoming[id] = await fetchCurrentAndUpcomingMatches(for: id)
        }

        var allMatches: [MatchData] = []
        for id in allLeagueIds { allMatches += upcoming[id] ?? [] }

        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        let liveMatches  = allMatches.filter { liveStatuses.contains($0.fixture.status.short) }
        let upcomingOnly = allMatches.filter { ["NS", "TBD"].contains($0.fixture.status.short) }

        // Tabellen für Live-Ligen parallel laden (6h-Cache → meist sofort)
        var standingsMap: [Int: [StandingEntry]] = [:]
        let liveLeagueIds = Set(liveMatches.map { $0.league.id })
        if !liveLeagueIds.isEmpty {
            await withTaskGroup(of: (Int, [StandingEntry]).self) { group in
                for lid in liveLeagueIds {
                    group.addTask { (lid, await self.fetchStandings(for: lid)) }
                }
                for await (lid, entries) in group { standingsMap[lid] = entries }
            }
        }

        // Prioritäts-Score für Sortierung:
        //  -2 = Favoriten-Team, -1 = Favoriten-Liga
        //   0 = Titelrennen (beide Top-8)
        //   1 = Abstiegskampf (mind. ein Team in Bottom-5)
        //   2+ = kombinierter Tabellenrang
        func matchPriority(_ m: MatchData) -> Int {
            if favTeamSet.contains(m.teams.home.id) || favTeamSet.contains(m.teams.away.id) { return -2 }
            if favLeagueSet.contains(m.league.id) { return -1 }
            let entries  = standingsMap[m.league.id] ?? []
            let total    = entries.count
            guard total > 0 else { return 200 }
            let homeRank = entries.first(where: { $0.team.id == m.teams.home.id })?.rank ?? (total + 1)
            let awayRank = entries.first(where: { $0.team.id == m.teams.away.id })?.rank ?? (total + 1)
            if homeRank <= 8 && awayRank <= 8                                              { return 0 }
            if total >= 5 && (homeRank >= total - 4 || awayRank >= total - 4)              { return 1 }
            return homeRank + awayRank + 2
        }

        let sortedLive = liveMatches.sorted { matchPriority($0) < matchPriority($1) }

        var result  = [MatchData]()
        var usedIds = Set<Int>()

        func add(_ m: MatchData) {
            guard result.count < 5, usedIds.insert(m.fixture.id).inserted else { return }
            result.append(m)
        }

        // PHASE 1 – Live-Spiele (standings-basiert sortiert)
        sortedLive.forEach { add($0) }

        // PHASE 2 – Anstehende Spiele nach Anpfiff-Zeit, Favoriten zuerst
        let sortedUpcoming = upcomingOnly.sorted {
            (iso.date(from: $0.fixture.date) ?? .distantFuture) <
            (iso.date(from: $1.fixture.date) ?? .distantFuture)
        }

        var bucketOrder = [String]()
        var bucketMap   = [String: [MatchData]]()
        for match in sortedUpcoming {
            let key = String(match.fixture.date.prefix(16))
            if bucketMap[key] == nil { bucketOrder.append(key) }
            bucketMap[key, default: []].append(match)
        }

        for key in bucketOrder where result.count < 5 {
            let bucket = bucketMap[key] ?? []
            bucket.filter { favTeamSet.contains($0.teams.home.id) || favTeamSet.contains($0.teams.away.id) }.forEach { add($0) }
            bucket.filter { favLeagueSet.contains($0.league.id) }.forEach { add($0) }
            bucket.forEach { add($0) }
        }

        // PHASE 3 – Fallback: Standard-Top-Ligen (CL, BL, PL, La Liga, Serie A, MLS, Saudi)
        // fetchCurrentAndUpcomingMatches statt fetchUpcomingMatches → nutzt 5-min-Cache + In-Flight-Dedup
        if result.isEmpty {
            let defaultLeagues = [1, 2, 78, 39, 140, 135, 253, 307]
            for id in defaultLeagues where result.count < 5 {
                let matches: [MatchData]
                if let preloaded = upcoming[id] { matches = preloaded }
                else { matches = await fetchCurrentAndUpcomingMatches(for: id) }
                if let first = matches.first(where: { !usedIds.contains($0.fixture.id) }) { add(first) }
            }
        }

        return result
    }

    // MARK: - Private

    func fetchCurrentRound(for leagueID: Int) async -> String? {
        let iso = ISO8601DateFormatter()
        let now = Date()

        // 1. Live-Spiele prüfen (±1 Tag) → deren Runde hat absolute Priorität
        let liveFrom = String(iso.string(from: now.addingTimeInterval(-86400)).prefix(10))
        let liveTo   = String(iso.string(from: now.addingTimeInterval( 86400)).prefix(10))
        var liveComp = URLComponents(string: "\(baseURL)/fixtures")!
        liveComp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
            URLQueryItem(name: "from",   value: liveFrom),
            URLQueryItem(name: "to",     value: liveTo)
        ]
        if let url = liveComp.url,
           let data = try? await performRequest(url: url),
           let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) {
            let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
            if let live = resp.response.first(where: {
                liveStatuses.contains($0.fixture.status.short) &&
                !isPlayoffRound($0.league.round ?? "")
            }) {
                return live.league.round
            }
        }

        // 2. API-eigener "current round" Endpoint — zuverlässigste Quelle für aktuelle Runde
        // Playoff-/Relegations-Runden werden übersprungen
        var currentComp = URLComponents(string: "\(baseURL)/fixtures/rounds")!
        currentComp.queryItems = [
            URLQueryItem(name: "league",  value: "\(leagueID)"),
            URLQueryItem(name: "season",  value: "\(season(for: leagueID))"),
            URLQueryItem(name: "current", value: "true")
        ]
        if let url = currentComp.url,
           let data = try? await performRequest(url: url),
           let resp = try? JSONDecoder().decode(APIRoundsResponse.self, from: data),
           let round = resp.response.first,
           !isPlayoffRound(round) {
            return round
        }

        // 3. Fallback: letzter FT-Match oder erster NS-Match im ±30-Tage-Fenster
        // Playoff-/Relegations-Spiele werden herausgefiltert
        let from = String(iso.string(from: now.addingTimeInterval(-30 * 86400)).prefix(10))
        let to   = String(iso.string(from: now.addingTimeInterval( 30 * 86400)).prefix(10))
        var comp = URLComponents(string: "\(baseURL)/fixtures")!
        comp.queryItems = [
            URLQueryItem(name: "league", value: "\(leagueID)"),
            URLQueryItem(name: "season", value: "\(season(for: leagueID))"),
            URLQueryItem(name: "from",   value: from),
            URLQueryItem(name: "to",     value: to)
        ]
        if let url = comp.url,
           let data = try? await performRequest(url: url),
           let resp = try? JSONDecoder().decode(APIFixturesResponse.self, from: data) {
            let regular = resp.response.filter { !isPlayoffRound($0.league.round ?? "") }
            let sorted = regular.sorted { $0.fixture.date < $1.fixture.date }
            let finishedStatuses: Set<String> = ["FT", "AET", "PEN", "AWD", "WO"]
            if let last = sorted.last(where: { finishedStatuses.contains($0.fixture.status.short) }) {
                return last.league.round
            }
            if let next = sorted.first(where: { ["NS", "TBD"].contains($0.fixture.status.short) }) {
                return next.league.round
            }
            if let last = sorted.last { return last.league.round }
        }

        return nil
    }

    func performRequest(url: URL, attempt: Int = 1) async throws -> Data {
        guard !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 && attempt < 3 {
                // Rate-Limit: kurz warten und nochmal versuchen
                try await Task.sleep(nanoseconds: UInt64(attempt) * 5_000_000_000)
                return try await performRequest(url: url, attempt: attempt + 1)
            }
            if !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
        }
        return data
    }

    private func extractMatchday(from round: String) -> Int {
        // Findet die letzte Ziffernfolge im String, unabhängig vom Format
        // "Regular Season - 34" → 34, "Ligue 1 - 34" → 34, "Round 34" → 34
        let sequences = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
        if let last = sequences.last, let n = Int(last) { return n }
        return 1
    }
}
