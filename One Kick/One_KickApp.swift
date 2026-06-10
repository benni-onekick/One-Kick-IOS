//
//  One_KickApp.swift
//  One Kick
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct One_KickApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var communityManager = CommunityManager()
    @StateObject private var newsService = NewsService()
    @StateObject private var authManager = AuthManager()
    @StateObject private var lm = LanguageManager.shared

    init() {
        FirebaseApp.configure()
        UIApplication.shared.registerForRemoteNotifications()
        Auth.auth().languageCode = "de"
        let cacheVersion = "v10"
        if UserDefaults.standard.string(forKey: "mpc_cache_version") != cacheVersion {
            MatchdayPointsCache.shared.clearAll()
            UserDefaults.standard.set(cacheVersion, forKey: "mpc_cache_version")
        }
        // Vollständiger Reset: In-Memory + Disk + MatchdayPoints für korrekte Punkte
        if UserDefaults.standard.string(forKey: "full_reset_v1") == nil {
            APIFootballService.clearSeasonMemoryCaches()
            MatchdayPointsCache.shared.clearAll()
            let fullResetDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OneKickMatchCache")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: fullResetDir.path) {
                for file in files where file.hasPrefix("season_v2_") {
                    try? FileManager.default.removeItem(at: fullResetDir.appendingPathComponent(file))
                }
            }
            UserDefaults.standard.set("done", forKey: "full_reset_v1")
            UserDefaults.standard.removeObject(forKey: "mpc_cache_version")
        }

        // Einmalig: ALLE season_v2_* Caches löschen — eingefrorene Live-Scores korrigieren
        if UserDefaults.standard.string(forKey: "season_staleLive_fix_v1") == nil {
            let cacheDir0 = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OneKickMatchCache")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDir0.path) {
                for file in files where file.hasPrefix("season_v2_") {
                    try? FileManager.default.removeItem(at: cacheDir0.appendingPathComponent(file))
                }
            }
            MatchdayPointsCache.shared.clearAll()
            UserDefaults.standard.set("done", forKey: "season_staleLive_fix_v1")
            // Versionierung zurücksetzen, damit mpc_cache_version wieder greift
            UserDefaults.standard.removeObject(forKey: "mpc_cache_version")
        }

        // Einmalig: Frauen Bundesliga (82) + Frauen CL (525) Saison-Caches löschen → Refetch 25/26
        if UserDefaults.standard.string(forKey: "frauenLeagues_cache_cleared_v2") == nil {
            let cacheDir2 = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OneKickMatchCache")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDir2.path) {
                for file in files where file.hasPrefix("season_v2_82_") || file.hasPrefix("season_v2_525_") {
                    try? FileManager.default.removeItem(at: cacheDir2.appendingPathComponent(file))
                }
            }
            MatchdayPointsCache.shared.clearForLeague(leagueId: 82)
            MatchdayPointsCache.shared.clearForLeague(leagueId: 525)
            UserDefaults.standard.set("done", forKey: "frauenLeagues_cache_cleared_v2")
        }

        // Einmalig: ALLE Ligue-1-Disk-Caches + mpc_ löschen (vergiftete Cache-Einträge aus alten Runs)
        if UserDefaults.standard.string(forKey: "sv_ligue1_fix") != "v4" {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OneKickMatchCache")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDir.path) {
                for file in files where file.hasPrefix("61_") || file.hasPrefix("season_v2_61_") {
                    try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent(file))
                }
            }
            MatchdayPointsCache.shared.clearForLeague(leagueId: 61)
            UserDefaults.standard.set("v4", forKey: "sv_ligue1_fix")
        }

        // Einmalig: VOLLSTÄNDIGER Cache-Reset — löscht ALLE Round-Cache-Dateien + mpc_ + leaderboard
        // Behebt iOS vs. Android Punkte-Diskrepanz (iOS fehlte fetchFixturesByIds-Äquivalent)
        if UserDefaults.standard.string(forKey: "all_caches_v1") == nil {
            APIFootballService.clearAllDiskCaches()
            MatchdayPointsCache.shared.clearAll()
            LeaderboardCache.shared.clearAll()
            let defaults = UserDefaults.standard
            defaults.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("lmd_") }
                .forEach { defaults.removeObject(forKey: $0) }
            UserDefaults.standard.set("done", forKey: "all_caches_v1")
            UserDefaults.standard.removeObject(forKey: "mpc_cache_version")
        }

        // Einmalig: Statistik-Cache leeren damit neue Punkte sofort erscheinen
        if UserDefaults.standard.string(forKey: "stats_cache_v1") == nil {
            UserDefaults.standard.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("statsCache_v3_") }
                .forEach { UserDefaults.standard.removeObject(forKey: $0) }
            UserDefaults.standard.set("done", forKey: "stats_cache_v1")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                // DIE WEICHE: Bist du eingeloggt oder nicht?
                if authManager.isAuthenticated && !authManager.isEmailVerified {
                    EmailVerificationView()
                        .environmentObject(authManager)
                        .preferredColorScheme(.dark)
                } else if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(communityManager)
                        .environmentObject(newsService)
                        .environmentObject(authManager)
                        .environmentObject(lm)
                        .preferredColorScheme(.dark)
                        .id(lm.currentLanguage)   // Erzwingt vollständigen Rebuild bei Sprachwechsel
                } else {
                    LoginView()
                        .environmentObject(authManager)
                        .environmentObject(lm)
                        .preferredColorScheme(.dark)
                        .id(lm.currentLanguage)
                }
            }
            .onOpenURL { url in
                guard url.scheme == "onekick",
                      url.host == "join",
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else { return }
                communityManager.pendingJoinCode = code
            }
        }
    }
}
