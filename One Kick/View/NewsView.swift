//
//  NewsView.swift
//  One Kick
//

import SwiftUI

// MARK: - NewsView

struct NewsView: View {
    @EnvironmentObject var newsService: NewsService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var lm: LanguageManager
    @State private var showProfileSheet = false
    @State private var selectedTab: NewsTab = .news
    @State private var favoritesOnly = false
    @State private var hasLoadedTransfers = false
    @State private var injuries: [InjuryData] = []
    @State private var isLoadingInjuries = false
    @State private var hasLoadedInjuries = false

    private let injuryService = APIFootballService()

    enum NewsTab: String, CaseIterable {
        case news = "News"
        case transfers = "Transfers"
        case injuries = "Injuries"

        var localizedLabel: String {
            switch self {
            case .news:      return LanguageManager.shared.t("tab.news")
            case .transfers: return LanguageManager.shared.t("news.transfers")
            case .injuries:  return "Injuries"
            }
        }
    }

    private var settings: UserSettings { UserSettings.shared }

    private var allCommunityLeagueNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for community in communityManager.communities {
            for name in community.activeLeagues where seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names
    }

    private var favoriteLeagueNames: [String] {
        settings.favoriteLeagueIds.compactMap { LeagueMapper.getName(for: $0) }
    }

    private var effectiveTeamNames: [String] { settings.favoriteTeams.map(\.name) }

    private var effectiveLeagueNames: [String] {
        if favoritesOnly {
            return favoriteLeagueNames
        }
        return Array(Set(allCommunityLeagueNames + favoriteLeagueNames))
    }

    private var hasFavorites: Bool {
        !settings.favoriteTeams.isEmpty || !settings.favoriteLeagueIds.isEmpty
    }

    private var isLoading: Bool {
        switch selectedTab {
        case .news:      return newsService.isLoadingPersonalized
        case .transfers: return newsService.isLoadingTransfers
        case .injuries:  return isLoadingInjuries
        }
    }

