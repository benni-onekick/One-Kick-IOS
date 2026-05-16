//
//  SpielwochePlayerDetailView.swift
//  One Kick
//
//  Detail-Ansicht eines Spielers für eine bestimmte Spielwoche.
//

import SwiftUI

// MARK: - Spielwoche-Detail eines Spielers

struct SpielwocheTipRow: Identifiable {
    var id: Int { match.fixture.id }
    let match: MatchData
    let tip: MatchTipEntry?
}

struct SpielwochePlayerDetailView: View {
    let entry: UserPointsEntry
    let weekMatchesByLeague: [String: [MatchData]]
    let isCurrentUser: Bool

    private var sortedLeagues: [String] { weekMatchesByLeague.keys.sorted() }

    private func rows(for leagueName: String) -> [SpielwocheTipRow] {
        let matches = weekMatchesByLeague[leagueName] ?? []
        let tips = entry.leagueBreakdown.first(where: { $0.leagueName == leagueName })?.matchTips ?? []
        let tipMap = Dictionary(uniqueKeysWithValues: tips.map { ($0.id, $0) })
        return matches.map { SpielwocheTipRow(match: $0, tip: tipMap[$0.fixture.id]) }
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(entry.displayName)
                            .font(.title2).bold()
                            .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                        Text("\(entry.points) Punkte diese Woche")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)

                    ForEach(sortedLeagues, id: \.self) { leagueName in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(leagueName)
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                                .tracking(1).textCase(.uppercase)
                                .padding(.horizontal, 20)

                            ForEach(rows(for: leagueName)) { row in
                                SpielwocheMatchRow(row: row, isCurrentUser: isCurrentUser)
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(isCurrentUser ? "Meine Spielwoche" : entry.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Match-Zeile mit Tipp

struct SpielwocheMatchRow: View {
    let row: SpielwocheTipRow
    let isCurrentUser: Bool

    private var isLive: Bool {
        ["1H", "2H", "HT", "ET", "P", "LIVE"].contains(row.match.fixture.status.short)
    }
    private var isStarted: Bool {
        !["NS", "TBD"].contains(row.match.fixture.status.short)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.match.teams.home.name)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .lineLimit(1)
                    if isLive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black)).foregroundColor(.black)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.red).cornerRadius(4)
                    }
                }
                Text(row.match.teams.away.name)
                    .font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
            }

            Spacer()

            if let tip = row.tip {
                if !isCurrentUser && !isStarted {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(.gray)
                        Text("Gesperrt").font(.system(size: 11)).foregroundColor(.gray)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("\(tip.tipHome):\(tip.tipAway)")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.black.opacity(0.4)).cornerRadius(8)
                            if let aH = row.match.goals.home, let aA = row.match.goals.away {
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
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.oneKickNeon)
                        }
                    }
                }
            } else {
                Text("Kein Tipp")
                    .font(.system(size: 11)).foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.oneKickDarkGray.opacity(0.6)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke((row.tip?.points ?? 0) > 0
                    ? Color.oneKickNeon.opacity(0.2)
                    : Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
