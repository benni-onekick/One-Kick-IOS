//
//  BettingPopupView.swift
//  One Kick
//

import SwiftUI
import FirebaseAuth

struct BettingPopupView: View {
    @Binding var isPresented: Bool
    let match: MatchData
    let communityId: String
    var odds: MatchWinnerOdds? = nil
    var onSaved: (() -> Void)? = nil

    @EnvironmentObject var communityManager: CommunityManager

    @AppStorage("showOdds") private var showOdds = true
    @State private var homeTip: String = ""
    @State private var awayTip: String = ""
    @State private var isSaving = false
    @State private var inputError = false
    @State private var onlyThisCommunity = false

    private let betManager = BetManager()

    private var affectedCommunities: [CommunityModel] {
        guard UserSettings.shared.crossCommunityTipping else { return [] }
        let leagueName = match.league.name
        let mappedName = LeagueMapper.getName(for: match.league.id)
        return communityManager.communities.filter { community in
            community.activeLeagues.contains(leagueName) ||
            (mappedName != nil && community.activeLeagues.contains(mappedName!))
        }
    }

    private var affectedCommunityIds: [String] {
        let ids = affectedCommunities.compactMap { $0.id }
        return ids.isEmpty ? [communityId] : ids
    }

    private var showsCrossCommunityBanner: Bool {
        UserSettings.shared.crossCommunityTipping
    }

    var matchDateTime: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: match.fixture.date) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EE. dd.MM. – HH:mm 'Uhr'"
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            ScrollView {
                VStack(spacing: 12) {
                    // HEADER
                    VStack(spacing: 4) {
                        Text("Tipp abgeben")
                            .font(.title2).bold().foregroundColor(.white)
                        Text(matchDateTime)
                            .font(.caption).foregroundColor(.gray)
                    }

                    // WETTQUOTEN
                    if showOdds, let o = odds {
                        oddsView(o)
                    }

                    // TEAMS & EINGABE
                    HStack(spacing: 15) {
                        teamColumn(name: match.teams.home.name, logo: match.teams.home.logo, tip: $homeTip)
                        Text(":")
                            .font(.title).bold().foregroundColor(.gray).padding(.top, 35)
                        teamColumn(name: match.teams.away.name, logo: match.teams.away.logo, tip: $awayTip)
                    }
                    .padding(.vertical, 6)

                    if inputError {
                        Text("Bitte gültige Zahlen eingeben.")
                            .font(.caption).foregroundColor(.orange)
                    }

                    // ÜBERGREIFENDES TIPPEN BANNER
                    if showsCrossCommunityBanner {
                        crossCommunityBanner
                    }

                    // BUTTONS
                    HStack(spacing: 10) {
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            isPresented = false
                        }) {
                            Text("Abbrechen")
                                .font(.subheadline).bold().foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.oneKickBlack).cornerRadius(12)
                        }

                        Button(action: saveBet) {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Speichern").font(.subheadline).bold().foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.oneKickNeon).cornerRadius(12)
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(18)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.oneKickDarkGray)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var crossCommunityBanner: some View {
        HStack(spacing: 8) {
            communityTile(
                label: "Community\nübergreifend tippen",
                active: !onlyThisCommunity
            ) {
                onlyThisCommunity = false
            }

            communityTile(
                label: "Nur in dieser\nCommunity tippen",
                active: onlyThisCommunity
            ) {
                onlyThisCommunity = true
            }
        }
    }

    private func communityTile(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.instance.impact(style: .light)
            action()
        }) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(active ? .black : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(active ? Color.oneKickNeon : Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(active ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func oddsView(_ o: MatchWinnerOdds) -> some View {
        let rawH = 1 / o.home; let rawD = 1 / o.draw; let rawA = 1 / o.away
        let total = rawH + rawD + rawA
        let pH = rawH / total; let pD = rawD / total; let pA = rawA / total

        return VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10)).foregroundColor(.oneKickNeon)
                Text("Wettquoten")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                Spacer()
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: max(0, geo.size.width * pH))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: max(0, geo.size.width * pD))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red.opacity(0.7))
                        .frame(width: max(0, geo.size.width * pA))
                }
            }
            .frame(height: 7)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.2f", o.home))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                    Text("Sieg Heim")
                        .font(.system(size: 9)).foregroundColor(.gray.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .center, spacing: 1) {
                    Text(String(format: "%.2f", o.draw))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.gray)
                    Text("Unentschieden")
                        .font(.system(size: 9)).foregroundColor(.gray.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.2f", o.away))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                    Text("Sieg Ausw.")
                        .font(.system(size: 9)).foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func teamColumn(name: String, logo: String, tip: Binding<String>) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: logo)) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else { Circle().fill(Color.gray.opacity(0.3)) }
            }
            .frame(width: 42, height: 42)

            Text(name)
                .font(.system(size: 10, weight: .bold)).foregroundColor(.white).lineLimit(1)

            TextField("-", text: tip)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title.bold())
                .frame(width: 60, height: 48)
                .background(Color.oneKickBlack)
                .cornerRadius(12)
                .foregroundColor(.oneKickNeon)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Fertig") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                        .foregroundColor(.oneKickNeon)
                        .fontWeight(.bold)
                    }
                }
        }
    }

    private func saveBet() {
        guard let home = Int(homeTip), let away = Int(awayTip) else {
            inputError = true
            HapticManager.instance.impact(style: .light)
            return
        }
        inputError = false
        isSaving = true
        HapticManager.instance.impact(style: .medium)

        let ids: [String] = (showsCrossCommunityBanner && !onlyThisCommunity)
            ? affectedCommunityIds
            : [communityId]

        Task {
            await betManager.saveBetToMultipleCommunities(
                fixtureId: match.fixture.id,
                communityIds: ids,
                homeGoals: home,
                awayGoals: away
            )
            isPresented = false
            onSaved?()
            for cid in ids {
                NotificationCenter.default.post(
                    name: .tipSaved,
                    object: nil,
                    userInfo: ["communityId": cid]
                )
            }
        }
    }
}
