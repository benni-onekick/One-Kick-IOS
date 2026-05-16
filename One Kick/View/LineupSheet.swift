//
//  LineupSheet.swift
//  One Kick
//

import SwiftUI

struct LineupSheet: View {
    let match: MatchData

    @Environment(\.dismiss) var dismiss
    @State private var lineups: [TeamLineup] = []
    @State private var isLoading = true

    private let service = APIFootballService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if lineups.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Aufstellung noch nicht verfügbar")
                            .font(.headline).foregroundColor(.white)
                        Text("Aufstellungen werden in der Regel ca. 1 Stunde vor Anpfiff veröffentlicht.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            HStack(spacing: 12) {
                                Text(match.teams.home.name)
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .lineLimit(2)
                                Text("vs").font(.caption).foregroundColor(.gray)
                                Text(match.teams.away.name)
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            ForEach(lineups) { lineup in
                                LineupTeamSection(lineup: lineup)
                            }

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationTitle("Aufstellung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
        }
        .task {
            lineups = await service.fetchLineups(for: match.fixture.id)
            isLoading = false
        }
    }
}

struct LineupTeamSection: View {
    let lineup: TeamLineup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: lineup.team.logo)) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(lineup.team.name)
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    if let formation = lineup.formation {
                        Text(formation)
                            .font(.caption).foregroundColor(.oneKickNeon)
                    }
                }

                Spacer()

                if let coach = lineup.coach {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Trainer")
                            .font(.system(size: 10)).foregroundColor(.gray)
                        Text(coach.name)
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 20)

            if !lineup.startXI.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STARTELF")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        .tracking(1)
                        .padding(.horizontal, 20).padding(.bottom, 6)

                    ForEach(Array(lineup.startXI.enumerated()), id: \.element.player.id) { i, wrapper in
                        LineupPlayerRow(player: wrapper.player, isSubstitute: false)
                        if i < lineup.startXI.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 20)
                        }
                    }
                }
                .background(Color.oneKickDarkGray.opacity(0.6))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }

            if !lineup.substitutes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("AUSWECHSELSPIELER")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        .tracking(1)
                        .padding(.horizontal, 20).padding(.bottom, 6)

                    ForEach(Array(lineup.substitutes.enumerated()), id: \.element.player.id) { i, wrapper in
                        LineupPlayerRow(player: wrapper.player, isSubstitute: true)
                        if i < lineup.substitutes.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 20)
                        }
                    }
                }
                .background(Color.oneKickDarkGray.opacity(0.3))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
    }
}

struct LineupPlayerRow: View {
    let player: LineupPlayer
    let isSubstitute: Bool

    private var positionColor: Color {
        guard !isSubstitute else { return .gray }
        switch player.pos {
        case "G": return .yellow
        case "D": return .blue
        case "M": return .green
        case "F": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(player.number.map { "\($0)" } ?? "–")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(positionColor)
                .frame(width: 24, alignment: .center)

            if let pos = player.pos {
                Text(pos)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(positionColor)
                    .frame(width: 18)
            }

            Text(player.name)
                .font(.system(size: 13, weight: isSubstitute ? .regular : .medium))
                .foregroundColor(isSubstitute ? .gray : .white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
