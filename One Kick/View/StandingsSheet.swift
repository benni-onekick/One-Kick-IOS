//
//  StandingsSheet.swift
//  One Kick
//

import SwiftUI

// MARK: - Live-Adjusted Display Entry (file-private)

struct StandingDisplayEntry: Identifiable {
    let id: Int  // team.id
    var rank: Int
    let entry: StandingEntry
    var bonusPoints: Int   = 0
    var bonusPlayed: Int   = 0
    var bonusWin: Int      = 0
    var bonusDraw: Int     = 0
    var bonusLoss: Int     = 0
    var bonusGoalDiff: Int = 0
    var hasLiveMatch: Bool = false

    var points: Int    { entry.points     + bonusPoints }
    var played: Int    { entry.all.played + bonusPlayed }
    var win: Int       { entry.all.win    + bonusWin }
    var draw: Int      { entry.all.draw   + bonusDraw }
    var lose: Int      { entry.all.lose   + bonusLoss }
    var goalsDiff: Int { entry.goalsDiff  + bonusGoalDiff }
}

// MARK: - Main View

struct StandingsSheet: View {
    let leagueID: Int
    let leagueName: String

    @Environment(\.dismiss) var dismiss
    @State private var displayEntries: [StandingDisplayEntry] = []
    @State private var hasLive = false
    @State private var isLoading = true

    private let service = APIFootballService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if displayEntries.isEmpty {
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
                            if hasLive {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("LIVE")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color.red.opacity(0.85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                            }

                            // Spaltenüberschriften
                            HStack {
                                Text("#").frame(width: 28, alignment: .center)
                                Text("Verein").frame(maxWidth: .infinity, alignment: .leading)
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

                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 0.5)

                            ForEach(Array(displayEntries.enumerated()), id: \.element.id) { i, de in
                                StandingRowView(displayEntry: de, leagueID: leagueID)

                                if i < displayEntries.count - 1 {
                                    let boundary = isZoneBoundary(at: i)
                                    Rectangle()
                                        .fill(Color.white.opacity(boundary ? 0.18 : 0.06))
                                        .frame(height: boundary ? 1 : 0.5)
                                        .padding(.horizontal, boundary ? 0 : 8)
                                }
                            }

                            legendView
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
            async let standingsTask = service.fetchStandings(for: leagueID)
            async let matchesTask   = service.fetchCurrentAndUpcomingMatches(for: leagueID)
            let (rawStandings, allMatches) = await (standingsTask, matchesTask)

            let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
            let live = allMatches.filter { liveStatuses.contains($0.fixture.status.short) }
            hasLive = !live.isEmpty
            displayEntries = buildDisplayEntries(standings: rawStandings, liveMatches: live)
            isLoading = false
        }
    }

    // MARK: - Live-Anpassung

    private func buildDisplayEntries(
        standings: [StandingEntry],
        liveMatches: [MatchData]
    ) -> [StandingDisplayEntry] {
        var dict: [Int: StandingDisplayEntry] = [:]
        for e in standings {
            dict[e.team.id] = StandingDisplayEntry(id: e.team.id, rank: e.rank, entry: e)
        }

        for match in liveMatches {
            let hID = match.teams.home.id
            let aID = match.teams.away.id
            let hG  = match.goals.home ?? 0
            let aG  = match.goals.away ?? 0
            guard dict[hID] != nil, dict[aID] != nil else { continue }

            dict[hID]!.bonusPlayed   += 1
            dict[aID]!.bonusPlayed   += 1
            dict[hID]!.hasLiveMatch   = true
            dict[aID]!.hasLiveMatch   = true
            dict[hID]!.bonusGoalDiff += (hG - aG)
            dict[aID]!.bonusGoalDiff -= (hG - aG)

            if hG > aG {
                dict[hID]!.bonusPoints += 3; dict[hID]!.bonusWin  += 1
                dict[aID]!.bonusLoss   += 1
            } else if hG == aG {
                dict[hID]!.bonusPoints += 1; dict[hID]!.bonusDraw += 1
                dict[aID]!.bonusPoints += 1; dict[aID]!.bonusDraw += 1
            } else {
                dict[aID]!.bonusPoints += 3; dict[aID]!.bonusWin  += 1
                dict[hID]!.bonusLoss   += 1
            }
        }

        var sorted = Array(dict.values).sorted {
            if $0.points    != $1.points    { return $0.points    > $1.points }
            if $0.goalsDiff != $1.goalsDiff { return $0.goalsDiff > $1.goalsDiff }
            return $0.entry.all.goals.`for` > $1.entry.all.goals.`for`
        }
        for i in sorted.indices { sorted[i].rank = i + 1 }
        return sorted
    }

