//
//  CommunityLeaguesView.swift
//  One Kick
//

import SwiftUI
import Combine
import FirebaseAuth

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

        // SONSTIGES
        case "Relegation":                  return 9999

        default: return 78
        }
    }

    static func getMaxMatchday(for name: String) -> Int {
        switch name {
        case "1. Bundesliga", "Bundesliga", "2. Bundesliga":  return 34
        case "3. Liga":                         return 38
        case "Premier League",
             "La Liga",
             "Serie A",
             "Süper Lig":                       return 38
        case "Österreich Liga":                 return 32
        case "MLS":                             return 35
        case "Saudi Pro League":                return 34
        case "Ligue 1",
             "Eredivisie",
             "Liga Portugal":                   return 34
        case "Super League":                    return 33
        case "1. Frauen-Bundesliga":            return 26
        case "Champions League",
             "Europa League",
             "Conference League",
             "Frauen Champions League":         return 0
        default:
            return 0
        }
    }

    static func getMaxMatchday(for leagueID: Int) -> Int {
        guard let name = getName(for: leagueID) else { return 0 }
        return getMaxMatchday(for: name)
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
        case 9999: return "Relegation"
        default:   return nil
        }
    }

    // MLS + Saudi laufen nach Kalenderjahr → season=2026, alle anderen nach Saison-Startjahr
    static func getSeason(for leagueID: Int) -> Int {
        switch leagueID {
        case 253: return 2026  // MLS
        case 307: return 2026  // Saudi Pro League (2026/27-Saison startet August 2026)
        case 1:   return 2026  // Weltmeisterschaft 2026
        default:  return APIConfig.currentSeason
        }
    }

    // Ligen mit echtem ligaübergreifendem Relegations-/Aufstiegs-Playoff
    static func hasRelegationPlayoff(leagueID: Int) -> Bool {
        let leagues: Set<Int> = [
            78,   // 1. Bundesliga
            79,   // 2. Bundesliga
            80,   // 3. Liga
            88,   // Eredivisie
            61,   // Ligue 1
            207,  // Super League (Schweiz)
            218,  // Österreich Liga
            94,   // Liga Portugal
            203,  // Süper Lig
            82    // 1. Frauen-Bundesliga
        ]
        return leagues.contains(leagueID)
    }

    // Qualifikationszone eines Ranges für eine bestimmte Liga
    static func qualificationZone(rank: Int, leagueID: Int) -> QualificationZone? {
        switch leagueID {
        case 78: // 1. Bundesliga
            switch rank {
            case 1...4:  return .championsLeague
            case 5...6:  return .europaLeague
            case 7:      return .conferenceLeague
            case 16:     return .relegationPlayoff
            case 17...18: return .relegation
            default:     return nil
            }
        case 79: // 2. Bundesliga
            switch rank {
            case 1...2:  return .promotion
            case 3:      return .promotionPlayoff
            case 16:     return .relegationPlayoff
            case 17...18: return .relegation
            default:     return nil
            }
        case 80: // 3. Liga
            switch rank {
            case 1...3:  return .promotion
            case 4:      return .promotionPlayoff
            case 17:     return .relegationPlayoff
            case 18...20: return .relegation
            default:     return nil
            }
        case 39: // Premier League
            switch rank {
            case 1...4:  return .championsLeague
            case 5:      return .europaLeague
            case 6:      return .conferenceLeague
            case 18...20: return .relegation
            default:     return nil
            }
        case 140: // La Liga
            switch rank {
            case 1...4:  return .championsLeague
            case 5...6:  return .europaLeague
            case 7:      return .conferenceLeague
            case 18...20: return .relegation
            default:     return nil
            }
        case 135: // Serie A
            switch rank {
            case 1...4:  return .championsLeague
            case 5...6:  return .europaLeague
            case 7:      return .conferenceLeague
            case 18...20: return .relegation
            default:     return nil
            }
        case 61: // Ligue 1
            switch rank {
            case 1...3:  return .championsLeague
            case 4...5:  return .europaLeague
            case 6:      return .conferenceLeague
            case 16:     return .relegationPlayoff
            case 17...18: return .relegation
            default:     return nil
            }
        case 203: // Süper Lig
            switch rank {
            case 1...2:  return .championsLeague
            case 3:      return .europaLeague
            case 4...5:  return .conferenceLeague
            case 16:     return .relegationPlayoff
            case 17...18: return .relegation
            default:     return nil
            }
        case 88: // Eredivisie
            switch rank {
            case 1:      return .championsLeague
            case 2...5:  return .europaLeague
            case 16...17: return .relegationPlayoff
            case 18:     return .relegation
            default:     return nil
            }
        case 94: // Liga Portugal
            switch rank {
            case 1...3:  return .championsLeague
            case 4...5:  return .europaLeague
            case 6:      return .conferenceLeague
            case 16:     return .relegationPlayoff
            case 17...18: return .relegation
            default:     return nil
            }
        case 207: // Super League (CH)
            switch rank {
            case 1:      return .championsLeague
            case 2...3:  return .europaLeague
            case 4:      return .conferenceLeague
            case 9:      return .relegationPlayoff
            case 10:     return .relegation
            default:     return nil
            }
        case 218: // Österreich Liga
            switch rank {
            case 1:      return .championsLeague
            case 2...3:  return .europaLeague
            case 4:      return .conferenceLeague
            case 10:     return .relegationPlayoff
            case 11...12: return .relegation
            default:     return nil
            }
        case 82: // 1. Frauen-Bundesliga
            switch rank {
            case 1...2:  return .championsLeague
            case 11...12: return .relegation
            default:     return nil
            }
        default:
            return nil
        }
    }

    // Gewünschte Anzeigereihenfolge: BL1/2/3 → Frauen-BL → DFB-Pokal → UCL/UEL/UECL →
    // Top-Ligen → weitere nationale → intl. Ligen → intl. Pokale → Nationalteams
    static func sortOrder(for name: String) -> Int {
        switch name {
        // Deutsche Ligen
        case "1. Bundesliga":            return 0
        case "2. Bundesliga":            return 1
        case "3. Liga":                  return 2
        case "1. Frauen-Bundesliga":     return 3
        case "DFB-Pokal":                return 4
        // Europäische Club-Wettbewerbe
        case "Champions League":         return 10
        case "Europa League":            return 11
        case "Conference League":        return 12
        // Internationale Ligen
        case "Premier League":           return 20
        case "La Liga":                  return 21
        case "Serie A":                  return 22
        case "Ligue 1":                  return 23
        case "Eredivisie":               return 24
        case "Liga Portugal":            return 25
        case "Super League":             return 26
        case "Süper Lig":                return 27
        case "Österreich Liga":          return 28
        case "MLS":                      return 30
        case "Saudi Pro League":         return 31
        // Internationale Pokale
        case "FA Cup":                   return 40
        case "Copa del Rey":             return 41
        case "Coppa Italia":             return 42
        case "Coupe de France":          return 43
        case "Frauen Champions League":  return 44
        // Nationalmannschaften
        case "Weltmeisterschaft":        return 50
        case "Europameisterschaft":      return 51
        // Rest
        case "Nations League":           return 60
        case "WM Qualifikation":         return 61
        case "EM Qualifikation":         return 62
        case "Frauen WM":                return 63
        case "Frauen EM":                return 64
        case "Relegation":               return 65
        default:                         return 99
        }
    }
}

