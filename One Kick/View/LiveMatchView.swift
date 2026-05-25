//
//  LiveMatchView.swift
//  One Kick
//

import SwiftUI
import Combine

struct LiveMatchView: View {
    let match: MatchData

    @Environment(\.dismiss) var dismiss
    @State private var events: [MatchEvent] = []
    @State private var statistics: [TeamStatistics] = []
    @State private var isLoadingEvents = true
    @State private var isLoadingStats = true
    @State private var selectedTab = 0

    private let service = APIFootballService()
    private var isLive: Bool { ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short) }

    private var computedScore: (home: Int, away: Int) {
        let homeID = match.teams.home.id
        var home = 0, away = 0
        for e in events where e.type == "Goal" {
            if e.detail == "Own Goal" {
                if e.team.id == homeID { away += 1 } else { home += 1 }
            } else {
                if e.team.id == homeID { home += 1 } else { away += 1 }
            }
        }
        return (home: max(home, match.goals.home ?? 0),
                away: max(away, match.goals.away ?? 0))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    matchHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    Picker("", selection: $selectedTab) {
                        Text("Ereignisse").tag(0)
                        Text("Statistiken").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    if selectedTab == 0 {
                        eventsTab
                    } else {
                        statsTab
                    }
                }
            }
            .navigationTitle("Live Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
                if isLive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { Task { await loadData(invalidateCache: true) } }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.oneKickNeon)
                        }
                    }
                }
            }
        }
        .task { await loadData(invalidateCache: false) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard isLive else { return }
            Task { await loadData(invalidateCache: false) }
        }
    }

    // MARK: - Header

    private var matchHeader: some View {
        HStack {
            VStack(spacing: 6) {
                AsyncImage(url: URL(string: match.teams.home.logo)) { img in
                    img.resizable().scaledToFit()
                } placeholder: { Color.clear }
                .frame(width: 40, height: 40)
                Text(match.teams.home.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                if isLive {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("LIVE").font(.system(size: 10, weight: .black)).foregroundColor(.red)
                    }
                }
                Text("\(computedScore.home) : \(computedScore.away)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                if match.fixture.status.short == "HT" {
                    Text("HZ").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                } else if let elapsed = match.fixture.status.elapsed {
                    Text("\(elapsed)'").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
            }

            VStack(spacing: 6) {
                AsyncImage(url: URL(string: match.teams.away.logo)) { img in
                    img.resizable().scaledToFit()
                } placeholder: { Color.clear }
                .frame(width: 40, height: 40)
                Text(match.teams.away.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(14)
    }

    // MARK: - Events Tab

    @ViewBuilder
    private var eventsTab: some View {
        if isLoadingEvents {
            ProgressView().tint(.oneKickNeon).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if events.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock").font(.system(size: 40)).foregroundColor(.gray)
                Text("Noch keine Ereignisse")
                    .font(.headline).foregroundColor(.white)
                Text("Ereignisse erscheinen sobald das Spiel läuft.")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                        LiveEventRow(event: event, homeTeamId: match.teams.home.id)
                        if idx < events.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)
                        }
                    }
                }
                .background(Color.oneKickDarkGray.opacity(0.6))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Stats Tab

    @ViewBuilder
    private var statsTab: some View {
        if isLoadingStats {
            ProgressView().tint(.oneKickNeon).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if statistics.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar").font(.system(size: 40)).foregroundColor(.gray)
                Text("Statistiken noch nicht verfügbar")
                    .font(.headline).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let homeStats = statistics.first(where: { $0.team.id == match.teams.home.id })
            let awayStats = statistics.first(where: { $0.team.id == match.teams.away.id })

            ScrollView {
                if let home = homeStats, let away = awayStats {
                    VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: 6) {
                                AsyncImage(url: URL(string: match.teams.home.logo)) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: { Color.clear }
                                .frame(width: 22, height: 22)
                                Text(match.teams.home.name)
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 6) {
                                Text(match.teams.away.name)
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                    .lineLimit(1)
                                AsyncImage(url: URL(string: match.teams.away.logo)) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: { Color.clear }
                                .frame(width: 22, height: 22)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().background(Color.white.opacity(0.08))

                        ForEach(Array(buildStatRows(home: home, away: away).enumerated()), id: \.offset) { idx, row in
                            LiveStatRow(homeValue: row.home, label: row.label, awayValue: row.away)
                            if idx < buildStatRows(home: home, away: away).count - 1 {
                                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color.oneKickDarkGray.opacity(0.6))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Data

    private func loadData(invalidateCache: Bool) async {
        if invalidateCache {
            isLoadingEvents = true
            isLoadingStats = true
        }
        async let e = service.fetchMatchEvents(for: match.fixture.id, isLive: isLive)
        async let s = service.fetchMatchStatistics(for: match.fixture.id, isLive: isLive)
        let (evts, stats) = await (e, s)
        events = evts
        isLoadingEvents = false
        statistics = stats
        isLoadingStats = false
    }

    private struct StatRow {
        let home: String
        let label: String
        let away: String
    }

    private func buildStatRows(home: TeamStatistics, away: TeamStatistics) -> [StatRow] {
        let keys: [(api: String, label: String)] = [
            ("Ball Possession",  "Ballbesitz"),
            ("Shots on Goal",    "Torschüsse"),
            ("Total Shots",      "Schüsse gesamt"),
            ("Blocked Shots",    "Geblockte Schüsse"),
            ("Shots insidebox",  "Schüsse im Strafraum"),
            ("Shots outsidebox", "Schüsse außerhalb"),
            ("Corner Kicks",     "Ecken"),
            ("Fouls",            "Fouls"),
            ("Offsides",         "Abseits"),
            ("Yellow Cards",     "Gelbe Karten"),
            ("Red Cards",        "Rote Karten"),
            ("Goalkeeper Saves", "Paraden"),
            ("Total passes",     "Pässe gesamt"),
            ("Passes accurate",  "Genaue Pässe"),
            ("Passes %",         "Passquote"),
        ]
        return keys.compactMap { key in
            let h = home.value(for: key.api)
            let a = away.value(for: key.api)
            guard h != "-" || a != "-" else { return nil }
            return StatRow(home: h, label: key.label, away: a)
        }
    }
}

// MARK: - Event Row

struct LiveEventRow: View {
    let event: MatchEvent
    let homeTeamId: Int

    private var isHome: Bool { event.team.id == homeTeamId }

    private var iconName: String {
        switch event.type {
        case "Goal":   return "soccerball"
        case "Card":   return "rectangle.fill"
        case "subst":  return "arrow.left.arrow.right"
        case "Var":    return "tv"
        default:       return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.type {
        case "Goal": return .oneKickNeon
        case "Card":
            if event.detail.contains("Red") { return .red }
            return .yellow
        default: return .gray
        }
    }

    private var subtitle: String? {
        switch event.type {
        case "Goal":
            if let assist = event.assist?.name { return "Vorlage: \(assist)" }
            if event.detail.contains("Own Goal") { return "Eigentor" }
            if event.detail.contains("Penalty")  { return "Elfmeter" }
            return nil
        case "subst":
            let incoming = event.player?.name ?? ""
            let outgoing = event.assist?.name ?? ""
            if !incoming.isEmpty && !outgoing.isEmpty { return "▲ \(incoming)  ▼ \(outgoing)" }
            if !outgoing.isEmpty { return "▼ \(outgoing)" }
            return nil
        default:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Home side
            if isHome {
                eventContent(alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                minuteAndIcon
            } else {
                Color.clear.frame(maxWidth: .infinity)
                minuteAndIcon
                eventContent(alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var minuteAndIcon: some View {
        VStack(spacing: 3) {
            Text("\(event.time.elapsed ?? 0)'")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 22, height: 22)
        }
        .frame(width: 40)
    }

    private func eventContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            // Auswechslungen: Subtitle enthält bereits beide Spieler (▲/▼), kein Haupttext nötig
            if event.type != "subst" {
                Text(event.player?.name ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: event.type == "subst" ? 11 : 10))
                    .foregroundColor(event.type == "subst" ? .white.opacity(0.85) : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Stat Row

struct LiveStatRow: View {
    let homeValue: String
    let label: String
    let awayValue: String

    var body: some View {
        HStack {
            Text(homeValue)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(width: 140)

            Text(awayValue)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
