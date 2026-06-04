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

    init() {
        // Design-Anpassung für die TabBar (schwarzer Hintergrund)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "OneKickBlack") ?? UIColor.black
        
        let itemAppearance = UITabBarItemAppearance()
        
        // Inaktive Icons (Grau)
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        
        // Aktive Icons (Neon)
        itemAppearance.selected.iconColor = UIColor(named: "OneKickNeon") ?? UIColor.green
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(named: "OneKickNeon") ?? UIColor.green]
        
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
        .tint(.oneKickNeon)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                manager.appBecameActive = .now
            }
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
