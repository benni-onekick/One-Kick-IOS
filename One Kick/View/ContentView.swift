//
//  ContentView.swift
//  One Kick
//
//  FIX: Platzhalter für NewsView und StatistikView entfernt,
//  da diese Dateien bereits in deinem Projekt existieren.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: CommunityManager // Zugriff auf die Steuerung
    
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
                    Label("Start", systemImage: "house")
                }
                .tag(0)
            
            TippenView()
                .tabItem {
                    Label("Tippen", systemImage: "soccerball")
                }
                .tag(1)
            
            NewsView()
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }
                .tag(2)
            
            StatistikView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.xyaxis.line")
                }
                .tag(3)
            
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .tag(4)
        }
        .tint(.oneKickNeon) // Färbt das aktive Icon Neon
    }
}

#Preview {
    ContentView()
        .environmentObject(CommunityManager())
        .preferredColorScheme(.dark)
}
