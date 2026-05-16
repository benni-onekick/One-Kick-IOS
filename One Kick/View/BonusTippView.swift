//
//  BonusTippView.swift
//  One Kick
//
//  Bonus-Tipp-Eingabe für alle Mitglieder.
//  Picker-Sheets → BonusTippSheets.swift
//

import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Sheet-Identifikator

struct BonusSheet: Identifiable {
    let id = UUID()
    let leagueName: String
    let category: String
    let isKO: Bool
}

// MARK: - ViewModel

@MainActor
class BonusTippViewModel: ObservableObject {
    @Published var answers:             [String: String]          = [:]
    @Published var standingsPerLeague:  [String: [StandingEntry]] = [:]
    @Published var lockedLeagues:       Set<String>               = []
    @Published var isLoading  = true
    @Published var isSaving   = false
    @Published var saveSuccess = false

    let community: CommunityModel
    private let api          = APIFootballService()
    private let bonusManager = BonusBetManager()

    init(community: CommunityModel) {
        self.community = community
    }

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let cid = community.id else { isLoading = false; return }

        async let existingAnswers = bonusManager.loadBonusAnswers(communityId: cid, userId: uid)

        typealias LResult = (name: String, entries: [StandingEntry], locked: Bool)
        var standings: [String: [StandingEntry]] = [:]
        var locked = Set<String>()

        await withTaskGroup(of: LResult.self) { group in
            for leagueName in community.activeLeagues {
                group.addTask {
                    let lid     = LeagueMapper.getID(for: leagueName)
                    let max     = LeagueMapper.getMaxMatchday(for: leagueName)
                    let entries = await self.api.fetchStandings(for: lid)
                    let round   = await self.api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)
                    var isLocked = round.matchday > 1 ||
                        round.matches.contains { !["NS", "TBD"].contains($0.fixture.status.short) }
                    if !isLocked && max == 0 {
                        let iso = ISO8601DateFormatter()
                        let from = String(iso.string(from: Date().addingTimeInterval(-90 * 86400)).prefix(10))
                        let to   = String(iso.string(from: Date()).prefix(10))
                        let recent = await self.api.fetchMatchesByDateRange(for: lid, from: from, to: to)
                        let done: Set<String> = ["FT", "AET", "PEN", "AWD", "WO", "1H", "2H", "HT", "ET", "P", "LIVE"]
                        if recent.contains(where: { done.contains($0.fixture.status.short) }) {
                            isLocked = true
                        }
                    }
                    return (name: leagueName, entries: entries, locked: isLocked)
                }
            }
            for await r in group {
                if !r.entries.isEmpty { standings[r.name] = r.entries }
                if r.locked { locked.insert(r.name) }
            }
        }

        answers            = await existingAnswers
        standingsPerLeague = standings
        lockedLeagues      = locked
        isLoading          = false
    }

    func save() {
        guard let uid = Auth.auth().currentUser?.uid,
              let cid = community.id else { return }
        isSaving = true
        let filtered = answers.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        Task {
            do {
                try await bonusManager.saveBonusAnswers(
                    communityId:  cid,
                    targetUserId: uid,
                    answers:      filtered,
                    adminId:      uid
                )
                isSaving    = false
                saveSuccess = true
                HapticManager.instance.notification(type: .success)
                try? await Task.sleep(for: .seconds(1.5))
                saveSuccess = false
            } catch {
                isSaving = false
            }
        }
    }

    func searchPlayers(in leagueName: String, query: String) async -> [PlayerBasicInfo] {
        let lid = LeagueMapper.getID(for: leagueName)
        return await api.searchPlayers(in: lid, query: query)
    }

    func teams(for leagueName: String) -> [StandingEntry] {
        standingsPerLeague[leagueName] ?? []
    }

    func answeredCount(for leagueName: String, categories: [String]) -> Int {
        categories.filter { !(answers["\(leagueName)|\($0)"] ?? "").isEmpty }.count
    }
}

// MARK: - Main View

struct BonusTippView: View {
    let community: CommunityModel
    @StateObject private var vm: BonusTippViewModel
    @Environment(\.dismiss) var dismiss
    @State private var activeSheet: BonusSheet?

    private let koLeagues: Set<String> = [
        "Champions League", "Europa League", "Conference League",
        "DFB-Pokal", "FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France",
        "Weltmeisterschaft", "Europameisterschaft", "Nations League",
        "WM Qualifikation", "EM Qualifikation",
        "Frauen Champions League", "Frauen WM", "Frauen EM"
    ]

    private var activeCategorySet: Set<String> {
        community.activeBonusCategories.map { Set($0) } ?? Set(allBonusCategories)
    }

    init(community: CommunityModel) {
        self.community = community
        _vm = StateObject(wrappedValue: BonusTippViewModel(community: community))
    }

