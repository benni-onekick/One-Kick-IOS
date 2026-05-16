//
//  CommunitySettingsView.swift
//  One Kick
//

import SwiftUI

struct CommunitySettingsView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var communityManager: CommunityManager

    @State private var groupName: String
    @State private var inviteCode = "KICK-2025-X7"
    @State private var selectedLeagues: Set<String>
    @State private var selectedBonusCategories: Set<String>
    @State private var showLeagueSelection = false
    @State private var showBonusFill = false

    init(community: CommunityModel) {
        self.community = community
        _groupName = State(initialValue: community.name)
        _selectedLeagues = State(initialValue: community.activeLeagues)
        // nil → alle Kategorien aktiv (= kompletter Satz)
        _selectedBonusCategories = State(
            initialValue: community.activeBonusCategories.map { Set($0) }
                ?? Set(allBonusCategories)
        )
    }

    var shareMessage: String {
        "Komm in meine One Kick Tipprunde! Tippe mit uns die Saison.\n\nCode: \(inviteCode)\n\nLade die App hier: www.onekick.app"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                List {
                    // --- NAME ---
                    Section(header: sectionHeader("Allgemein")) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Name der Runde").font(.caption2).foregroundColor(.gray)
                            if community.isCreatedByUser {
                                TextField("Name", text: $groupName)
                                    .font(.headline).foregroundColor(.white)
                            } else {
                                Text(community.name).font(.headline).foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 5)
                        .listRowBackground(Color.oneKickDarkGray)
                    }

                    // --- WETTBEWERBE (nur Admin) ---
                    if community.isCreatedByUser {
                        Section(header: sectionHeader("Wettbewerbe")) {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showLeagueSelection = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Ligen verwalten")
                                            .font(.headline).foregroundColor(.white)
                                        Text("\(selectedLeagues.count) Ligen aktiv")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- BONUS-KATEGORIEN (nur Admin) ---
                    if community.isCreatedByUser {
                        Section(header: sectionHeader("Bonus-Kategorien")) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Wähle, welche Bonus-Tipps in dieser Community verfügbar sind.")
                                    .font(.caption).foregroundColor(.gray)

                                ForEach(allBonusCategories, id: \.self) { category in
                                    HStack {
                                        Text(category)
                                            .font(.subheadline)
                                            .foregroundColor(selectedBonusCategories.contains(category) ? .white : .gray)
                                        Spacer()
                                        Image(systemName: selectedBonusCategories.contains(category)
                                              ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedBonusCategories.contains(category)
                                                             ? .oneKickNeon : .gray.opacity(0.4))
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.instance.impact(style: .light)
                                        if selectedBonusCategories.contains(category) {
                                            selectedBonusCategories.remove(category)
                                        } else {
                                            selectedBonusCategories.insert(category)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- BONUS NACHTRAGEN (nur Admin) ---
                    if community.isCreatedByUser {
                        Section(header: sectionHeader("Mitglieder")) {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showBonusFill = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bonus-Tipps nachtragen")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Für spät beigetretene Mitglieder ausfüllen")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.oneKickNeon)
                                }
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- EINLADEN ---
                    Section(header: sectionHeader("Freunde einladen")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dein Einladungscode").font(.caption2).foregroundColor(.gray)
                                Text(inviteCode)
                                    .font(.title3).fontDesign(.monospaced).fontWeight(.bold)
                                    .foregroundColor(.oneKickNeon)
                            }
                            Spacer()
                            HStack(spacing: 15) {
                                Button(action: {
                                    UIPasteboard.general.string = inviteCode
                                    HapticManager.instance.notification(type: .success)
                                }) {
                                    Image(systemName: "doc.on.doc.fill").font(.title2).foregroundColor(.gray)
                                }.buttonStyle(PlainButtonStyle())
                                ShareLink(item: shareMessage) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.title2).foregroundColor(.oneKickNeon)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.oneKickDarkGray)
                    }

                    // --- GEFAHRENZONE ---
                    Section(header: sectionHeader("Gefahrenzone", color: .red)) {
                        if community.isCreatedByUser {
                            Button(action: {
                                HapticManager.instance.notification(type: .warning)
                                communityManager.deleteCommunity(community)
                                dismiss()
                            }) {
                                HStack { Image(systemName: "trash.fill"); Text("Community löschen") }
                                    .foregroundColor(.red).bold()
                            }.listRowBackground(Color.oneKickDarkGray)
                        } else {
                            Button(action: { HapticManager.instance.notification(type: .warning); dismiss() }) {
                                HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Community verlassen") }
                                    .foregroundColor(.red).bold()
                            }.listRowBackground(Color.oneKickDarkGray)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 10)
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        HapticManager.instance.impact(style: .light)
                        if community.isCreatedByUser {
                            communityManager.updateActiveLeagues(for: community, newLeagues: selectedLeagues)
                            let isAllActive = selectedBonusCategories == Set(allBonusCategories)
                            communityManager.updateBonusCategories(
                                for: community,
                                categories: isAllActive ? [] : Array(selectedBonusCategories)
                            )
                        }
                        dismiss()
                    }
                    .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
            .fullScreenCover(isPresented: $showLeagueSelection) {
                ManageLeaguesView(selectedLeagues: $selectedLeagues)
            }
            .sheet(isPresented: $showBonusFill) {
                AdminBonusFillView(community: community)
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color = .gray) -> some View {
        Text(title).foregroundColor(color).font(.caption).bold()
    }
}

// MARK: - Ligen verwalten

struct ManageLeaguesView: View {
    @Binding var selectedLeagues: Set<String>
    @Environment(\.dismiss) var dismiss
    @State private var showConfirmPopup = false

    let allLeagues = [
        // Deutscher Fußball
        "1. Bundesliga", "2. Bundesliga", "3. Liga", "DFB-Pokal",
        // International (Club)
        "Champions League", "Europa League", "Conference League",
        // Europäische Top-Ligen
        "Premier League", "La Liga", "Serie A", "Ligue 1",
        "Eredivisie", "Liga Portugal", "Super League", "Süper Lig", "Österreich Liga",
        // Europäische Pokale
        "FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France",
        // Internationale Ligen
        "MLS", "Saudi Pro League",
        // Nationalmannschaften
        "Weltmeisterschaft", "Europameisterschaft", "Nations League", "WM Qualifikation", "EM Qualifikation",
        // Frauenfußball
        "1. Frauen-Bundesliga", "Frauen Champions League", "Frauen WM", "Frauen EM"
    ]

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Text("Ligen verwalten").font(.headline).bold().foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .overlay(
                    HStack {
                        Button("Abbrechen") { dismiss() }.font(.subheadline).foregroundColor(.white)
                        Spacer()
                    }.padding(.horizontal)
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Wähle die Wettbewerbe für deine Tipprunde.")
                            .font(.caption).foregroundColor(.gray).padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)], spacing: 15) {
                            ForEach(allLeagues, id: \.self) { league in
                                LeagueSelectionChip(
                                    title: league,
                                    isSelected: selectedLeagues.contains(league),
                                    onTap: {
                                        HapticManager.instance.impact(style: .light)
                                        if selectedLeagues.contains(league) {
                                            selectedLeagues.remove(league)
                                        } else {
                                            selectedLeagues.insert(league)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 10)
                }

                Spacer()

                Button(action: {
                    HapticManager.instance.impact(style: .medium)
                    withAnimation(.spring()) { showConfirmPopup = true }
                }) {
                    Text("Bestätigen").font(.headline).bold().foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.oneKickNeon).cornerRadius(15)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .blur(radius: showConfirmPopup ? 5 : 0)
            .disabled(showConfirmPopup)

            if showConfirmPopup {
                Color.black.opacity(0.6).ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Willst du mit diesen Ligen fortfahren?")
                        .font(.headline).multilineTextAlignment(.center).foregroundColor(.white).padding(.top, 10)

                    HStack(spacing: 15) {
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            withAnimation { showConfirmPopup = false }
                        }) {
                            Text("Nein").font(.headline).bold().foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red).cornerRadius(12)
                        }
                        Button(action: {
                            HapticManager.instance.notification(type: .success)
                            withAnimation { showConfirmPopup = false }
                            dismiss()
                        }) {
                            Text("Ja").font(.headline).bold().foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.oneKickNeon).cornerRadius(12)
                        }
                    }
                }
                .padding(25)
                .background(Color.oneKickDarkGray).cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
