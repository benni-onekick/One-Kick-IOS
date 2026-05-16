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

struct MatchData: Codable {
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
}

struct StandingTeam: Codable {
    let id: Int
    let name: String
    let logo: String
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
