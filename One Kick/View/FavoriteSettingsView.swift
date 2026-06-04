//
//  FavoriteSettingsView.swift
//  One Kick
//
//  Lieblingsteams (max 5) & Lieblingsligen auswählen.
//  Lieblingsteams werden in Top Spiele immer angezeigt wenn sie spielen.
//  Lieblingsligen bekommen Vorrang bei interessanten Spielen.
//

import SwiftUI

struct FavoriteSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var browsedLeagueId: Int = 78
    @State private var browseStandings: [StandingEntry] = []
    @State private var isLoadingTeams = false

    private let api = APIFootballService()

    static let leagues: [(id: Int, name: String)] = [
        (78,  "1. Bundesliga"),
        (79,  "2. Bundesliga"),
        (80,  "3. Liga"),
        (2,   "Champions League"),
        (3,   "Europa League"),
        (848, "Conference League"),
        (39,  "Premier League"),
        (140, "La Liga"),
        (135, "Serie A"),
        (61,  "Ligue 1"),
        (88,  "Eredivisie"),
        (94,  "Liga Portugal"),
        (207, "Super League"),
        (203, "Süper Lig"),
        (218, "Österreich Liga"),
        (253, "MLS"),
        (307, "Saudi Pro League"),
        (82,  "1. Frauen-Bundesliga"),
    ]

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // MARK: - Lieblingsligen
                    sectionHeader(
                        title: "Lieblingsligen",
                        subtitle: "Spiele aus diesen Ligen werden bei Top Spiele bevorzugt."
                    )

                    VStack(spacing: 8) {
                        ForEach(Self.leagues, id: \.id) { league in
                            leagueRow(id: league.id, name: league.name)
                        }
                    }

                    // MARK: - Lieblingsteams
                    sectionHeader(
                        title: "Lieblingsteams",
                        subtitle: "Wenn ein Lieblingsteam spielt, wird es immer in Top Spiele angezeigt. Max. 5 Teams."
                    )

                    // Ausgewählte Teams als Chips
                    if !settings.favoriteTeams.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(settings.favoriteTeams, id: \.id) { team in
                                    favoriteTeamChip(team: team)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Liga auswählen + Tabelle zum Stöbern
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Liga durchsuchen")
                                .font(.subheadline).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(settings.favoriteTeams.count) / 5")
                                .font(.caption.bold())
                                .foregroundColor(settings.favoriteTeams.count >= 5 ? .red : .oneKickNeon)
                        }
                        .padding(.horizontal)

                        Picker("Liga", selection: $browsedLeagueId) {
                            ForEach(Self.leagues, id: \.id) { league in
                                Text(league.name).tag(league.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.oneKickNeon)
                        .padding(.horizontal)

                        if isLoadingTeams {
                            ProgressView()
                                .tint(.oneKickNeon)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else if browseStandings.isEmpty {
                            Text("Keine Tabellendaten verfügbar.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(browseStandings, id: \.rank) { entry in
                                    teamRow(entry: entry)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 50)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Favoriten")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: browsedLeagueId) {
            await loadTeams()
        }
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline).bold()
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }

    private func leagueRow(id: Int, name: String) -> some View {
        let isSelected = settings.favoriteLeagueIds.contains(id)
        return Button(action: { toggleLeague(id: id) }) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .oneKickNeon : .gray.opacity(0.4))
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.oneKickDarkGray)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func favoriteTeamChip(team: FavoriteTeam) -> some View {
        HStack(spacing: 6) {
            Text(team.name)
                .font(.caption.bold())
                .foregroundColor(.black)
                .lineLimit(1)

            Button(action: { removeTeam(team) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.oneKickNeon)
        .cornerRadius(20)
    }

    private func teamRow(entry: StandingEntry) -> some View {
        let isFav = settings.favoriteTeamIds.contains(entry.team.id)
        let canAdd = settings.favoriteTeams.count < 5 || isFav

        return Button(action: {
            guard canAdd else { return }
            toggleTeam(entry: entry)
        }) {
            HStack(spacing: 10) {
                Text("\(entry.rank).")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 24, alignment: .trailing)

                Text(entry.team.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundColor(isFav ? .oneKickNeon : (canAdd ? .gray : .gray.opacity(0.25)))
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.oneKickDarkGray)
            .cornerRadius(12)
            .padding(.horizontal)
            .opacity((!canAdd && !isFav) ? 0.45 : 1.0)
        }
        .disabled(!canAdd && !isFav)
    }

    // MARK: - Actions

    private func toggleLeague(id: Int) {
        HapticManager.instance.impact(style: .light)
        if let idx = settings.favoriteLeagueIds.firstIndex(of: id) {
            settings.favoriteLeagueIds.remove(at: idx)
        } else {
            settings.favoriteLeagueIds.append(id)
        }
    }

    private func toggleTeam(entry: StandingEntry) {
        HapticManager.instance.impact(style: .light)
        if let idx = settings.favoriteTeams.firstIndex(where: { $0.id == entry.team.id }) {
            settings.favoriteTeams.remove(at: idx)
        } else {
            settings.favoriteTeams.append(FavoriteTeam(
                id: entry.team.id,
                name: entry.team.name,
                logo: entry.team.logo
            ))
        }
    }

    private func removeTeam(_ team: FavoriteTeam) {
        HapticManager.instance.impact(style: .light)
        settings.favoriteTeams.removeAll { $0.id == team.id }
    }

    private func loadTeams() async {
        isLoadingTeams = true
        browseStandings = await api.fetchStandings(for: browsedLeagueId)
        isLoadingTeams = false
    }
}
