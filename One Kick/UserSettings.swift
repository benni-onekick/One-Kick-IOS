//
//  UserSettings.swift
//  One Kick
//
//  Persistierte Nutzereinstellungen: Lieblingsteams (max 5) & Lieblingsligen.
//

import Foundation
import Combine

struct FavoriteTeam: Codable, Equatable {
    let id: Int
    let name: String
    let logo: String
}

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    @Published var favoriteTeams: [FavoriteTeam] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(favoriteTeams) {
                UserDefaults.standard.set(data, forKey: "favoriteTeams")
            }
        }
    }

    @Published var favoriteLeagueIds: [Int] = [] {
        didSet { UserDefaults.standard.set(favoriteLeagueIds, forKey: "favoriteLeagueIds") }
    }

    var favoriteTeamIds: [Int] { favoriteTeams.map { $0.id } }

    private init() {
        if let data = UserDefaults.standard.data(forKey: "favoriteTeams"),
           let teams = try? JSONDecoder().decode([FavoriteTeam].self, from: data) {
            favoriteTeams = teams
        }
        favoriteLeagueIds = UserDefaults.standard.array(forKey: "favoriteLeagueIds") as? [Int] ?? []
    }
}
