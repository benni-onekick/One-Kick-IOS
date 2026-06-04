import SwiftUI

private let allBonusCategoriesForPoll = [
    "Torschützenkönig", "Meiste Vorlagen", "Meiste Tore (Team)",
    "Meiste Gegentore", "Endtabelle", "Finalisten tippen",
    "Halbfinalisten tippen", "Meiste Aluminium-Treffer",
    "Meiste Karten", "Meiste Zu-Null-Spiele"
]

struct CreatePollView: View {

    let community: CommunityModel
    let communityId: String
    let pollViewModel: CommunityPollViewModel
    let availableMatches: [MatchData]
    let onCreated: (String) -> Void  // pollId

    @Environment(\.dismiss) private var dismiss
    @State private var pollType: CommunityPoll.PollType = .free
    @State private var freeQuestion = ""
    @State private var freeOptions: [String] = ["", ""]
    @State private var selectedLeague: String = ""
    @State private var selectedLeagueOptions: Set<String> = []
    @State private var selectedBonusOptions: Set<String> = Set(allBonusCategoriesForPoll)
    @State private var selectedMatchIndices: Set<Int> = []

    private var canCreate: Bool {
        switch pollType {
        case .free:    return !freeQuestion.isEmpty && freeOptions.filter { !$0.isEmpty }.count >= 2
        case .leagues: return selectedLeagueOptions.count >= 2
        case .bonus:   return selectedBonusOptions.count >= 2
        case .matches: return selectedMatchIndices.count >= 2
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Typ-Auswahl
                        sectionHeader("Typ")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([CommunityPoll.PollType.free, .leagues, .bonus, .matches], id: \.rawValue) { type in
                                    Button(type.label) { pollType = type }
                                        .font(.system(size: 12, weight: pollType == type ? .bold : .regular))
                                        .foregroundColor(pollType == type ? .oneKickNeon : .gray)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(pollType == type ? Color.oneKickNeon : Color.white.opacity(0.1), lineWidth: 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .fill(pollType == type ? Color.oneKickNeon.opacity(0.1) : Color.clear)
                                                )
                                        )
                                }
                            }
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Typ-spezifischer Inhalt
                        switch pollType {
                        case .free:    freePollSection
                        case .leagues: leaguePollSection
                        case .bonus:   bonusPollSection
                        case .matches: matchPollSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Abstimmung erstellen")
                        .font(.headline).bold().foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Starten") { createAndDismiss() }
                        .font(.headline)
                        .foregroundColor(canCreate ? .oneKickNeon : .gray)
                        .disabled(!canCreate)
                }
            }
        }
    }

    // MARK: - Sections

    private var freePollSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Frage")
            styledTextField("Frage eingeben...", text: $freeQuestion)

            sectionHeader("Antwortoptionen (min. 2)")
            ForEach(freeOptions.indices, id: \.self) { i in
                HStack {
                    styledTextField("Option \(i + 1)", text: $freeOptions[i])
                    if freeOptions.count > 2 {
                        Button { freeOptions.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
            }
            if freeOptions.count < 6 {
                Button { freeOptions.append("") } label: {
                    Label("Option hinzufügen", systemImage: "plus")
                        .font(.system(size: 13)).foregroundColor(.oneKickNeon)
                }
            }
        }
    }

    private var leaguePollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Welche Ligen zur Abstimmung stellen?")
            ForEach(Array(community.activeLeagues).sorted(), id: \.self) { league in
                checkRow(league, selected: selectedLeagueOptions.contains(league)) {
                    if selectedLeagueOptions.contains(league) { selectedLeagueOptions.remove(league) }
                    else { selectedLeagueOptions.insert(league) }
                }
            }
        }
    }

    private var bonusPollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Welche Kategorien zur Abstimmung stellen?")
            ForEach(allBonusCategoriesForPoll, id: \.self) { cat in
                checkRow(cat, selected: selectedBonusOptions.contains(cat)) {
                    if selectedBonusOptions.contains(cat) { selectedBonusOptions.remove(cat) }
                    else { selectedBonusOptions.insert(cat) }
                }
            }
        }
    }

    private var matchPollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Liga auswählen")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(community.activeLeagues).filter { $0 != "Relegation" }.sorted(), id: \.self) { league in
                        let isSel = selectedLeague == league
                        Button(league) { selectedLeague = league }
                            .font(.system(size: 12, weight: isSel ? .bold : .regular))
                            .foregroundColor(isSel ? .oneKickNeon : .gray)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isSel ? Color.oneKickNeon : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            if availableMatches.isEmpty {
                Text("Keine Spiele verfügbar").font(.caption).foregroundColor(.gray)
            } else {
                sectionHeader("Welche Spiele sollen tippbar sein?")
                ForEach(Array(availableMatches.prefix(20).enumerated()), id: \.offset) { idx, match in
                    let label = "\(match.teams.home.name) – \(match.teams.away.name)"
                    checkRow(label, selected: selectedMatchIndices.contains(idx)) {
                        if selectedMatchIndices.contains(idx) { selectedMatchIndices.remove(idx) }
                        else { selectedMatchIndices.insert(idx) }
                    }
                }
            }
        }
        .onAppear {
            selectedLeague = Array(community.activeLeagues).filter { $0 != "Relegation" }.sorted().first ?? ""
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.gray).textCase(.uppercase)
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(.white)
            .padding(10)
            .background(Color.oneKickDarkGray)
            .cornerRadius(8)
    }

    private func checkRow(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundColor(selected ? .oneKickNeon : .gray)
                Text(label).font(.system(size: 14)).foregroundColor(.white)
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }

    private func createAndDismiss() {
        let completion: (String) -> Void = { [self] pollId in
            onCreated(pollId)
            dismiss()
        }
        switch pollType {
        case .free:
            let opts = freeOptions.filter { !$0.isEmpty }
            pollViewModel.createPoll(communityId: communityId, type: .free,
                question: freeQuestion, options: opts, multiSelect: false,
                completion: completion)
        case .leagues:
            pollViewModel.createPoll(communityId: communityId, type: .leagues,
                question: "Welche Ligen sollen weiterhin getippt werden?",
                options: Array(selectedLeagueOptions), multiSelect: true,
                completion: completion)
        case .bonus:
            pollViewModel.createPoll(communityId: communityId, type: .bonus,
                question: "Welche Bonus-Kategorien sollen getippt werden?",
                options: Array(selectedBonusOptions), multiSelect: true,
                completion: completion)
        case .matches:
            let sorted = selectedMatchIndices.sorted()
            let opts = sorted.compactMap { availableMatches[safe: $0] }
                .map { "\($0.teams.home.name) – \($0.teams.away.name)" }
            let ids = sorted.compactMap { availableMatches[safe: $0]?.fixture.id }
            pollViewModel.createPoll(communityId: communityId, type: .matches,
                question: "Welche Spiele sollen getippt werden? (\(selectedLeague))",
                options: opts, matchIds: ids, multiSelect: true,
                completion: completion)
        }
    }
}

