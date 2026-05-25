//
//  SpielwochePlayerDetailView.swift
//  One Kick
//
//  Spielwoche-Detail: erst Liga-Übersicht, dann Spiele pro Liga.
//

import SwiftUI

// MARK: - Spielwoche-Detail eines Spielers (Liga-Übersicht)

struct SpielwocheTipRow: Identifiable {
    var id: Int { match.fixture.id }
    let match: MatchData
    let tip: MatchTipEntry?
}

struct SpielwochePlayerDetailView: View {
    let entry: UserPointsEntry
    let weekMatchesByLeague: [String: [MatchData]]
    let isCurrentUser: Bool

    private let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]

    private var sortedLeagues: [String] {
        weekMatchesByLeague.keys.sorted { LeagueMapper.sortOrder(for: $0) < LeagueMapper.sortOrder(for: $1) }
    }

    private func isLeagueLive(_ leagueName: String) -> Bool {
        weekMatchesByLeague[leagueName]?.contains {
            liveStatuses.contains($0.fixture.status.short)
        } ?? false
    }

    private func leaguePoints(for name: String) -> Int {
        entry.leagueBreakdown.first(where: { $0.leagueName == name })?.points ?? 0
    }

    private func leagueTips(for name: String) -> [MatchTipEntry] {
        entry.leagueBreakdown.first(where: { $0.leagueName == name })?.matchTips ?? []
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(entry.displayName)
                            .font(.title2).bold()
                            .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                        Text("\(entry.points) Punkte diese Woche")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)

                    if sortedLeagues.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 40)).foregroundColor(.gray)
                            Text("Keine Spiele diese Woche")
                                .font(.headline).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        ForEach(sortedLeagues, id: \.self) { leagueName in
                            let pts     = leaguePoints(for: leagueName)
                            let tips    = leagueTips(for: leagueName)
                            let matches = weekMatchesByLeague[leagueName] ?? []

                            NavigationLink(destination: SpielwocheLeagueDetailView(
                                leagueName: leagueName,
                                matches: matches,
                                tips: tips,
                                isCurrentUser: isCurrentUser
                            )) {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(leagueName)
                                                .font(.headline).foregroundColor(.white).lineLimit(1)
                                            if isLeagueLive(leagueName) { LiveBadge() }
                                        }
                                        Text("\(matches.count) Spiele")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text("\(pts) Pkt")
                                        .font(.title3.bold())
                                        .foregroundColor(pts > 0 ? .oneKickNeon : .gray)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold()).foregroundColor(.gray)
                                }
                                .padding(16)
                                .background(Color.oneKickDarkGray).cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(isLeagueLive(leagueName) ? Color.red.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
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
        .navigationTitle(isCurrentUser ? "Meine Spielwoche" : entry.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Liga-Detail für Spielwoche (Spiele einer Liga)

struct SpielwocheLeagueDetailView: View {
    let leagueName: String
    let matches: [MatchData]
    let tips: [MatchTipEntry]
    let isCurrentUser: Bool

    private var rows: [SpielwocheTipRow] {
        let tipMap = Dictionary(uniqueKeysWithValues: tips.map { ($0.id, $0) })
        return matches.map { SpielwocheTipRow(match: $0, tip: tipMap[$0.fixture.id]) }
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if rows.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sportscourt").font(.system(size: 40)).foregroundColor(.gray)
                            Text("Keine Spiele").font(.headline).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        ForEach(rows) { row in
                            SpielwocheMatchRow(row: row, isCurrentUser: isCurrentUser)
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
}

// MARK: - Match-Zeile mit Tipp

struct SpielwocheMatchRow: View {
    let row: SpielwocheTipRow
    let isCurrentUser: Bool

    private var isStarted: Bool { !["NS", "TBD"].contains(row.match.fixture.status.short) }
    private var shouldReveal: Bool { isCurrentUser || isStarted }

    private var myTip: (home: Int, away: Int)? {
        guard shouldReveal, let t = row.tip else { return nil }
        return (home: t.tipHome, away: t.tipAway)
    }

    var body: some View {
        ApiMatchRow(match: row.match, myTip: myTip)
            .padding(.horizontal, 16)
    }
}
