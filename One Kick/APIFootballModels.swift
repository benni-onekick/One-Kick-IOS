//
//  APIFootballModels.swift
//  One Kick
//

import Foundation

struct APIFixturesResponse: Codable {
    let response: [MatchData]
    let paging: APIPaging?
}

struct APIPaging: Codable {
    let current: Int
    let total: Int
}

struct APIRoundsResponse: Codable {
    let response: [String]
}

struct MatchData: Codable, Identifiable {
    var id: Int { fixture.id }
    let fixture: FixtureDetails
    let league: MatchLeague
    let teams: MatchTeams
    let goals: MatchGoals
}

struct MatchLeague: Codable {
    let id: Int
    let name: String
    let round: String?
}

struct FixtureDetails: Codable {
    let id: Int
    let date: String
    let status: FixtureStatus
}

struct FixtureStatus: Codable {
    let short: String
    let elapsed: Int?
}

struct MatchTeams: Codable {
    let home: Team
    let away: Team
}

struct Team: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct MatchGoals: Codable {
    let home: Int?
    let away: Int?
}

// MARK: - Standings

struct APIStandingsResponse: Codable {
    let response: [StandingsWrapper]
}

struct StandingsWrapper: Codable {
    let league: StandingsLeagueData
}

struct StandingsLeagueData: Codable {
    let standings: [[StandingEntry]]
}

struct StandingEntry: Codable {
    let rank: Int
    let team: StandingTeam
    let points: Int
    let goalsDiff: Int
    let form: String?
    let all: StandingStats
    let group: String?
}

struct StandingTeam: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct StandingStats: Codable {
    let played: Int
    let win: Int
    let draw: Int
    let lose: Int
    let goals: StandingGoals
}

struct StandingGoals: Codable {
    let `for`: Int
    let against: Int
}

// MARK: - Wettquoten

struct MatchWinnerOdds {
    let home: Double   // Dezimalquote, z.B. 1.85
    let draw: Double
    let away: Double
}

struct APIOddsResponse: Codable {
    let response: [OddsFixtureWrapper]
}

struct OddsFixtureWrapper: Codable {
    let bookmakers: [OddsBookmaker]

    private enum CodingKeys: String, CodingKey { case bookmakers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookmakers = (try? c.decode([OddsBookmaker].self, forKey: .bookmakers)) ?? []
    }
}

struct OddsBookmaker: Codable {
    let id: Int
    let name: String
    let bets: [OddsBet]

    private enum CodingKeys: String, CodingKey { case id, name, bets }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = try c.decode(Int.self,    forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        bets = (try? c.decode([OddsBet].self, forKey: .bets)) ?? []
    }
}

struct OddsBet: Codable {
    let id: Int
    let name: String
    let values: [OddsValue]

    private enum CodingKeys: String, CodingKey { case id, name, values }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(Int.self,       forKey: .id)
        name   = try c.decode(String.self,    forKey: .name)
        values = (try? c.decode([OddsValue].self, forKey: .values)) ?? []
    }
}

struct OddsValue: Codable {
    let value: String
    let odd: String
}

// MARK: - Injuries

struct APIInjuriesResponse: Codable {
    let response: [InjuryData]
}

struct InjuryData: Codable, Identifiable {
    var id: UUID { UUID() }
    let player: InjuredPlayer
    let team: InjuryTeam
    let fixture: InjuryFixtureInfo?

    private enum CodingKeys: String, CodingKey {
        case player, team, fixture
    }
}

struct InjuredPlayer: Codable {
    let id: Int
    let name: String
    let photo: String?
    let type: String?     // "Injury" | "Suspension"
    let reason: String?
}

struct InjuryTeam: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct InjuryFixtureInfo: Codable {
    let timestamp: Int?
    let date: String?
}

// MARK: - Lineups

struct APILineupsResponse: Codable {
    let response: [TeamLineup]
}

struct TeamLineup: Codable, Identifiable {
    var id: Int { team.id }
    let team: LineupTeam
    let formation: String?
    let startXI: [LineupPlayerWrapper]
    let substitutes: [LineupPlayerWrapper]
    let coach: LineupCoach?
}

struct LineupTeam: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct LineupPlayerWrapper: Codable {
    let player: LineupPlayer
}

struct LineupPlayer: Codable, Identifiable {
    let id: Int
    let name: String
    let number: Int?
    let pos: String?
    let grid: String?
}

struct LineupCoach: Codable {
    let name: String
}

// MARK: - Players

struct APIPlayersResponse: Codable {
    let response: [PlayerData]
}

struct PlayerData: Codable {
    let player: PlayerBasicInfo
}

struct PlayerBasicInfo: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Match Events

struct APIEventsResponse: Codable {
    let response: [MatchEvent]
}

struct MatchEvent: Codable, Identifiable {
    var id: String { "\(time.elapsed ?? 0)-\(type)-\(player?.name ?? "")-\(assist?.name ?? "")" }
    let time: EventTime
    let team: EventTeam
    let player: EventNameRef?
    let assist: EventNameRef?
    let type: String
    let detail: String
    let comments: String?
}

struct EventTime: Codable {
    let elapsed: Int?
    let extra: Int?
}

struct EventTeam: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct EventNameRef: Codable {
    let id: Int?
    let name: String?
}

// MARK: - Match Statistics

struct APIStatisticsResponse: Codable {
    let response: [TeamStatistics]
}

struct TeamStatistics: Codable, Identifiable {
    var id: Int { team.id }
    let team: EventTeam
    let statistics: [StatEntry]

    func value(for type: String) -> String {
        statistics.first(where: { $0.type == type })?.displayValue ?? "-"
    }
}

struct StatEntry: Codable {
    let type: String
    private let value: AnyStat?

    var displayValue: String { value?.description ?? "-" }

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        if let i = try? c.decode(Int.self, forKey: .value) {
            value = AnyStat(i)
        } else if let s = try? c.decode(String.self, forKey: .value) {
            value = AnyStat(s)
        } else {
            value = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(value?.description, forKey: .value)
    }
}

private struct AnyStat {
    let description: String
    init(_ i: Int)    { description = "\(i)" }
    init(_ s: String) { description = s }
}
