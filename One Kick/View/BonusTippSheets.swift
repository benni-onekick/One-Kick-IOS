//
//  BonusTippSheets.swift
//  One Kick
//
//  Picker-Sheets für Bonus-Tipps: Spielersuche, Team-Picker, Endtabelle, Finalisten.
//

import SwiftUI

// MARK: - Spielersuche

struct PlayerSearchSheet: View {
    let leagueName:           String
    let category:             String
    let currentAnswer:        String
    let onSelect:             (String) -> Void
    let searchPlayers:        (String) async -> [PlayerBasicInfo]
    let isNationalTeamLeague: Bool

    @Environment(\.dismiss) var dismiss
    @State private var query:        String = ""
    @State private var results:      [PlayerBasicInfo] = []
    @State private var isSearching   = false
    @State private var selectedName: String

    init(leagueName: String, category: String = "Torschützenkönig", currentAnswer: String,
         onSelect: @escaping (String) -> Void,
         searchPlayers: @escaping (String) async -> [PlayerBasicInfo],
         isNationalTeamLeague: Bool = false) {
        self.leagueName           = leagueName
        self.category             = category
        self.currentAnswer        = currentAnswer
        self.onSelect             = onSelect
        self.searchPlayers        = searchPlayers
        self.isNationalTeamLeague = isNationalTeamLeague
        _selectedName             = State(initialValue: currentAnswer)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isNationalTeamLeague {
                    manualInputView
                } else {
                    searchView
                }
            }
            .navigationTitle("\(category) – \(leagueName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var manualInputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Spieler suchen …", text: $query)
                    .foregroundColor(.white)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.oneKickDarkGray)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !selectedName.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.oneKickNeon)
                    Text("Aktuell: \(selectedName)").font(.caption).foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if query.count < 2 {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40)).foregroundColor(.gray)
                    Text("Mindestens 2 Buchstaben eingeben")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
            } else {
                let filtered = wmAllPlayerNames.filter {
                    $0.localizedCaseInsensitiveContains(query)
                }
                if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("Kein Spieler gefunden")
                            .font(.subheadline).foregroundColor(.gray)
                        Button(action: {
                            let name = query.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            onSelect(name)
                            dismiss()
                        }) {
                            Text("\"\(query.trimmingCharacters(in: .whitespaces))\" trotzdem speichern")
                                .font(.caption).foregroundColor(.oneKickNeon)
                        }
                    }
                    Spacer()
                } else {
                    List(filtered, id: \.self) { name in
                        Button(action: {
                            selectedName = name
                            onSelect(name)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "person.fill").foregroundColor(.gray)
                                Text(name).foregroundColor(.white)
                                Spacer()
                                if name == selectedName {
                                    Image(systemName: "checkmark").foregroundColor(.oneKickNeon)
                                }
                            }
                        }
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Spieler suchen …", text: $query)
                    .foregroundColor(.white)
                    .onChange(of: query) { _, val in
                        if val.count >= 3 {
                            Task { await runSearch(val) }
                        } else {
                            results = []
                        }
                    }
                if !query.isEmpty {
                    Button(action: { query = ""; results = [] }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.oneKickDarkGray)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !selectedName.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.oneKickNeon)
                    Text("Aktuell: \(selectedName)").font(.caption).foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if isSearching {
                Spacer()
                ProgressView().tint(.oneKickNeon)
                Spacer()
            } else if query.count < 3 {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40)).foregroundColor(.gray)
                    Text("Mindestens 3 Buchstaben eingeben")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text("Kein Spieler gefunden")
                    .font(.subheadline).foregroundColor(.gray)
                Spacer()
            } else {
                List(results) { player in
                    Button(action: {
                        selectedName = player.name
                        onSelect(player.name)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.fill").foregroundColor(.gray)
                            Text(player.name).foregroundColor(.white)
                            Spacer()
                            if player.name == selectedName {
                                Image(systemName: "checkmark").foregroundColor(.oneKickNeon)
                            }
                        }
                    }
                    .listRowBackground(Color.oneKickDarkGray)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func runSearch(_ query: String) async {
        isSearching = true
        results     = await searchPlayers(query)
        isSearching = false
    }
}

// MARK: - Team-Picker (Einzelauswahl)

struct TeamPickerSheet: View {
    let leagueName:    String
    let category:      String
    let teams:         [StandingEntry]
    let currentAnswer: String
    let onSelect:      (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selected: String

    init(leagueName: String, category: String, teams: [StandingEntry],
         currentAnswer: String, onSelect: @escaping (String) -> Void) {
        self.leagueName    = leagueName
        self.category      = category
        self.teams         = teams
        self.currentAnswer = currentAnswer
        self.onSelect      = onSelect
        _selected          = State(initialValue: currentAnswer)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if teams.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Keine Tabellendaten verfügbar")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                } else {
                    List(teams, id: \.team.id) { entry in
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            selected = entry.team.name
                            onSelect(entry.team.name)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Text(teamNameWithFlag(entry.team.name)).foregroundColor(.white).lineLimit(1)
                                Spacer()
                                if entry.team.name == selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.oneKickNeon)
                                }
                            }
                        }
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Endtabelle (sequenziell)

struct TableRankingSheet: View {
    let leagueName:    String
    let teams:         [StandingEntry]
    let currentAnswer: String
    let onSave:        ([String]) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var ranking: [String]

    init(leagueName: String, teams: [StandingEntry],
         currentAnswer: String, onSave: @escaping ([String]) -> Void) {
        self.leagueName    = leagueName
        self.teams         = teams
        self.currentAnswer = currentAnswer
        self.onSave        = onSave
        let existing       = currentAnswer.isEmpty ? [] : currentAnswer.components(separatedBy: ",")
        _ranking           = State(initialValue: existing)
    }

    /// Overload für [String]-Teamnamen (z.B. WM-Gruppen) – baut intern StandingEntry-Dummies.
    init(leagueName: String, teamNames: [String],
         currentAnswer: String, onSave: @escaping ([String]) -> Void) {
        let dummy = StandingStats(played: 0, win: 0, draw: 0, lose: 0,
                                  goals: StandingGoals(for: 0, against: 0))
        let entries = teamNames.enumerated().map { i, name in
            StandingEntry(rank: i + 1, team: StandingTeam(id: i, name: name, logo: ""),
                          points: 0, goalsDiff: 0, form: nil, all: dummy, group: nil)
        }
        self.init(leagueName: leagueName, teams: entries,
                  currentAnswer: currentAnswer, onSave: onSave)
    }

    private var totalTeams:     Int                { teams.count }
    private var pickedSet:      Set<String>        { Set(ranking) }
    private var remainingTeams: [StandingEntry]    { teams.filter { !pickedSet.contains($0.team.name) } }
    private var isComplete:     Bool               { ranking.count == totalTeams && totalTeams > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressHeader
                    if teams.isEmpty {
                        Spacer()
                        Text("Keine Tabellendaten verfügbar")
                            .font(.subheadline).foregroundColor(.gray)
                        Spacer()
                    } else if isComplete {
                        completedView
                    } else {
                        pickList
                    }

                    if !ranking.isEmpty {
                        saveButton
                    }
                }
            }
            .navigationTitle("Endtabelle – \(leagueName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isComplete
                     ? "Tabelle vollständig!"
                     : "Platz \(ranking.count + 1) von \(totalTeams) wählen")
                    .font(.subheadline)
                    .foregroundColor(isComplete ? .oneKickNeon : .white)
                Spacer()
                if !ranking.isEmpty {
                    Button("Zurücksetzen") {
                        HapticManager.instance.impact(style: .medium)
                        ranking = []
                    }
                    .font(.caption).foregroundColor(.red)
                }
            }

            if !ranking.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(ranking.enumerated()), id: \.offset) { idx, name in
                            HStack(spacing: 4) {
                                Text("\(idx + 1).").font(.caption2.bold()).foregroundColor(.gray)
                                Text(name).font(.caption).foregroundColor(.white)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.oneKickDarkGray).cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.oneKickDarkGray.opacity(0.5))
    }

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50)).foregroundColor(.oneKickNeon)
            Text("Tabelle vollständig!").font(.headline).foregroundColor(.white)
            Text("Tippe auf Speichern um zu bestätigen.")
                .font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pickList: some View {
        List(remainingTeams, id: \.team.id) { entry in
            Button(action: {
                HapticManager.instance.impact(style: .light)
                ranking.append(entry.team.name)
            }) {
                HStack(spacing: 12) {
                    Text(teamNameWithFlag(entry.team.name)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundColor(.oneKickNeon.opacity(0.6))
                }
            }
            .listRowBackground(Color.oneKickDarkGray)
        }
        .scrollContentBackground(.hidden)
    }

    private var saveButton: some View {
        Button(action: { onSave(ranking); dismiss() }) {
            Text(isComplete
                 ? "Speichern"
                 : "Bisher speichern (\(ranking.count)/\(totalTeams))")
                .font(.headline.bold()).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding()
                .background(Color.oneKickNeon).cornerRadius(14)
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }
}

// MARK: - Finalist-Picker (KO-Ligen)

struct FinalistPickerSheet: View {
    let leagueName:    String
    let category:      String
    let count:         Int
    let teams:         [StandingEntry]
    let currentAnswer: String
    let onSave:        ([String]) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var textSlots: [String]

    init(leagueName: String, category: String, count: Int, teams: [StandingEntry],
         currentAnswer: String, onSave: @escaping ([String]) -> Void) {
        self.leagueName    = leagueName
        self.category      = category
        self.count         = count
        self.teams         = teams
        self.currentAnswer = currentAnswer
        self.onSave        = onSave
        let parts = currentAnswer.isEmpty ? [] : currentAnswer.components(separatedBy: ",")
        var slots = Array(repeating: "", count: count)
        for (i, p) in parts.enumerated() where i < count { slots[i] = p }
        _textSlots = State(initialValue: slots)
    }

    private var isComplete: Bool {
        textSlots.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count == count
    }
    private var title: String {
        switch count {
        case 1:  return "Sieger"
        case 2:  return "Finalisten"
        default: return "Halbfinalisten"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if teams.isEmpty {
                    freeTextContent
                } else {
                    slotPickerContent
                }
            }
            .navigationTitle("\(title) – \(leagueName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var slotPickerContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(0..<count, id: \.self) { i in
                    let label = count == 1 ? "Sieger"
                              : count == 2 ? "Finalist \(i + 1)"
                              : "Halbfinalist \(i + 1)"
                    HStack {
                        Text(label).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $textSlots[i]) {
                            Text("– wählen –").tag("")
                            ForEach(teams, id: \.team.id) { entry in
                                Text(teamNameWithFlag(entry.team.name)).tag(entry.team.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.oneKickNeon)
                    }
                    .listRowBackground(Color.oneKickDarkGray)
                }
            }
            .scrollContentBackground(.hidden)

            Button(action: { onSave(textSlots.filter { !$0.isEmpty }); dismiss() }) {
                Text("Speichern")
                    .font(.headline.bold()).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(isComplete ? Color.oneKickNeon : Color.gray.opacity(0.4))
                    .cornerRadius(14)
            }
            .disabled(!isComplete)
            .padding(.horizontal, 16).padding(.bottom, 20)
        }
    }

    private var freeTextContent: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Mannschaften eingeben")
                    .foregroundColor(.gray).font(.caption).bold()) {
                    ForEach(0..<count, id: \.self) { i in
                        HStack(spacing: 10) {
                            Text("\(i + 1).")
                                .font(.caption.bold()).foregroundColor(.gray)
                                .frame(width: 20)
                            TextField("Teamname …", text: $textSlots[i])
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Button(action: {
                onSave(textSlots.map { $0.trimmingCharacters(in: .whitespaces) })
                dismiss()
            }) {
                Text("Speichern")
                    .font(.headline.bold()).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(isComplete ? Color.oneKickNeon : Color.gray.opacity(0.4))
                    .cornerRadius(14)
            }
            .disabled(!isComplete)
            .padding(.horizontal, 16).padding(.bottom, 20)
        }
    }
}