// MARK: - Qualification Zones

enum QualificationZone: Hashable {
    case championsLeague
    case europaLeague
    case conferenceLeague
    case promotion
    case promotionPlayoff
    case relegationPlayoff
    case relegation

    var color: Color {
        switch self {
        case .championsLeague:   return Color(red: 0.1,  green: 0.46, blue: 0.9)
        case .europaLeague:      return Color(red: 1.0,  green: 0.47, blue: 0.0)
        case .conferenceLeague:  return Color(red: 0.0,  green: 0.70, blue: 0.48)
        case .promotion:         return Color(red: 0.0,  green: 0.70, blue: 0.48)
        case .promotionPlayoff:  return Color(red: 0.6,  green: 0.85, blue: 0.0)
        case .relegationPlayoff: return Color(red: 1.0,  green: 0.65, blue: 0.0)
        case .relegation:        return Color(red: 0.85, green: 0.20, blue: 0.2)
        }
    }

    var label: String {
        switch self {
        case .championsLeague:   return "Champions League"
        case .europaLeague:      return "Europa League"
        case .conferenceLeague:  return "Conference League"
        case .promotion:         return "Aufstieg"
        case .promotionPlayoff:  return "Aufstiegs-Playoff"
        case .relegationPlayoff: return "Relegations-Playoff"
        case .relegation:        return "Abstieg"
        }
    }
}

