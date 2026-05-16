//
//  StandingsSheet.swift
//  One Kick
//

import SwiftUI

struct StandingsSheet: View {
    let leagueID: Int
    let leagueName: String

    @Environment(\.dismiss) var dismiss
    @State private var standings: [StandingEntry] = []
    @State private var isLoading = true

    private let service = APIFootballService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if standings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Keine Tabelle verfügbar")
                            .font(.headline).foregroundColor(.white)
                        Text("Für diesen Wettbewerb gibt es keine Tabellendaten.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("#")
                                    .frame(width: 28, alignment: .center)
                                Text("Verein")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Sp").frame(width: 28, alignment: .center)
                                Text("S").frame(width: 24, alignment: .center)
                                Text("U").frame(width: 24, alignment: .center)
                                Text("N").frame(width: 24, alignment: .center)
                                Text("TD").frame(width: 34, alignment: .center)
                                Text("Pkt").frame(width: 36, alignment: .center)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            Divider().background(Color.white.opacity(0.1))

                            ForEach(Array(standings.enumerated()), id: \.element.rank) { i, entry in
                                StandingRowView(entry: entry)
                                if i < standings.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("\(leagueName) – Tabelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
        }
        .task {
            standings = await service.fetchStandings(for: leagueID)
            isLoading = false
        }
    }
}

struct StandingRowView: View {
    let entry: StandingEntry

    var body: some View {
        HStack {
            Text("\(entry.rank)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 28, alignment: .center)

            AsyncImage(url: URL(string: entry.team.logo)) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 20, height: 20)

            Text(entry.team.name)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.all.played)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 28, alignment: .center)
            Text("\(entry.all.win)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text("\(entry.all.draw)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text("\(entry.all.lose)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text(goalDiffText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(entry.goalsDiff >= 0 ? Color.green : Color.red)
                .frame(width: 34, alignment: .center)
            Text("\(entry.points)")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.white)
                .frame(width: 36, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(rankHighlight)
    }

    private var goalDiffText: String {
        entry.goalsDiff > 0 ? "+\(entry.goalsDiff)" : "\(entry.goalsDiff)"
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }

    private var rankHighlight: Color {
        switch entry.rank {
        case 1: return Color.yellow.opacity(0.04)
        case 2: return Color.white.opacity(0.015)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.04)
        default: return .clear
        }
    }
}
