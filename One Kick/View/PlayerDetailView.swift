//
//  PlayerDetailView.swift
//  One Kick
//
//  Liga-Leaderboard, Spieler-Detail und Tipp-Ansicht.
//  Spielwoche-Detail → SpielwochePlayerDetailView.swift
//

import SwiftUI
import FirebaseAuth

// MARK: - Liga-Tabelle aller Spieler

struct LeagueLeaderboardView: View {
    let leagueName: String
    let rankings: [UserPointsEntry]
    let currentUserId: String?

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 6) {
                    HStack {
                        Text("Tabelle")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            .tracking(1).textCase(.uppercase)
                        Spacer()
                        Text(leagueName).font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 4)

                    if rankings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3").font(.system(size: 40)).foregroundColor(.gray)
                            Text("Noch keine Tipps").font(.headline).foregroundColor(.white)
                            Text("Hier erscheint die Ligatabelle, sobald Tipps abgegeben wurden.")
                                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal)
                    } else {
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { rank, entry in
                            let isCurrentUser = entry.id == currentUserId
                            NavigationLink(destination: PlayerMatchTipsView(
                                entry: entry,
                                leagueName: leagueName,
                                isCurrentUser: isCurrentUser
                            )) {
                                HStack(spacing: 12) {
                                    Text("\(rank + 1)")
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundColor(rankColor(rank + 1))
                                        .frame(width: 28, alignment: .center)

                                    Text(entry.displayName)
                                        .font(.system(size: 15, weight: isCurrentUser ? .bold : .regular))
                                        .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                                        .lineLimit(1)

                                    Spacer()

                                    HStack(spacing: 3) {
                                        Text("\(entry.points)")
                                            .font(.system(size: 18, weight: .black))
                                            .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                                        Text("Pkt")
                                            .font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .background(isCurrentUser
                                    ? Color.oneKickNeon.opacity(0.06)
                                    : Color.oneKickDarkGray.opacity(0.6))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(isCurrentUser
                                        ? Color.oneKickNeon.opacity(0.4)
                                        : Color.white.opacity(0.06),
                                            lineWidth: isCurrentUser ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(leagueName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
}

// MARK: - Spieler-Detail (Liga-Übersicht eines Spielers)

struct PlayerDetailView: View {
    let entry: UserPointsEntry
    let isCurrentUser: Bool

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text(entry.displayName)
                            .font(.title2).bold()
                            .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                        Text("\(entry.points) Punkte gesamt")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)

                    HStack {
                        Text("Ligen")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            .tracking(1).textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.bottom, 4)

                    ForEach(entry.leagueBreakdown) { league in
                        NavigationLink(destination: PlayerMatchTipsView(
                            entry: entry,
                            leagueName: league.leagueName,
                            isCurrentUser: isCurrentUser
                        )) {
                            HStack(spacing: 14) {
                                Image(systemName: "soccerball")
                                    .font(.system(size: 16)).foregroundColor(.gray)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.3)).clipShape(Circle())

                                Text(league.leagueName)
                                    .font(.subheadline).bold()
                                    .foregroundColor(.white).lineLimit(1)

                                Spacer()

                                Text("\(league.points) Pkt")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.oneKickNeon)

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold()).foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color.oneKickDarkGray).cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(isCurrentUser ? "Meine Tipps" : entry.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tipp-Ansicht eines Spielers in einer Liga

struct PlayerMatchTipsView: View {
    let entry: UserPointsEntry
    let leagueName: String
    let isCurrentUser: Bool

    private var tips: [MatchTipEntry] {
        entry.leagueBreakdown.first(where: { $0.leagueName == leagueName })?.matchTips ?? []
    }

    private var grouped: [(round: String, tips: [MatchTipEntry])] {
        var dict: [String: [MatchTipEntry]] = [:]
        for tip in tips {
            let r = tip.match.league.round ?? "Spieltag"
            dict[r, default: []].append(tip)
        }
        return dict.map { (round: $0.key, tips: $0.value.sorted { $0.match.fixture.date < $1.match.fixture.date }) }
                   .sorted { $0.round < $1.round }
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(grouped, id: \.round) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.round)
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                                .tracking(1).textCase(.uppercase)
                                .padding(.horizontal, 20)

                            ForEach(group.tips) { tip in
                                PlayerTipMatchRow(tip: tip, isCurrentUser: isCurrentUser)
                            }
                        }
                    }

                    if tips.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sportscourt").font(.system(size: 40)).foregroundColor(.gray)
                            Text("Keine Tipps in dieser Liga")
                                .font(.headline).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(leagueName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Einzelne Match-Tipp-Zeile

struct PlayerTipMatchRow: View {
    let tip: MatchTipEntry
    let isCurrentUser: Bool

    private var shouldReveal: Bool { isCurrentUser || tip.isStarted }

    private var isLive: Bool {
        ["1H", "2H", "HT", "ET", "P", "LIVE"].contains(tip.match.fixture.status.short)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tip.match.teams.home.name)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .lineLimit(1)
                    if isLive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.red).cornerRadius(4)
                    }
                }
                Text(tip.match.teams.away.name)
                    .font(.system(size: 13)).foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            if shouldReveal {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(tip.tipHome):\(tip.tipAway)")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.4)).cornerRadius(8)

                        if let aH = tip.match.goals.home, let aA = tip.match.goals.away {
                            Text("\(aH):\(aA)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isLive ? .orange : .oneKickNeon)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background((isLive ? Color.orange : Color.oneKickNeon).opacity(0.12))
                                .cornerRadius(8)
                        }
                    }

                    if tip.points > 0 {
                        Text("+\(tip.points) Pkt")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.oneKickNeon)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11)).foregroundColor(.gray)
                    Text("Gesperrt")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.oneKickDarkGray.opacity(0.6)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(tip.points > 0 ? Color.oneKickNeon.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
