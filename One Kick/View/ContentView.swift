//
//  ContentView.swift
//  One Kick
//
//  FIX: Platzhalter für NewsView und StatistikView entfernt,
//  da diese Dateien bereits in deinem Projekt existieren.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: CommunityManager
    @EnvironmentObject var lm: LanguageManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("didAskNotificationPermission") private var didAskNotif = false
    @State private var showNotifPrompt = false

    init() {
        // Design-Anpassung für die TabBar (schwarzer Hintergrund)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "OneKickBlack") ?? UIColor.black
        
        let itemAppearance = UITabBarItemAppearance()

        // Tab-Farbe exakt #d8ff00 (nur die Tab-Leiste, global bleibt oneKickNeon unverändert)
        let neon = UIColor(red: 216/255.0, green: 255/255.0, blue: 0/255.0, alpha: 1.0)

        // Inaktive Icons (Grau)
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]

        // Aktive Icons (Neon)
        itemAppearance.selected.iconColor = neon
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: neon]
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        // Die TabView reagiert auf die Auswahl im Manager (für automatische Wechsel)
        TabView(selection: $manager.selectedTab) {
            
            StartseiteView()
                .tabItem {
                    Label(lm.t("tab.start"), systemImage: "house")
                }
                .tag(0)
            
            TippenView()
                .tabItem {
                    Label(lm.t("tab.tippen"), systemImage: "soccerball")
                }
                .tag(1)
            
            NewsView()
                .tabItem {
                    Label(lm.t("tab.news"), systemImage: "newspaper")
                }
                .tag(2)
            
            StatistikView()
                .tabItem {
                    Label(lm.t("tab.statistik"), systemImage: "chart.xyaxis.line")
                }
                .tag(3)
            
            CommunityView()
                .tabItem {
                    Label(lm.t("tab.community"), systemImage: "person.3.fill")
                }
                .tag(4)
        }
        .tint(Color(red: 216/255.0, green: 255/255.0, blue: 0/255.0))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                manager.appBecameActive = .now
            }
        }
        .task {
            guard !didAskNotif else { return }
            let status = await NotificationManager.shared.authorizationStatus()
            if status == .notDetermined {
                showNotifPrompt = true
            } else {
                didAskNotif = true
            }
        }
        .sheet(isPresented: $showNotifPrompt) {
            NotificationPermissionPrompt(onFinish: { didAskNotif = true })
        }
        .sheet(isPresented: Binding(
            get: { manager.pendingJoinCode != nil },
            set: { if !$0 { manager.pendingJoinCode = nil } }
        )) {
            if let code = manager.pendingJoinCode {
                JoinCommunitySheet(prefillCode: code)
                    .environmentObject(manager)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CommunityManager())
        .preferredColorScheme(.dark)
}
