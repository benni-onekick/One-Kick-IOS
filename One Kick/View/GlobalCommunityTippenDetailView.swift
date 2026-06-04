//
//  GlobalCommunityTippenDetailView.swift
//  One Kick
//
//  Zeigt die ausgewählten Ligen der Globalen Community mit Punkten + Platzierung.
//

import SwiftUI

struct GlobalCommunityTippenDetailView: View {
    @ObservedObject var vm: GlobalCommunityViewModel
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss

    private func community(for league: String) -> CommunityModel? {
        communityManager.communities.first { $0.activeLeagues.contains(league) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if vm.selectedLeagues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 50)).foregroundColor(.gray)
                        Text("Keine Wettbewerbe ausgewählt")
                            .font(.headline).foregroundColor(.white)
                        Text("Wähle Ligen im Community-Tab aus.")
                            .font(.caption).foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.selectedLeagues, id: \.self) { league in
                                let comm = community(for: league)
                                Group {
                                    if let comm {
                                        NavigationLink(destination: LeagueBettingView(
                                            community: comm,
                                            leagueID: LeagueMapper.getID(for: league),
                                            leagueName: league,
                                            maxMatchday: LeagueMapper.getMaxMatchday(for: league)
                                        )) {
                                            leagueRow(league: league, hasAccess: true)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        leagueRow(league: league, hasAccess: false)
                                            .opacity(0.5)
                                            .overlay(alignment: .trailing) {
                                                Text("Keine Community")
                                                    .font(.system(size: 9)).foregroundColor(.gray)
                                                    .padding(.trailing, 36)
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Globale Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }.foregroundColor(.oneKickNeon)
                }
            }
        }
        .task { await vm.load() }
    }

    private func leagueRow(league: String, hasAccess: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.oneKickDarkGray)
                    .frame(width: 38, height: 38)
                Image(systemName: "soccerball")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            }

            Text(league)
                .font(.subheadline).bold()
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.pointsByLeague[league] ?? 0) Pkt")
                    .font(.subheadline).bold()
                    .foregroundColor(.oneKickNeon)
                if let rank = vm.rankByLeague[league] {
                    Text("Platz \(rank)")
                        .font(.caption).foregroundColor(.gray)
                } else {
                    Text("Noch keine Daten")
                        .font(.caption).foregroundColor(.gray)
                }
            }

            if hasAccess {
                Image(systemName: "chevron.right")
                    .font(.caption.bold()).foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.oneKickDarkGray)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
