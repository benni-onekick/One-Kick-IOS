//
//  GlobalLeagueDetailView.swift
//  One Kick
//
//  Spieltage, Tabelle und globale Rangliste für eine Liga in der Globalen Community.
//

import SwiftUI

struct GlobalLeagueDetailView: View {
    let leagueName: String
    @ObservedObject var globalVM: GlobalCommunityViewModel
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    private var leagueID: Int { LeagueMapper.getID(for: leagueName) }
    private var maxMatchday: Int { LeagueMapper.getMaxMatchday(for: leagueName) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Spieltage").tag(0)
                Text("Tabelle").tag(1)
                Text("Rangliste").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.oneKickBlack)

            Divider().background(Color.white.opacity(0.08))

            Group {
                switch selectedTab {
                case 0:
                    spieltageTab
                case 1:
                    tabelleTab
                default:
                    ranglisteTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.oneKickBlack.ignoresSafeArea())
        .navigationTitle(leagueName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await globalVM.load() }
    }

    // MARK: - Spieltage Tab

    @ViewBuilder
    private var spieltageTab: some View {
        GlobalLeagueBettingView(leagueName: leagueName, globalVM: globalVM)
    }

    // MARK: - Tabelle Tab

    @ViewBuilder
    private var tabelleTab: some View {
        if koLeagueNames.contains(leagueName) {
            GroupStandingsSheet(leagueID: leagueID, leagueName: leagueName, embedded: true)
        } else {
            StandingsSheet(leagueID: leagueID, leagueName: leagueName, embedded: true)
        }
    }

    // MARK: - Rangliste Tab

    private var ranglisteTab: some View {
        GlobalCommunityLeaderboardView(vm: globalVM, embedded: true)
            .onAppear { globalVM.selectedLeagueForLeaderboard = leagueName }
    }
}