    private var editableLeagues: [String] {
        community.activeLeagues.sorted().filter { !vm.lockedLeagues.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if editableLeagues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 60)).foregroundColor(.gray)
                        Text("Tipps gesperrt")
                            .font(.headline).foregroundColor(.white)
                        Text("Alle Ligen haben bereits begonnen.\nDie Bonus-Tipps sind in der Punkteübersicht für alle sichtbar.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !vm.lockedLeagues.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12)).foregroundColor(.gray)
                                    Text("\(vm.lockedLeagues.count) Liga(en) bereits gestartet und gesperrt.")
                                        .font(.caption).foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.oneKickDarkGray.opacity(0.6))
                                .cornerRadius(12)
                            }

                            ForEach(editableLeagues, id: \.self) { leagueName in
                                let isKO = koLeagues.contains(leagueName)
                                let cats = categories(for: leagueName, isKO: isKO)
                                if !cats.isEmpty {
                                    BonusTippLeagueSection(
                                        leagueName: leagueName,
                                        categories:  cats,
                                        isKO:        isKO,
                                        answers:     vm.answers,
                                        onTap: { category in
                                            activeSheet = BonusSheet(
                                                leagueName: leagueName,
                                                category:   category,
                                                isKO:       isKO
                                            )
                                        }
                                    )
                                }
                            }
                            Spacer(minLength: 60)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Bonus Tipps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: vm.save) {
                        if vm.isSaving {
                            ProgressView().tint(.oneKickNeon).scaleEffect(0.8)
                        } else {
                            Text(vm.saveSuccess ? "✓ Gespeichert" : "Speichern")
                                .font(.headline)
                                .foregroundColor(vm.saveSuccess ? .green : .oneKickNeon)
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetView(for: sheet)
            }
        }
        .task { await vm.load() }
    }

    private func categories(for leagueName: String, isKO: Bool) -> [String] {
        var cats: [String] = isKO
            ? ["Finalisten tippen", "Halbfinalisten tippen"]
            : ["Torschützenkönig", "Meiste Tore (Team)", "Meiste Gegentore", "Endtabelle"]
        cats += ["Meiste Aluminium-Treffer", "Meiste Karten", "Meiste Zu-Null-Spiele"]
        return cats.filter { activeCategorySet.contains($0) }
    }

    @ViewBuilder
    private func sheetView(for sheet: BonusSheet) -> some View {
        let key   = "\(sheet.leagueName)|\(sheet.category)"
        let teams = vm.teams(for: sheet.leagueName)

        switch sheet.category {
        case "Torschützenkönig":
            PlayerSearchSheet(
                leagueName:    sheet.leagueName,
                currentAnswer: vm.answers[key] ?? "",
                onSelect:      { vm.answers[key] = $0 },
                searchPlayers: { await vm.searchPlayers(in: sheet.leagueName, query: $0) }
            )
        case "Endtabelle":
            TableRankingSheet(
                leagueName:    sheet.leagueName,
                teams:         teams,
                currentAnswer: vm.answers[key] ?? "",
                onSave:        { vm.answers[key] = $0.joined(separator: ",") }
            )
        case "Finalisten tippen":
            FinalistPickerSheet(
                leagueName:    sheet.leagueName,
                category:      sheet.category,
                count:         2,
                teams:         teams,
                currentAnswer: vm.answers[key] ?? "",
                onSave:        { vm.answers[key] = $0.joined(separator: ",") }
            )
        case "Halbfinalisten tippen":
            FinalistPickerSheet(
                leagueName:    sheet.leagueName,
                category:      sheet.category,
                count:         4,
                teams:         teams,
                currentAnswer: vm.answers[key] ?? "",
                onSave:        { vm.answers[key] = $0.joined(separator: ",") }
            )
        default:
            TeamPickerSheet(
                leagueName:    sheet.leagueName,
                category:      sheet.category,
                teams:         teams,
                currentAnswer: vm.answers[key] ?? "",
                onSelect:      { vm.answers[key] = $0 }
            )
        }
    }
}

// MARK: - Liga-Abschnitt

struct BonusTippLeagueSection: View {
    let leagueName: String
    let categories: [String]
    let isKO:       Bool
    let answers:    [String: String]
    let onTap:      (String) -> Void

    @State private var isExpanded = true

    private var answeredCount: Int {
        categories.filter { !(answers["\(leagueName)|\($0)"] ?? "").isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isKO ? "trophy.circle.fill" : "soccerball")
                        .font(.system(size: 18))
                        .foregroundColor(isKO ? .yellow : .oneKickNeon)

                    Text(leagueName)
                        .font(.headline).bold().foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(answeredCount)/\(categories.count)")
                        .font(.caption.bold())
                        .foregroundColor(answeredCount == categories.count ? .oneKickNeon : .gray)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundColor(.gray)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { idx, category in
                        let key    = "\(leagueName)|\(category)"
                        let answer = answers[key] ?? ""

                        Button(action: { onTap(category) }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category)
                                        .font(.subheadline).foregroundColor(.white)
                                    if answer.isEmpty {
                                        Text("Noch nicht getippt")
                                            .font(.caption).foregroundColor(.gray.opacity(0.6))
                                    } else {
                                        Text(answer)
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if idx < categories.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