// MARK: - ViewModel

@MainActor
class CommunityLeaguesViewModel: ObservableObject {
    @Published var openTipsPerLeague: [String: Int] = [:]
    @Published var liveLeagues: Set<String> = []
    @Published var openBonusTips: Int = 0

    private let api = APIFootballService()
    private let betManager = BetManager()

    func load(community: CommunityModel) async {
        guard let cid = community.id else { return }
        let bettedIds = await betManager.loadBets(communityId: cid)
        let liveStatuses: Set<String> = ["1H", "2H", "HT", "ET", "P", "LIVE"]
        let playoffKw = ["relegation", "playoff", "play-off", "barrage", "qualifying",
                         "promotion", "qualification", "playout", "maintien"]
        let intraLeaguePatterns = ["championship round", "relegation round",
                                   "championship group", "relegation group"]
        func isPlayoff(_ round: String, lid: Int = 0) -> Bool {
            let lower = round.lowercased()
            if !LeagueMapper.hasRelegationPlayoff(leagueID: lid) {
                if intraLeaguePatterns.contains(where: { lower.contains($0) }) { return false }
            }
            return playoffKw.contains { lower.contains($0) }
        }
        func matchdayNum(_ round: String) -> Int {
            round.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }.last ?? 0
        }

        var playoffRoundsByLeagueId: [Int: Set<String>] = [:]
        var playoffMatchesByLeagueId: [Int: [MatchData]] = [:]

        for leagueName in community.activeLeagues {
            let lid = LeagueMapper.getID(for: leagueName)
            guard lid != 9999 else { continue }
            let max = LeagueMapper.getMaxMatchday(for: leagueName)
            let result = await api.determineDisplayRoundWithMatches(for: lid, maxMatchday: max)

            func isEffectivelyPlayoff(_ r: String) -> Bool {
                let lower = r.lowercased()
                if !LeagueMapper.hasRelegationPlayoff(leagueID: lid) {
                    if intraLeaguePatterns.contains(where: { lower.contains($0) }) { return false }
                }
                return isPlayoff(r, lid: lid) || (max > 0 && matchdayNum(r) > max)
            }
            var classifiedPlayoffRounds: Set<String> = []
            if max > 0 && LeagueMapper.hasRelegationPlayoff(leagueID: lid) {
                let allRounds = await api.fetchAllRounds(for: lid)
                let (_, rawPlayoff) = api.classifyRounds(allRounds, maxMatchday: max)
                let intra = ["championship round", "championship group", "relegation group"]
                for r in rawPlayoff where !intra.contains(where: { r.lowercased().contains($0) }) {
                    classifiedPlayoffRounds.insert(r)
                }
                if !classifiedPlayoffRounds.isEmpty {
                    playoffRoundsByLeagueId[lid] = classifiedPlayoffRounds
                }
            }
            func isRelegationOrPlayoff(_ r: String) -> Bool {
                classifiedPlayoffRounds.contains(r) || isEffectivelyPlayoff(r)
            }
            let allMatchesArePlayoff = !result.matches.isEmpty &&
                result.matches.allSatisfy { isRelegationOrPlayoff($0.league.round ?? result.round) }
            guard !isRelegationOrPlayoff(result.round) && !allMatchesArePlayoff else {
                openTipsPerLeague[leagueName] = 0
                if LeagueMapper.hasRelegationPlayoff(leagueID: lid) {
                    playoffMatchesByLeagueId[lid] = result.matches
                }
                continue
            }

            let open = result.matches.filter {
                ["NS", "TBD"].contains($0.fixture.status.short) &&
                !bettedIds.contains($0.fixture.id) &&
                !isRelegationOrPlayoff($0.league.round ?? "")
            }.count
            openTipsPerLeague[leagueName] = open

            if result.matches.contains(where: { liveStatuses.contains($0.fixture.status.short) }) {
                liveLeagues.insert(leagueName)
            }
        }

