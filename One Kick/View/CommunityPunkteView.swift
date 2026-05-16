//
//  CommunityPunkteView.swift
//  One Kick
//
//  Hauptview, Tabs und Leaderboard-Zeilen.
//  Models → CommunityPunkteModels.swift
//  ViewModel → CommunityPunkteViewModel.swift
//

import SwiftUI
import FirebaseAuth

// MARK: - Main View

struct CommunityPunkteView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CommunityPunkteViewModel
    @State private var selectedTab = 0   // 0=Spielwoche 1=Ligen 2=Gesamt 3=Bonus
    @State private var weekOffset  = 0   // 0=aktuelle Woche, -1=letzte Woche, …

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    init(community: CommunityModel) {
        self.community = community
        _viewModel = StateObject(wrappedValue: CommunityPunkteViewModel(community: community))
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                tabBar
                Divider().background(Color.white.opacity(0.08))
                contentView
            }
        }
        .navigationBarHidden(true)
        .task { await viewModel.loadData() }
    }

    // MARK: Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold()).foregroundColor(.white)
                    .frame(width: 40, height: 40).background(Color.oneKickDarkGray).clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(community.name).font(.headline).bold().foregroundColor(.white)
                Text("Punkte").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 10)
    }

    // MARK: Tab Bar

    private let tabTitles = ["Spielwoche", "Ligen", "Gesamt", "Bonus"]

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabTitles.enumerated()), id: \.offset) { idx, title in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = idx }
                    if idx == 0 && weekOffset != 0 {
                        weekOffset = 0
                        Task { await viewModel.loadSpielwoche(offset: 0) }
                    }
                }) {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: selectedTab == idx ? .bold : .regular))
                            .foregroundColor(selectedTab == idx ? .oneKickNeon : .gray)
                        Rectangle().frame(height: 2)
                            .foregroundColor(selectedTab == idx ? .oneKickNeon : .clear)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            if viewModel.isLoading {
                loadingPlaceholder("Punkte werden berechnet...")
            } else {
                spielwocheTab
            }
        case 1:
            if viewModel.isLoading || viewModel.isLoadingGesamt {
                loadingPlaceholder("Ligen werden geladen...")
            } else {
                ligenTab
            }
        case 2:
            if viewModel.isLoading || viewModel.isLoadingGesamt {
                loadingPlaceholder("Saison-Punkte werden geladen...")
            } else {
                leaderboardView(entries: viewModel.totalLeaderboard, label: "Gesamte Saison")
            }
        default:
            bonusTab
        }
    }

    @ViewBuilder
    private func loadingPlaceholder(_ text: String) -> some View {
        Spacer()
        ProgressView().tint(.oneKickNeon)
        Text(text).font(.caption).foregroundColor(.gray).padding(.top, 8)
        Spacer()
    }

    // MARK: Leaderboard

    private func leaderboardView(entries: [UserPointsEntry], label: String) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if entries.isEmpty {
                    emptyPlaceholder
                } else {
                    tableHeader(label: label)
                    ForEach(Array(entries.enumerated()), id: \.element.id) { rank, entry in
                        LeaderboardRowView(rank: rank + 1, entry: entry,
                                           isCurrentUser: entry.id == currentUserId)
                    }
                }
                Spacer(minLength: 80)
            }
            .padding(.top, 12)
        }
        .refreshable { await viewModel.loadData() }
    }

    private func tableHeader(label: String) -> some View {
        HStack {
            Text("Tabelle")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                .tracking(1).textCase(.uppercase)
            Spacer()
            Text(label).font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
        }
        .padding(.horizontal, 20).padding(.bottom, 4)
    }

    // MARK: Spielwoche-Tab

    private var spielwocheTab: some View {
        ScrollView {
            LazyVStack(spacing: 6) {

                // Wochen-Navigation
                HStack(spacing: 12) {
                    Button(action: {
                        weekOffset -= 1
                        Task { await viewModel.loadSpielwoche(offset: weekOffset) }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.oneKickNeon)
                            .frame(width: 32, height: 32)
                            .background(Color.oneKickNeon.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12)).foregroundColor(.oneKickNeon)
                        Text(viewModel.currentWeekLabel.isEmpty ? "Lädt…" : viewModel.currentWeekLabel)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.oneKickNeon)
                    }

                    Spacer()

                    Button(action: {
                        weekOffset += 1
                        Task { await viewModel.loadSpielwoche(offset: weekOffset) }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(weekOffset < 0 ? .oneKickNeon : .gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .background(weekOffset < 0 ? Color.oneKickNeon.opacity(0.1) : Color.clear)
                            .clipShape(Circle())
                    }
                    .disabled(weekOffset >= 0)
                }
                .padding(.horizontal, 20).padding(.bottom, 4)

                if viewModel.isLoadingSpielwoche {
                    ProgressView().tint(.oneKickNeon).padding(.top, 40)
                } else if viewModel.weekMatchesByLeague.isEmpty {
                    // Wirklich keine Spiele in dieser Woche
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Keine Spiele diese Woche")
                            .font(.headline).foregroundColor(.white)
                        Text("In dieser Woche finden keine Spiele in deinen Ligen statt.")
                            .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal)
                } else {
                    // Sieger-Banner nur wenn jemand wirklich Punkte hat
                    if let winner = viewModel.spielwocheLeaderboard.first, winner.points > 0 {
                        HStack(spacing: 14) {
                            Text("🏆").font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Spielwoche-Sieger")
                                    .font(.caption.bold()).foregroundColor(.oneKickNeon.opacity(0.8))
                                Text(winner.displayName)
                                    .font(.headline).bold().foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(winner.points)")
                                    .font(.title2).bold().foregroundColor(.oneKickNeon)
                                Text("Punkte").font(.caption2).foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color.oneKickNeon.opacity(0.08))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.oneKickNeon.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 16).padding(.bottom, 4)
                    }

                    tableHeader(label: viewModel.currentWeekLabel)
                    ForEach(Array(viewModel.spielwocheLeaderboard.enumerated()), id: \.element.id) { rank, entry in
                        SpielwocheLeaderboardRowView(
                            rank: rank + 1, entry: entry,
                            isCurrentUser: entry.id == currentUserId,
                            weekMatchesByLeague: viewModel.weekMatchesByLeague
                        )
                    }
                }
                Spacer(minLength: 80)
            }
            .padding(.top, 12)
        }
        .refreshable {
            weekOffset = 0
            await viewModel.loadData()
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3").font(.system(size: 40)).foregroundColor(.gray)
            Text("Noch keine Tipps").font(.headline).foregroundColor(.white)
            Text("Hier erscheint das Leaderboard, sobald Tipps abgegeben wurden.")
                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal)
    }

    // MARK: Ligen-Tab

    private var ligenTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.totalLeaderboard.isEmpty {
                    emptyPlaceholder
                } else {
                    HStack {
                        Text("Ligen")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            .tracking(1).textCase(.uppercase)
                        Spacer()
                        Text("Aktueller Führender")
                            .font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.horizontal, 20).padding(.bottom, 4)

                    ForEach(Array(community.activeLeagues).sorted(), id: \.self) { leagueName in
                        let leader = viewModel.leagueLeader(for: leagueName)
                        NavigationLink(destination: LeagueLeaderboardView(
                            leagueName: leagueName,
                            rankings: viewModel.leagueRanking(for: leagueName),
                            currentUserId: currentUserId
                        )) {
                            LigenOverviewCard(leagueName: leagueName,
                                              leaderName: leader?.name,
                                              leaderPoints: leader?.points,
                                              hasLive: viewModel.liveLeagues.contains(leagueName))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 80)
            }
            .padding(.top, 12)
        }
        .refreshable { await viewModel.loadData() }
    }

    // MARK: Bonus-Tab

    private var bonusTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 28)).foregroundColor(.oneKickNeon)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bonuspunkte").font(.headline).bold().foregroundColor(.white)
                        Text(viewModel.bonusLockedLeagues.isEmpty
                             ? "Tippe vor Saisonstart und sammle Extra-Punkte."
                             : "Gestartete Ligen: Tipps aller Tipper sind sichtbar.")
                            .font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.oneKickNeon.opacity(0.08)).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.oneKickNeon.opacity(0.25), lineWidth: 1))

                if viewModel.isLoadingBonus {
                    ProgressView().tint(.oneKickNeon).padding()
                } else {
                    let enabledCats = community.activeBonusCategories.map { Set($0) }
                    ForEach(Array(community.activeLeagues).sorted(), id: \.self) { leagueName in
                        if viewModel.bonusLockedLeagues.contains(leagueName) {
                            BonusAnswerCard(
                                leagueName:        leagueName,
                                enabledCategories: enabledCats,
                                entries:           viewModel.bonusEntries
                            )
                        } else {
                            BonusLeagueCard(
                                leagueName:        leagueName,
                                enabledCategories: enabledCats
                            )
                        }
                    }
                }
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .task {
            if viewModel.bonusEntries.isEmpty && !viewModel.isLoadingBonus {
                await viewModel.loadBonusData()
            }
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRowView: View {
    let rank: Int
    let entry: UserPointsEntry
    let isCurrentUser: Bool

    var body: some View {
        NavigationLink(destination: PlayerDetailView(entry: entry, isCurrentUser: isCurrentUser)) {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(rankColor)
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
            .background(isCurrentUser ? Color.oneKickNeon.opacity(0.06) : Color.oneKickDarkGray.opacity(0.6))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? Color.oneKickNeon.opacity(0.4) : Color.white.opacity(0.06),
                        lineWidth: isCurrentUser ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
}

// MARK: - Ligen-Übersichts-Kachel

struct LigenOverviewCard: View {
    let leagueName: String
    let leaderName: String?
    let leaderPoints: Int?
    var hasLive: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "soccerball")
                .font(.system(size: 18)).foregroundColor(.gray)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.3)).clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(leagueName).font(.headline).foregroundColor(.white).lineLimit(1)
                    if hasLive { LiveBadge() }
                }
                if let name = leaderName {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundColor(.yellow)
                        Text(name).font(.caption).foregroundColor(.gray)
                    }
                } else {
                    Text("Noch keine Tipps").font(.caption).foregroundColor(.gray.opacity(0.6))
                }
            }

            Spacer()

            if let pts = leaderPoints {
                Text("\(pts) Pkt").font(.subheadline).bold().foregroundColor(.oneKickNeon)
            }

            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.oneKickDarkGray).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Spielwoche-Leaderboard-Zeile

struct SpielwocheLeaderboardRowView: View {
    let rank: Int
    let entry: UserPointsEntry
    let isCurrentUser: Bool
    let weekMatchesByLeague: [String: [MatchData]]

    var body: some View {
        NavigationLink(destination: SpielwochePlayerDetailView(
            entry: entry,
            weekMatchesByLeague: weekMatchesByLeague,
            isCurrentUser: isCurrentUser
        )) {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(rankColor)
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
            .background(isCurrentUser ? Color.oneKickNeon.opacity(0.06) : Color.oneKickDarkGray.opacity(0.6))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? Color.oneKickNeon.opacity(0.4) : Color.white.opacity(0.06),
                        lineWidth: isCurrentUser ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
}
