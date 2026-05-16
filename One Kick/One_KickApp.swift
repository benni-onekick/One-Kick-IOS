//
//  One_KickApp.swift
//  One Kick
//

import SwiftUI
import FirebaseCore

@main
struct One_KickApp: App {
    @StateObject private var communityManager = CommunityManager()
    @StateObject private var newsService = NewsService()
    @StateObject private var authManager = AuthManager() // <--- Startet den Login-Manager
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            // DIE WEICHE: Bist du eingeloggt oder nicht?
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(communityManager)
                    .environmentObject(newsService)
                    .environmentObject(authManager) // Dem Profil zur Verfügung stellen
                    .preferredColorScheme(.dark)
            } else {
                LoginView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
