//
//  One_KickApp.swift
//  One Kick
//

import SwiftUI
import FirebaseCore

@main
struct One_KickApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var communityManager = CommunityManager()
    @StateObject private var newsService = NewsService()
    @StateObject private var authManager = AuthManager() // <--- Startet den Login-Manager

    init() {
        FirebaseApp.configure()
        let cacheVersion = "v8"
        if UserDefaults.standard.string(forKey: "mpc_cache_version") != cacheVersion {
            MatchdayPointsCache.shared.clearAll()
            UserDefaults.standard.set(cacheVersion, forKey: "mpc_cache_version")
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
    }
    
    var body: some Scene {
        WindowGroup {
            // DIE WEICHE: Bist du eingeloggt oder nicht?
            if authManager.isAuthenticated {
                // TODO: E-Mail-Verifizierung aktivieren sobald Testphase abgeschlossen.
                // Dann ersetzen durch: authManager.isAuthenticated && authManager.isEmailVerified
                // + folgenden Block einkommentieren:
                // } else if authManager.isAuthenticated && !authManager.isEmailVerified {
                //     EmailVerificationView().environmentObject(authManager).preferredColorScheme(.dark)
                ContentView()
                    .environmentObject(communityManager)
                    .environmentObject(newsService)
                    .environmentObject(authManager)
                    .preferredColorScheme(.dark)
            } else {
                LoginView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