    private var currentArticles: [NewsArticle] {
        switch selectedTab {
        case .news:      return newsService.personalizedArticles
        case .transfers: return newsService.transferArticles
        case .injuries:  return []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    OneKickHeader(onProfile: {
                        HapticManager.instance.impact(style: .light)
                        showProfileSheet = true
                    })

                    tabPicker
                    filterRow

                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView().tint(.oneKickNeon).padding(.top, 50)
                                Text("Lade \(selectedTab.rawValue)…")
                                    .foregroundColor(.gray).font(.caption)
                            } else if selectedTab == .injuries {
                                injuriesContent
                            } else if currentArticles.isEmpty {
                                emptyState
                            } else {
                                ForEach(currentArticles) { article in
                                    if let url = URL(string: article.url) {
                                        Link(destination: url) {
                                            NewsCard(article: article)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Spacer(minLength: 80)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfileSheet) { ProfileView() }
            .task { await loadNews() }
            .onChange(of: favoritesOnly) { Task { await reloadCurrent() } }
            .onChange(of: selectedTab) {
                Task {
                    if selectedTab == .transfers && !hasLoadedTransfers {
                        await reloadTransfers()
                        hasLoadedTransfers = true
                    } else if selectedTab == .injuries && !hasLoadedInjuries {
                        await loadInjuries()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(NewsTab.allCases.filter { $0 != .injuries }, id: \.self) { tab in
                Button(action: {
                    HapticManager.instance.impact(style: .light)
                    selectedTab = tab
                }) {
                    Text(tab.localizedLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(selectedTab == tab ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selectedTab == tab ? Color.oneKickNeon : Color.oneKickDarkGray.opacity(0.6))
                        .cornerRadius(22)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundColor(favoritesOnly ? .oneKickNeon : .gray)

            Text(lm.t("news.onlyFavorites"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(favoritesOnly ? .oneKickNeon : .gray)

            Toggle("", isOn: $favoritesOnly)
                .labelsHidden()
                .tint(.oneKickNeon)
                .scaleEffect(0.8)

            Spacer()

            if favoritesOnly && !hasFavorites {
                NavigationLink(destination: FavoriteSettingsView()) {
                    HStack(spacing: 4) {
                        Text("Keine Favoriten gesetzt")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            } else if favoritesOnly {
                NavigationLink(destination: FavoriteSettingsView()) {
                    HStack(spacing: 4) {
                        Text("Lieblingsligen & -teams")
                            .font(.system(size: 11))
                            .foregroundColor(.oneKickNeon.opacity(0.8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.oneKickNeon.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(lm.t("news.allLeagues"))
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var injuriesContent: some View {
        if injuries.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "cross.circle").font(.system(size: 40)).foregroundColor(.gray)
                Text("Keine Verletzungen gefunden").font(.headline).foregroundColor(.white)
                Text("Aktuell sind keine Verletzungen oder Sperren für deine aktiven Ligen bekannt.")
                    .font(.caption).foregroundColor(.gray)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        } else {
            // Verletzungen nach Team gruppiert
            let grouped = Dictionary(grouping: injuries, by: { $0.team.name })
                .sorted(by: { $0.key < $1.key })
            ForEach(grouped, id: \.key) { teamName, teamInjuries in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(teamName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(teamInjuries.enumerated()), id: \.offset) { _, injury in
                        InjuryCard(injury: injury)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: selectedTab == .news ? "newspaper" : "arrow.left.arrow.right.circle")
                .font(.system(size: 40)).foregroundColor(.gray)
            Text("Keine \(selectedTab.rawValue) gefunden")
                .font(.headline).foregroundColor(.white)
            if favoritesOnly && !hasFavorites {
                Text("Füge Lieblingsteams oder Lieblingsligen in deinem Profil hinzu.")
                    .font(.caption).foregroundColor(.gray)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            } else {
                Text("Aktuell sind keine Artikel verfügbar.")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data loading

    private func loadNews() async {
        await newsService.fetchPersonalizedNews(
            teamNames: effectiveTeamNames,
            leagueNames: effectiveLeagueNames
        )
    }

    private func reloadTransfers() async {
        await newsService.fetchTransferNews(
            teamNames: effectiveTeamNames,
            leagueNames: effectiveLeagueNames
        )
    }

    private func reloadCurrent() async {
        switch selectedTab {
        case .news:
            await newsService.fetchPersonalizedNews(
                teamNames: effectiveTeamNames,
                leagueNames: effectiveLeagueNames
            )
        case .transfers:
            await newsService.fetchTransferNews(
                teamNames: effectiveTeamNames,
                leagueNames: effectiveLeagueNames
            )
        case .injuries:
            await loadInjuries()
        }
    }

    private func loadInjuries() async {
        isLoadingInjuries = true
        let leagueIds = Array(Set(allCommunityLeagueNames.map { LeagueMapper.getID(for: $0) }))
        var all: [InjuryData] = []

        await withTaskGroup(of: [InjuryData].self) { group in
            for id in leagueIds {
                group.addTask { await self.injuryService.fetchInjuries(for: id) }
            }
            for await result in group { all.append(contentsOf: result) }
        }

        // Nur Einträge der letzten 60 Tage, Duplikate per Spieler-ID entfernen
        let cutoff = Date().addingTimeInterval(-60 * 24 * 3600).timeIntervalSince1970
        let recent = all.filter { ($0.fixture?.timestamp.map(Double.init) ?? 0) >= cutoff }

        var seen = Set<Int>()
        var unique: [InjuryData] = []
        for injury in recent.sorted(by: {
            ($0.fixture?.timestamp ?? 0) > ($1.fixture?.timestamp ?? 0)
        }) {
            if seen.insert(injury.player.id).inserted { unique.append(injury) }
        }

        injuries = unique
        isLoadingInjuries = false
        hasLoadedInjuries = true
    }
}

// MARK: - InjuryCard

struct InjuryCard: View {
    let injury: InjuryData

    private var isSuspension: Bool { injury.player.type == "Suspension" }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(injury.player.name)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                if let reason = injury.player.reason {
                    Text(reason)
                        .font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                }
            }

            Spacer()

            Text(isSuspension ? "Sperre" : "Verletzt")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isSuspension ? .yellow : .red)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((isSuspension ? Color.yellow : Color.red).opacity(0.15))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - NewsCard

struct NewsCard: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2).frame(height: 120)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(article.source.name.uppercased())
                    .font(.caption).bold().foregroundColor(.oneKickNeon)

                Text(article.title)
                    .font(.headline).bold().foregroundColor(.white).lineLimit(3)

                Text("Mehr lesen")
                    .font(.caption).foregroundColor(.gray).padding(.top, 4)
            }
            .padding(16)
            .background(Color.oneKickDarkGray)
        }
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
