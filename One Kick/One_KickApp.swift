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
    @StateObject private var authManager = AuthManager()
    @StateObject private var lm = LanguageManager.shared

    init() {
        FirebaseApp.configure()
        UIApplication.shared.registerForRemoteNotifications()
        let cacheVersion = "v9"
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