    // MARK: - Zonengrenze-Prüfung

    private func isZoneBoundary(at index: Int) -> Bool {
        guard index < displayEntries.count - 1 else { return false }
        let curr = LeagueMapper.qualificationZone(rank: displayEntries[index].rank, leagueID: leagueID)
        let next = LeagueMapper.qualificationZone(rank: displayEntries[index + 1].rank, leagueID: leagueID)
        return curr != next
    }

    // MARK: - Legende

    @ViewBuilder
    private var legendView: some View {
        let zones = uniqueZones
        if !zones.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(zones, id: \.label) { zone in
                    HStack(spacing: 8) {
                        zone.color
                            .frame(width: 10, height: 10)
                            .clipShape(Circle())
                        Text(zone.label)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    fileprivate var uniqueZones: [QualificationZone] {
        var seen = Set<QualificationZone>()
        var result: [QualificationZone] = []
        for e in displayEntries {
            if let z = LeagueMapper.qualificationZone(rank: e.rank, leagueID: leagueID),
               seen.insert(z).inserted {
                result.append(z)
            }
        }
        return result
    }
}

// MARK: - Zeilen-View

struct StandingRowView: View {
    let displayEntry: StandingDisplayEntry
    let leagueID: Int

    var body: some View {
        HStack {
            Text("\(displayEntry.rank)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 28, alignment: .center)

            Text(displayEntry.entry.team.name)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(displayEntry.played)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 28, alignment: .center)
            Text("\(displayEntry.win)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text("\(displayEntry.draw)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text("\(displayEntry.lose)")
                .font(.system(size: 12)).foregroundColor(.gray)
                .frame(width: 24, alignment: .center)
            Text(goalDiffText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(displayEntry.goalsDiff >= 0 ? Color.green : Color.red)
                .frame(width: 34, alignment: .center)
            Text("\(displayEntry.points)")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(displayEntry.hasLiveMatch ? .oneKickNeon : .white)
                .frame(width: 36, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            if let zone = LeagueMapper.qualificationZone(rank: displayEntry.rank, leagueID: leagueID) {
                zone.color
                    .frame(width: 3)
                    .cornerRadius(1.5)
            }
        }
    }

    private var goalDiffText: String {
        displayEntry.goalsDiff > 0 ? "+\(displayEntry.goalsDiff)" : "\(displayEntry.goalsDiff)"
    }
}

// MARK: - Gruppen-Tabelle (WM, EM)

struct GroupStandingsSheet: View {
    let leagueID: Int
    let leagueName: String

    @Environment(\.dismiss) var dismiss
    @State private var groups: [[StandingEntry]] = []
    @State private var selectedGroupIndex: Int = 0
    @State private var isLoading = true

    private let service = APIFootballService()

    private var currentGroup: [StandingEntry] {
        guard selectedGroupIndex < groups.count else { return [] }
        return groups[selectedGroupIndex]
    }

    private func groupName(at index: Int) -> String {
        if let raw = groups[index].first?.group {
            // "Group A" → "Gr. A", "Gruppe A" → "Gr. A"
            let parts = raw.split(separator: " ")
            return parts.count >= 2 ? "Gr. \(parts.last!)" : raw
        }
        return "Gr. \(index + 1)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if groups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Keine Gruppendaten verfügbar")
                            .font(.headline).foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(groups.indices, id: \.self) { i in
                                    Button(action: { selectedGroupIndex = i }) {
                                        Text(groupName(at: i))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(selectedGroupIndex == i ? .black : .white)
                                            .padding(.horizontal, 14).padding(.vertical, 7)
                                            .background(selectedGroupIndex == i
                                                        ? Color.oneKickNeon
                                                        : Color.oneKickDarkGray)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)

                        // Spaltenüberschriften
                        HStack {
                            Text("#").frame(width: 28, alignment: .center)
                            Text("Verein").frame(maxWidth: .infinity, alignment: .leading)
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

                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)

                        ScrollView {
                            ForEach(Array(currentGroup.enumerated()), id: \.element.team.id) { i, entry in
                                let display = StandingDisplayEntry(id: entry.team.id, rank: entry.rank, entry: entry)
                                StandingRowView(displayEntry: display, leagueID: leagueID)

                                if i < currentGroup.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 0.5)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(leagueName) – Gruppen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
        }
        .task {
            groups = await service.fetchGroupStandings(for: leagueID)
            isLoading = false
        }
    }
}
