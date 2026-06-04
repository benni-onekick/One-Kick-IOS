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

    /// Erste Community des Nutzers, die diese Liga enthält
    private var matchingCommunity: CommunityModel? {
        communityManager.communities.first { $0.activeLeagues.contains(leagueName) }
    }

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }.foregroundColor(.oneKickNeon)
                }
            }
        }
        .task { await globalVM.load() }
    }

    // MARK: - Spieltage Tab

    @ViewBuilder
    private var spieltageTab: some View {
        if let community = matchingCommunity {
            LeagueBettingView(
                community: community,
                leagueID: leagueID,
                leagueName: leagueName,
                maxMatchday: maxMatchday
            )
        } else {
            noCommunityHint
        }
    }

    private var noCommunityHint: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 50)).foregroundColor(.gray)
            Text("Keine passende Community")
                .font(.headline).foregroundColor(.white)
            Text("Du bist in keiner Community, die \(leagueName) spielt.\nErstelle oder tritt einer bei, um die Spieltage zu sehen und zu tippen.")
                .font(.subheadline).foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tabelle Tab

    @ViewBuilder
    private var tabelleTab: some View {
        if koLeagueNames.contains(leagueName) {
            GroupStandingsSheet(leagueID: leagueID, leagueName: leagueName)
        } else {
            StandingsSheet(leagueID: leagueID, leagueName: leagueName)
        }
    }

    // MARK: - Rangliste Tab

    private var ranglisteTab: some View {
        GlobalCommunityLeaderboardView(vm: globalVM)
            .onAppear { globalVM.selectedLeagueForLeaderboard = leagueName }
    }
}
