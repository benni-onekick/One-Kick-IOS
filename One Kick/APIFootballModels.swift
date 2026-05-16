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

// MARK: - Predictions

struct APIPredictionResponse: Codable {
    let response: [PredictionWrapper]
}

struct PredictionWrapper: Codable {
    let predictions: MatchPrediction
}

struct MatchPrediction: Codable {
    let winner: PredictionWinner?
    let percent: PredictionPercent
    let advice: String?
}

struct PredictionWinner: Codable {
    let id: Int?
    let name: String?
}

struct PredictionPercent: Codable {
    let home: String   // z.B. "68%"
    let draw: String
    let away: String
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
