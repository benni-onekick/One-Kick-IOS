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
    let community: CommunityModel
    var hasLive: Bool = false

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 6) {
                    HStack {
                        Text("Tabelle")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            .tracking(1).textCase(.uppercase)
                        if hasLive { LiveBadge() }
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
                        let ranks = tiedRanks(for: rankings)
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { i, entry in
                            let isCurrentUser = entry.id == currentUserId
                            if isCurrentUser {
                                NavigationLink(destination: LeagueBettingView(
                                    community: community,
                                    leagueID: LeagueMapper.getID(for: leagueName),
                                    leagueName: leagueName,
                                    maxMatchday: LeagueMapper.getMaxMatchday(for: leagueName)
                                )) {
                                    leagueRowContent(entry: entry, rank: ranks[i], isCurrentUser: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            } else {
                                NavigationLink(destination: PlayerMatchTipsView(
                                    entry: entry,
                                    leagueName: leagueName,
                                    isCurrentUser: false
                                )) {
                                    leagueRowContent(entry: entry, rank: ranks[i], isCurrentUser: false)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
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

    @ViewBuilder
    private func leagueRowContent(entry: UserPointsEntry, rank: Int, isCurrentUser: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(rankColor(rank))
                .frame(width: 28, alignment: .center)

            AvatarView(displayName: entry.displayName,
                       photoBase64: entry.photoBase64,
                       size: 34)

            Text(entry.displayName)
                .font(.system(size: 15, weight: isCurrentUser ? .bold : .regular))
                .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 3) {
                Text("\(entry.totalPoints)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                Text("Pkt")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(isCurrentUser ? Color.oneKickNeon.opacity(0.06) : Color.oneKickDarkGray.opacity(0.6))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(isCurrentUser ? Color.oneKickNeon.opacity(0.4) : Color.white.opacity(0.06),
                    lineWidth: isCurrentUser ? 1.5 : 1))
    }

    private func tiedRanks(for entries: [UserPointsEntry]) -> [Int] {
        var ranks: [Int] = []
        for (i, entry) in entries.enumerated() {
            if i == 0 {
                ranks.append(1)
            } else if entry.totalPoints == entries[i - 1].totalPoints {
                ranks.append(ranks[i - 1])
            } else {
                ranks.append(i + 1)
            }
        }
        return ranks
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
    let community: CommunityModel

    private let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]

    private func isLeagueLive(_ league: LeaguePointsEntry) -> Bool {
        league.matchTips.contains { liveStatuses.contains($0.match.fixture.status.short) }
    }

    @ViewBuilder
    private func leagueRowContent(_ league: LeaguePointsEntry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "soccerball")
                .font(.system(size: 16)).foregroundColor(.gray)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.3)).clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(league.leagueName)
                    .font(.subheadline).bold()
                    .foregroundColor(.white).lineLimit(1)
                if isLeagueLive(league) { LiveBadge() }
            }

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
            .stroke(isLeagueLive(league) ? Color.red.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text(entry.displayName)
                            .font(.title2).bold()
                            .foregroundColor(isCurrentUser ? .oneKickNeon : .white)
                        Text("\(entry.totalPoints) Punkte gesamt")
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
                        if isCurrentUser {
                            NavigationLink(destination: LeagueBettingView(
                                community: community,
                                leagueID: LeagueMapper.getID(for: league.leagueName),
                                leagueName: league.leagueName,
                                maxMatchday: LeagueMapper.getMaxMatchday(for: league.leagueName)
                            )) { leagueRowContent(league) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        } else {
                            NavigationLink(destination: PlayerMatchTipsView(
                                entry: entry,
                                leagueName: league.leagueName,
                                isCurrentUser: isCurrentUser
                            )) { leagueRowContent(league) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
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

    @State private var currentGroupIndex: Int? = nil
    @State private var allLeagueMatches: [MatchData] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var liveMatchForInfo: MatchData?

    private let api = APIFootballService()

    // Getippte Spiele des Spielers: fixtureId → (home, away)
    private var tipMap: [Int: (home: Int, away: Int)] {
        let matchTips = entry.leagueBreakdown.first(where: { $0.leagueName == leagueName })?.matchTips ?? []
        var dict: [Int: (home: Int, away: Int)] = [:]
        for t in matchTips { dict[t.id] = (home: t.tipHome, away: t.tipAway) }
        return dict
    }

    // Alle Spiele: API-Daten + getippte Matches aus Entry (immer vorhanden) zusammengeführt
    // → zeigt Tipps auch wenn der API-Call fehlschlug (Rate-Limiting, offline etc.)
    private var grouped: [(round: String, matches: [MatchData])] {
        var matchDict: [Int: MatchData] = [:]
        // Basis: getippte Matches aus entry (rate-limit-sicher, immer verfügbar)
        let tippedMatches = entry.leagueBreakdown
            .first(where: { $0.leagueName == leagueName })?
            .matchTips.map { $0.match } ?? []
        for m in tippedMatches { matchDict[m.fixture.id] = m }
        // API-Daten überschreiben (frischer, haben alle Spiele)
        for m in allLeagueMatches { matchDict[m.fixture.id] = m }

        var dict: [String: [MatchData]] = [:]
        for m in matchDict.values {
            let r = m.league.round ?? "Spieltag"
            dict[r, default: []].append(m)
        }
        // Innerhalb einer Runde chronologisch (Fr → Sa → So), Runden aufsteigend
        // Leere Runden werden herausgefiltert (API-Platzhalter ohne Spiele)
        return dict.map { (round: $0.key, matches: $0.value.sorted { $0.fixture.date < $1.fixture.date }) }
                   .filter { !$0.matches.isEmpty }
                   .sorted { roundNumber($0.round) < roundNumber($1.round) }
    }

    private func roundNumber(_ round: String) -> Int {
        let num = round.components(separatedBy: " ").compactMap { Int($0) }.last ?? 0
        // Relegation/Playoff-Runden kommen nach allen regulären Spieltagen
        if isRelegationRound(round) { return 1000 + num }
        return num
    }

    private func isRelegationRound(_ round: String) -> Bool {
        let keywords = ["relegation", "playoff", "play-off", "play off", "playout",
                        "promotion", "barrage", "qualification", "qualifying",
                        "championship", "barrages", "maintien"]
        let lower = round.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    private func roundDisplayLabel(_ round: String) -> String {
        let lower = round.lowercased()
        if lower.contains("relegation") {
            let num = round.components(separatedBy: " ").compactMap { Int($0) }.last ?? 0
            switch num {
            case 1: return "Relegation · Hinspiel"
            case 2: return "Relegation · Rückspiel"
            default: return "Relegation"
            }
        }
        return round
    }

    private var currentRoundIsRelegation: Bool {
        guard effectiveIndex < grouped.count else { return false }
        return isRelegationRound(grouped[effectiveIndex].round)
    }

    // Standardmäßig letzter (aktuellster) Spieltag; clamped wenn API weniger Runden liefert
    private var effectiveIndex: Int {
        let defaultIndex = max(0, grouped.count - 1)
        guard let idx = currentGroupIndex else { return defaultIndex }
        return min(idx, grouped.count - 1)
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    if grouped.isEmpty && isLoading {
                        ProgressView().tint(.oneKickNeon)
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else if grouped.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sportscourt").font(.system(size: 40)).foregroundColor(.gray)
                            Text("Keine Spiele gefunden")
                                .font(.headline).foregroundColor(.white)
                            Text(loadFailed
                                 ? "Daten konnten nicht geladen werden."
                                 : "Noch keine Tipps oder Spiele in dieser Liga verfügbar.")
                                .font(.caption).foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            if loadFailed {
                                Button(action: {
                                    Task { await loadAllMatches() }
                                }) {
                                    Text("Erneut versuchen")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(Color.oneKickNeon)
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal)
                    } else {
                        // Spieltag-Navigation
                        VStack(spacing: 8) {
                            if currentRoundIsRelegation {
                                Text("RELEGATION")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange).tracking(1)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(6)
                            } else {
                                Text("SPIELTAG")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.oneKickNeon).tracking(1)
                            }
                            HStack(spacing: 20) {
                                Button(action: {
                                    HapticManager.instance.impact(style: .light)
                                    currentGroupIndex = max(0, effectiveIndex - 1)
                                }) {
                                    CircleButton(icon: "chevron.left", enabled: effectiveIndex > 0)
                                }
                                .disabled(effectiveIndex <= 0)

                                Text(roundDisplayLabel(grouped[effectiveIndex].round))
                                    .font(.headline).bold()
                                    .foregroundColor(currentRoundIsRelegation ? .orange : .white)
                                    .multilineTextAlignment(.center)
                                    .frame(minWidth: 140)

                                Button(action: {
                                    HapticManager.instance.impact(style: .light)
                                    currentGroupIndex = min(grouped.count - 1, effectiveIndex + 1)
                                }) {
                                    CircleButton(icon: "chevron.right", enabled: effectiveIndex < grouped.count - 1)
                                }
                                .disabled(effectiveIndex >= grouped.count - 1)
                            }
                        }
                        .padding(.vertical, 10)

                        let currentMatches = grouped[effectiveIndex].matches
                        ForEach(currentMatches, id: \.fixture.id) { match in
                            let isLive = ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short)
                            let isStarted = !["NS", "TBD"].contains(match.fixture.status.short)
                            let myTip: (home: Int, away: Int)? = (isCurrentUser || isStarted) ? tipMap[match.fixture.id] : nil

                            PlayerTipMatchRow(
                                match: match,
                                myTip: myTip,
                                onLiveInfo: isLive ? { liveMatchForInfo = match } : nil
                            )
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(leagueName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAllMatches() }
        .sheet(item: $liveMatchForInfo) { LiveMatchView(match: $0) }
    }

    private func loadAllMatches() async {
        isLoading = true
        loadFailed = false
        let lid = LeagueMapper.getID(for: leagueName)
        let from = "\(APIConfig.currentSeason)-01-01"
        // Saison-Ende: API liefert nur season=currentSeason Spiele – erweitertes Datum ist safe
        let to = "\(APIConfig.currentSeason + 1)-06-30"

        // Parallel: historische Matches + kommende Runden (Relegation-Rückspiel etc.)
        async let historical = api.fetchMatchesByDateRange(for: lid, from: from, to: to)
        async let upcoming = api.fetchCurrentAndUpcomingMatches(for: lid)
        let (hist, upc) = await (historical, upcoming)

        var merged: [Int: MatchData] = [:]
        for m in hist { merged[m.fixture.id] = m }
        for m in upc  { merged[m.fixture.id] = m }  // upcoming überschreibt mit frischeren Daten
        allLeagueMatches = Array(merged.values)
        loadFailed = allLeagueMatches.isEmpty
        isLoading = false
    }
}

// MARK: - Einzelne Match-Tipp-Zeile

struct PlayerTipMatchRow: View {
    let match: MatchData
    let myTip: (home: Int, away: Int)?
    var onLiveInfo: (() -> Void)? = nil

    var body: some View {
        ApiMatchRow(match: match, myTip: myTip, onLiveInfo: onLiveInfo)
            .padding(.horizontal, 16)
    }
}
