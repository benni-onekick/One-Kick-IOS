//
//  CommunityPunkteModels.swift
//  One Kick
//
//  Datenmodelle für Leaderboard und Tipp-Einträge.
//

import Foundation

// MARK: - Data Models

struct CommunityBet: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let fixtureId: Int
    let homeGoals: Int
    let awayGoals: Int
}

struct UserPointsEntry: Identifiable {
    let id: String
    let displayName: String
    var points: Int
    var leagueBreakdown: [LeaguePointsEntry]
}

struct LeaguePointsEntry: Identifiable {
    let id: String          // leagueName (community-seitig)
    let leagueName: String
    var points: Int
    var matchTips: [MatchTipEntry]
}

struct MatchTipEntry: Identifiable {
    let id: Int             // fixtureId
    let match: MatchData
    let tipHome: Int
    let tipAway: Int
    let points: Int
    let isStarted: Bool     // false = NS/TBD → Tipp verdeckt für andere
}
