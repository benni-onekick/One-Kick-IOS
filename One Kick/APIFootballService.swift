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
    private let cacheExpiry: TimeInterval = 6 * 3600

    // Lineups-Cache (5min – werden 1h vor Anpfiff veröffentlicht)
    private var lineupsCache: [Int: (lineups: [TeamLineup], date: Date)] = [:]
    private let lineupsCacheExpiry: TimeInterval = 5 * 60

    // Predictions-Cache (1h)
    private var predictionsCache: [Int: (prediction: MatchPrediction, date: Date)] = [:]

    // Injuries-Cache (3h)
    private var injuriesCache: [Int: (injuries: [InjuryData], date: Date)] = [:]
    private let injuriesCacheExpiry: TimeInterval = 3 * 3600

    // Display-Round-Cache (STATISCH = wird zwischen allen ViewModels geteilt, 5min)
    // Löst "leere Liga beim ersten Tap" → zweiter Aufruf trifft sofort den Cache
    private static var roundCache: [Int: (round: String, matchday: Int, matches: [MatchData], date: Date)] = [:]
    private static let roundCacheExpiry: TimeInterval = 5 * 60

    // MLS nutzt Kalenderjahr (2026), alle anderen Saison-Startjahr (2025)
    private func season(for leagueID: Int) -> Int {
        LeagueMapper.getSeason(for: leagueID)
    }

    private let playoffKeywords = [
        "Relegation", "Playoff", "Play-off", "Play Off", "Playout",
        "Promotion", "Barrage", "Barrages",
        "Qualification", "Qualifying", "relégation", "Maintien"
    ]

    private func isPlayoffRound(_ round: String) -> Bool {
        playoffKeywords.contains { round.localizedCaseInsensitiveContains($0) }
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
            // Letzter Ausweg: letzte 5 Runden prüfen, ob eine Spiele enthält
            let allRounds = await fetchAllRounds(for: leagueID)
            for round in allRounds.suffix(5).reversed() {
                if let matches = try? await fetchMatches(for: leagueID, round: round), !matches.isEmpty {
                    let md = extractMatchday(from: round)
                    result = (round, md, matches)
                    Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
                    return result
                }
            }
            return ("Regular Season - 1", 1, [])
        }

        var matches = (try? await fetchMatches(for: leagueID, round: currentRound)) ?? []
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
                return result
            }
        }

        result = (currentRound, currentMatchday, matches)
        Self.roundCache[leagueID] = (result.round, result.matchday, result.matches, Date())
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

    // Alle Matches (alle Status) in einem Datums-Bereich – für historische Punkte-Berechnung.
    // Paginiert automatisch durch alle Seiten (API-Football: max 100 Einträge pro Seite).
    func fetchMatchesByDateRange(for leagueID: Int, from: String, to: String) async -> [MatchData] {
        var all: [MatchData] = []
        var page = 1
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
            if page >= totalPages { break }
            page += 1
        }
        return all
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
    func fetchCurrentAndUpcomingMatches(for leagueID: Int) async -> [MatchData] {
        let iso = ISO8601DateFormatter()
        let now = Date()
        let from = String(iso.string(from: now.addingTimeInterval(-86400)).prefix(10)) // -1 Tag fängt Live-Spiele
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
        let valid: Set<String> = ["NS", "TBD", "1H", "2H", "HT", "ET", "P", "LIVE"]
        let filtered = resp.response.filter { match in
            guard valid.contains(match.fixture.status.short) else { return false }
            return !isPlayoffRound(match.league.round ?? "")
        }
        // Singleton-Runden-Filter: Runden mit nur 1 Spiel entfernen wenn andere Runden
        // ≥5 Spiele haben (reguläre Liga) → fängt Playoff-Matches mit normalem Rundennamen
        let byRound = Dictionary(grouping: filtered) { $0.league.round ?? "" }
        let maxCount = byRound.values.map(\.count).max() ?? 0
        if maxCount >= 5 {
            return filtered.filter { (byRound[$0.league.round ?? ""]?.count ?? 0) > 1 }
        }
        return filtered
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
              let group = wrapper.league.standings.first else {
            return []
        }

        standingsCache[leagueID] = (entries: group, date: Date())
        return group
    }

    // MARK: - Predictions

    func fetchPrediction(for fixtureId: Int) async -> MatchPrediction? {
        if let cached = predictionsCache[fixtureId],
           Date().timeIntervalSince(cached.date) < cacheExpiry {
            return cached.prediction
        }
        var comp = URLComponents(string: "\(baseURL)/predictions")!
        comp.queryItems = [URLQueryItem(name: "fixture", value: "\(fixtureId)")]
        guard let url = comp.url,
              let data = try? await performRequest(url: url),
              let resp = try? JSONDecoder().decode(APIPredictionResponse.self, from: data),
              let prediction = resp.response.first?.predictions else {
            return nil
        }
        predictionsCache[fixtureId] = (prediction: prediction, date: Date())
        return prediction
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

    // Alle Runden einer Liga (für KO-Wettbewerbe wie DFB-Pokal, CL etc.)
    func fetchAllRounds(for leagueID: Int) async -> [String] {
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
        return resp.response
    }

    // MARK: - Smart Top Matches
    //
    // Logik:
    //   Phase 1 – Live-Spiele (fav-Team > fav-Liga > andere tippbare Ligen)
    //   Phase 2 – Anstehende Spiele nach Anpfiff-Zeit (früher = wichtiger),
    //             innerhalb eines Zeitfensters: fav-Team > fav-Liga > andere
    //             → So verdrängt ein Bundesliga-Spiel (15:30) ein laufendes
    //               Nicht-Lieblings-Spiel (13:30) sobald es angepfiffen wird.
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

        // Fehlende Ligen nachladen
        var upcoming = preloaded
        let allLeagueIds = Array(Set(activeLeagueIds + favoriteLeagueIds))
        for id in allLeagueIds where upcoming[id] == nil {
            upcoming[id] = await fetchCurrentAndUpcomingMatches(for: id)
        }

        var allMatches: [MatchData] = []
        for id in allLeagueIds { allMatches += upcoming[id] ?? [] }

        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        let liveMatches   = allMatches.filter { liveStatuses.contains($0.fixture.status.short) }
        let upcomingOnly  = allMatches.filter { ["NS", "TBD"].contains($0.fixture.status.short) }

        var result   = [MatchData]()
        var usedIds  = Set<Int>()

        func add(_ m: MatchData) {
            guard result.count < 5, usedIds.insert(m.fixture.id).inserted else { return }
            result.append(m)
        }

        // PHASE 1 – Live-Spiele (Priorität: fav-Team > fav-Liga > sonstige)
        liveMatches.filter { favTeamSet.contains($0.teams.home.id) || favTeamSet.contains($0.teams.away.id) }.forEach { add($0) }
        liveMatches.filter { favLeagueSet.contains($0.league.id) }.forEach { add($0) }
        liveMatches.forEach { add($0) }   // restliche Live-Spiele aus tippbaren Ligen

        // PHASE 2 – Anstehende Spiele, nach Anpfiff-Zeitfenster gruppiert (frühestes zuerst)
        // Innerhalb eines Zeitfensters: fav-Team > fav-Liga > andere
        // → Bundesliga (15:30) erscheint erst nach 3. Liga (13:30), übernimmt aber ab 15:30 live den Platz
        let sortedUpcoming = upcomingOnly.sorted {
            (iso.date(from: $0.fixture.date) ?? .distantFuture) <
            (iso.date(from: $1.fixture.date) ?? .distantFuture)
        }

        // Gruppiere nach Minute-genauem Zeitfenster (ISO-Datum bis Minute: "2026-05-16T13:30")
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
            bucket.forEach { add($0) }   // andere tippbare Ligen in diesem Zeitfenster
        }

        // PHASE 3 – Fallback: Standard-Top-Ligen (CL, BL, PL, La Liga, Serie A)
        if result.isEmpty {
            let defaultLeagues = [2, 78, 39, 140, 135]
            for id in defaultLeagues where result.count < 5 {
                let matches: [MatchData]
                if let preloaded = upcoming[id] { matches = preloaded }
                else { matches = await fetchUpcomingMatches(for: id) }
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

    private func performRequest(url: URL) async throws -> Data {
        guard !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
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
