//
//  CommunityLeaguesView.swift
//  One Kick
//

import SwiftUI
import Combine

// MARK: - LeagueMapper

struct LeagueMapper {

    static func getID(for name: String) -> Int {
        switch name {

        // DEUTSCHER FUSSBALL
        case "1. Bundesliga":       return 78
        case "2. Bundesliga":       return 79
        case "3. Liga":             return 80
        case "DFB-Pokal":           return 81

        // INTERNATIONAL (CLUB)
        case "Champions League":    return 2
        case "Europa League":       return 3
        case "Conference League":   return 848

        // EUROPÄISCHE TOP-LIGEN
        case "Premier League":      return 39
        case "La Liga":             return 140
        case "Serie A":             return 135
        case "Ligue 1":             return 61
        case "Eredivisie":          return 88
        case "Liga Portugal":       return 94
        case "Super League":        return 207
        case "Süper Lig":           return 203
        case "Österreich Liga":     return 218

        // EUROPÄISCHE POKALE
        case "FA Cup":              return 45
        case "Copa del Rey":        return 143
        case "Coppa Italia":        return 137
        case "Coupe de France":     return 66

        // INTERNATIONALE LIGEN
        case "MLS":                 return 253
        case "Saudi Pro League":    return 307

        // NATIONALMANNSCHAFTEN
        case "Weltmeisterschaft":   return 1
        case "Europameisterschaft": return 4
        case "Nations League":      return 5
        case "WM Qualifikation":    return 32
        case "EM Qualifikation":    return 960

        // FRAUENFUSSBALL
        case "1. Frauen-Bundesliga":        return 82
        case "Frauen Champions League":     return 525
        case "Frauen WM":                   return 6
        case "Frauen EM":                   return 1191

        default: return 78
        }
    }

    static func getMaxMatchday(for name: String) -> Int {
        switch name {
        case "1. Bundesliga", "2. Bundesliga":  return 34
        case "3. Liga":                         return 38
        case "Premier League",
             "La Liga",
             "Serie A",
             "Süper Lig":                       return 38
        case "Österreich Liga":                 return 32
        case "MLS",
             "Saudi Pro League":                return 34
        case "Ligue 1",
             "Eredivisie",
             "Liga Portugal":                   return 34
        case "Super League":                    return 36
        case "1. Frauen-Bundesliga":            return 26
        case "Champions League",
             "Europa League",
             "Conference League",
             "Frauen Champions League":         return 8
        default:
            return 0
        }
    }

    static func getName(for id: Int) -> String? {
        switch id {
        case 78:   return "Bundesliga"
        case 79:   return "2. Bundesliga"
        case 80:   return "3. Liga"
        case 81:   return "DFB-Pokal"
        case 2:    return "Champions League"
        case 3:    return "Europa League"
        case 848:  return "Conference League"
        case 39:   return "Premier League"
        case 140:  return "La Liga"
        case 135:  return "Serie A"
        case 61:   return "Ligue 1"
        case 88:   return "Eredivisie"
        case 94:   return "Liga Portugal"
        case 207:  return "Super League"
        case 203:  return "Süper Lig"
        case 218:  return "Österreich Liga"
        case 45:   return "FA Cup"
        case 143:  return "Copa del Rey"
        case 137:  return "Coppa Italia"
        case 66:   return "Coupe de France"
        case 253:  return "MLS"
        case 307:  return "Saudi Pro League"
        case 1:    return "Weltmeisterschaft"
        case 4:    return "Europameisterschaft"
        case 5:    return "Nations League"
        case 32:   return "WM Qualifikation"
        case 960:  return "EM Qualifikation"
        case 82:   return "Frauen-Bundesliga"
        case 525:  return "Frauen Champions League"
        case 6:    return "Frauen WM"
        case 1191: return "Frauen EM"
        default:   return nil
        }
    }

    // MLS läuft nach Kalenderjahr → season=2026, alle anderen nach Saison-Startjahr
    static func getSeason(for leagueID: Int) -> Int {
        switch leagueID {
        case 253: return 2026  // MLS
        default:  return APIConfig.currentSeason
        }
    }
}

// MARK: - ViewModel

@MainActor
class CommunityLeaguesViewModel: ObservableObject {
    @Published var openTipsPerLeague: [String: Int] = [:]
    @Published var liveLeagues: Set<String> = []

    private let api = APIFootballService()
    private let betManager = BetManager()

    func load(community: CommunityModel) async {
        guard let cid = community.id else { return }
        let bettedIds = await betManager.loadBets(communityId: cid)
        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]

        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            let max = LeagueMapper.getMaxMatchday(for: leagueName)
            let result = await api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)

            let open = result.matches.filter {
                ["NS", "TBD"].contains($0.fixture.status.short) &&
                !bettedIds.contains($0.fixture.id)
            }.count
            openTipsPerLeague[leagueName] = open

            if result.matches.contains(where: { liveStatuses.contains($0.fixture.status.short) }) {
                liveLeagues.insert(leagueName)
            }
        }
    }
}

// MARK: - View

struct CommunityLeaguesView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = CommunityLeaguesViewModel()
    @State private var showBonusTipp = false

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                // HEADER
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold()).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Color.oneKickDarkGray).clipShape(Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(community.name).font(.headline).bold().foregroundColor(.white)
                        Text("Wettbewerb wählen").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal).padding(.top, 10).padding(.bottom, 30)

                // LIGEN LISTE
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(Array(community.activeLeagues).sorted(), id: \.self) { leagueName in
                            let leagueID    = LeagueMapper.getID(for: leagueName)
                            let maxMatchday = LeagueMapper.getMaxMatchday(for: leagueName)
                            let openCount   = vm.openTipsPerLeague[leagueName]
                            let isLive      = vm.liveLeagues.contains(leagueName)

                            NavigationLink(destination: LeagueBettingView(
                                community: community,
                                leagueID: leagueID,
                                leagueName: leagueName,
                                maxMatchday: maxMatchday
                            )) {
                                HStack(spacing: 10) {
                                    Text(leagueName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Spacer()

                                    if isLive {
                                        LiveBadge()
                                    }

                                    if let count = openCount, count > 0 {
                                        OpenTipsBadge(count: count)
                                    }

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption.bold())
                                }
                                .padding()
                                .background(Color.oneKickDarkGray)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }

                        // BONUS TIPPS
                        Button(action: {
                            HapticManager.instance.impact(style: .medium)
                            showBonusTipp = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.oneKickNeon)
                                    .frame(width: 36, height: 36)
                                    .background(Color.oneKickNeon.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Bonus Tipps")
                                        .font(.headline).foregroundColor(.white)
                                    Text("Saisontipps abgeben & Extra-Punkte sichern")
                                        .font(.caption).foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray).font(.caption.bold())
                            }
                            .padding()
                            .background(Color.oneKickNeon.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.oneKickNeon.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.load(community: community) }
        .sheet(isPresented: $showBonusTipp) {
            BonusTippView(community: community)
        }
    }
}