        if community.activeLeagues.contains("Relegation") {
            var relegationOpen = 0
            for leagueName in community.activeLeagues {
                let rLid = LeagueMapper.getID(for: leagueName)
                guard rLid != 9999, LeagueMapper.hasRelegationPlayoff(leagueID: rLid) else { continue }
                let cached = playoffMatchesByLeagueId[rLid] ?? []
                if !cached.isEmpty {
                    relegationOpen += cached.filter {
                        ["NS", "TBD"].contains($0.fixture.status.short) && !bettedIds.contains($0.fixture.id)
                    }.count
                } else {
                    let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
                    let fromStr = dateFmt.string(from: Date().addingTimeInterval(-21 * 86400))
                    let toStr   = dateFmt.string(from: Date().addingTimeInterval( 21 * 86400))
                    let fetched = await api.fetchMatchesByDateRange(for: rLid, from: fromStr, to: toStr)
                    let knownRounds = playoffRoundsByLeagueId[rLid]
                    let maxMd = LeagueMapper.getMaxMatchday(for: leagueName)
                    relegationOpen += fetched.filter { m in
                        guard ["NS", "TBD"].contains(m.fixture.status.short),
                              !bettedIds.contains(m.fixture.id) else { return false }
                        let round = m.league.round ?? ""
                        if let known = knownRounds, !known.isEmpty { return known.contains(round) }
                        if maxMd > 0 {
                            let num = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                .compactMap { Int($0) }.last ?? 0
                            if num > maxMd { return true }
                        }
                        return playoffKw.contains { round.lowercased().contains($0) }
                    }.count
                }
            }
            openTipsPerLeague["Relegation"] = relegationOpen
        }

        // Bonus-Tipps zählen (nur für Ligen, deren erster Spieltag noch nicht begonnen hat)
        if let myId = Auth.auth().currentUser?.uid, let cid = community.id {
            let bonusManager = BonusBetManager()
            let answers = await bonusManager.loadBonusAnswers(communityId: cid, userId: myId)
            let activeCatSet = community.activeBonusCategories.map { Set($0) } ?? Set(allBonusCategories)
            var bonusCount = 0
            for leagueName in community.activeLeagues where LeagueMapper.getID(for: leagueName) != 9999 {
                let lid = LeagueMapper.getID(for: leagueName)
                let maxMd = LeagueMapper.getMaxMatchday(for: leagueName)
                let result = await api.determineDisplayRoundWithMatches(for: lid, maxMatchday: maxMd)
                // Bonus nur zählen wenn noch kein Spiel begonnen hat
                let bonusUnlocked = result.matches.allSatisfy { ["NS", "TBD"].contains($0.fixture.status.short) }
                guard bonusUnlocked else { continue }
                let cats = bonusCategoriesForLeague(leagueName, activeCategorySet: activeCatSet)
                bonusCount += cats.filter { (answers["\(leagueName)|\($0)"] ?? "").isEmpty }.count
            }
            openBonusTips = bonusCount
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
                        ForEach(community.activeLeagues.sorted { LeagueMapper.sortOrder(for: $0) < LeagueMapper.sortOrder(for: $1) }, id: \.self) { leagueName in
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

                                if vm.openBonusTips > 0 {
                                    OpenTipsBadge(count: vm.openBonusTips)
                                }

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