// MARK: - WM/EM Gruppenphase-Tabelle (alle Gruppen)

/// Eine Gruppe aus der API-Tabelle, gruppiert für das Bonus-Tippen.
private struct WmGroupInfo: Identifiable {
    let id: String          // Speicher-Key, z.B. "Weltmeisterschaft|WM Gruppe A"
    let title: String       // Anzeige, z.B. "Gruppe A"
    let teams: [String]     // API-Teamnamen (englisch)
}

struct WmGroupsSheet: View {
    let leagueName: String
    @Binding var answers: [String: String]
    var onSaved: () -> Void = {}
    @Environment(\.dismiss) var dismiss

    @State private var groups: [WmGroupInfo] = []
    @State private var isLoading = true
    @State private var activeGroup: WmGroupInfo? = nil
    private let api = APIFootballService()

    private var tippedCount: Int {
        groups.filter { !(answers[$0.id] ?? "").isEmpty }.count
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
                        Text("Noch keine Gruppendaten verfügbar")
                            .font(.headline).foregroundColor(.white)
                        Text("Die Gruppen erscheinen, sobald die Auslosung in den Tabellen verfügbar ist.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("\(tippedCount)/\(groups.count) Gruppen getippt")
                                    .font(.caption)
                                    .foregroundColor(tippedCount == groups.count ? .oneKickNeon : .gray)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)

                            ForEach(Array(groups.enumerated()), id: \.element.id) { idx, group in
                                let answer = answers[group.id] ?? ""
                                Button(action: { activeGroup = group }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(answer.isEmpty ? Color.oneKickDarkGray : Color.oneKickNeon.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Text(String(group.title.last ?? "?"))
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(answer.isEmpty ? .gray : .oneKickNeon)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(group.title)
                                                .font(.subheadline).bold().foregroundColor(.white)
                                            if answer.isEmpty {
                                                Text("Noch nicht getippt")
                                                    .font(.caption).foregroundColor(.gray.opacity(0.6))
                                            } else {
                                                let ranked = answer.components(separatedBy: ",")
                                                    .map { localizedTeamName($0.trimmingCharacters(in: .whitespaces)) }
                                                Text(ranked.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "  "))
                                                    .font(.caption).foregroundColor(.oneKickNeon).lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if idx < groups.count - 1 {
                                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Gruppenphase Tabelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(item: $activeGroup) { group in
                GroupRankingSheet(
                    groupTitle: group.title,
                    teams: group.teams,
                    currentAnswer: answers[group.id] ?? "",
                    onSave: {
                        answers[group.id] = $0.joined(separator: ",")
                        onSaved()
                    }
                )
            }
        }
        .task { await loadGroups() }
    }

    /// Lädt die Gruppen aus der API-Tabelle (identisch zur „Tabelle"-Ansicht).
    private func loadGroups() async {
        let lid = LeagueMapper.getID(for: leagueName)
        let raw = await api.fetchGroupStandings(for: lid)
        groups = raw.compactMap { entries in
            guard let first = entries.first else { return nil }
            let letter = (first.group ?? "").split(separator: " ").last.map(String.init) ?? ""
            // Nur echte Gruppen mit einzelnem Buchstaben (A–L) – filtert API-Artefakte wie „… Teams".
            guard letter.count == 1, let ch = letter.first, ch.isLetter else { return nil }
            let upper = letter.uppercased()
            return WmGroupInfo(
                id: "\(leagueName)|WM Gruppe \(upper)",
                title: "Gruppe \(upper)",
                teams: entries.map { $0.team.name }
            )
        }
        isLoading = false
    }
}

// MARK: - Gruppen-Ranking-Picker (Dropdown pro Platz)

struct GroupRankingSheet: View {
    let groupTitle: String
    let teams: [String]            // API-Teamnamen
    let currentAnswer: String
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var slots: [String]

    init(groupTitle: String, teams: [String], currentAnswer: String, onSave: @escaping ([String]) -> Void) {
        self.groupTitle = groupTitle
        self.teams = teams
        self.currentAnswer = currentAnswer
        self.onSave = onSave
        let parts = currentAnswer.isEmpty ? [] : currentAnswer.components(separatedBy: ",")
        var s = Array(repeating: "", count: teams.count)
        for (i, p) in parts.enumerated() where i < teams.count {
            s[i] = p.trimmingCharacters(in: .whitespaces)
        }
        _slots = State(initialValue: s)
    }

    private var isComplete: Bool {
        !teams.isEmpty && slots.allSatisfy { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                VStack(spacing: 0) {
                    List {
                        ForEach(0..<teams.count, id: \.self) { i in
                            HStack {
                                Text("\(i + 1). Platz").foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $slots[i]) {
                                    Text("– wählen –").tag("")
                                    ForEach(teams, id: \.self) { team in
                                        Text(teamNameWithFlag(team)).tag(team)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.oneKickNeon)
                            }
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }
                    .scrollContentBackground(.hidden)

                    Button(action: { onSave(slots); dismiss() }) {
                        Text("Speichern")
                            .font(.headline.bold()).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding()
                            .background(isComplete ? Color.oneKickNeon : Color.gray.opacity(0.4))
                            .cornerRadius(14)
                    }
                    .disabled(!isComplete)
                    .padding(.horizontal, 16).padding(.bottom, 20)
                }
            }
            .navigationTitle(groupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}
