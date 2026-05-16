import Foundation

class MockFootballService {

    func fetchMatches() async throws -> [MatchData] {
        let fakeLeague = MatchLeague(id: 78, name: "Bundesliga", round: "Regular Season - 34")

        let fakeTeam1 = Team(id: 1, name: "FC Bayern München", logo: "https://media.api-sports.io/football/teams/157.png")
        let fakeTeam2 = Team(id: 2, name: "Borussia Dortmund", logo: "https://media.api-sports.io/football/teams/165.png")
        let fakeMatch = MatchData(
            fixture: FixtureDetails(id: 1001, date: "2024-05-25T15:30:00+00:00", status: FixtureStatus(short: "FT", elapsed: 90)),
            league: fakeLeague,
            teams: MatchTeams(home: fakeTeam1, away: fakeTeam2),
            goals: MatchGoals(home: 3, away: 1)
        )

        let fakeTeam3 = Team(id: 3, name: "Bayer Leverkusen", logo: "https://media.api-sports.io/football/teams/168.png")
        let fakeTeam4 = Team(id: 4, name: "VfB Stuttgart", logo: "https://media.api-sports.io/football/teams/172.png")
        let fakeMatch2 = MatchData(
            fixture: FixtureDetails(id: 1002, date: "2024-05-26T15:30:00+00:00", status: FixtureStatus(short: "NS", elapsed: nil)),
            league: fakeLeague,
            teams: MatchTeams(home: fakeTeam3, away: fakeTeam4),
            goals: MatchGoals(home: nil, away: nil)
        )

        try await Task.sleep(nanoseconds: 500_000_000)
        return [fakeMatch, fakeMatch2]
    }
}
