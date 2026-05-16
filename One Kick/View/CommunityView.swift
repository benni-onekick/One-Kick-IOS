//
//  CommunityView.swift
//  One Kick
//
//  FINAL VERSION:
//  - Profil Icon oben rechts (konsistent mit Start & Tippen).
//  - "Hinzufügen" Button darunter.
//  - Onboarding Logik integriert.
//  - FIX: Leitet jetzt korrekt zur CommunityLeaguesView (Ligen-Übersicht) weiter!
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var manager: CommunityManager
    
    @State private var showMenu = false
    @State private var showProfileSheet = false
    @State private var navigationCommunity: CommunityModel?
    
    var myCommunities: [CommunityModel] { manager.communities }
    var challengeCount: Int { 1 }
    var isUserNew: Bool { manager.communities.isEmpty }
    
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                if isUserNew {
                    // Verwenden wir die umbenannte View, um Fehler zu vermeiden
                    CommunityEmptyStateView(
                        onAction: { showMenu = true },
                        onProfile: { showProfileSheet = true }
                    )
                } else {
                    mainContentView
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // HIER IST DER FIX: Ziel auf CommunityLeaguesView geändert
            .navigationDestination(item: $navigationCommunity) { community in
                CommunityPunkteView(community: community)
            }
            .sheet(isPresented: $showMenu) {
                CommunityStartMenu()
                    .presentationDetents([.height(450)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showProfileSheet) { ProfileView() }
            .onChange(of: manager.selectedCommunity) { _, newComm in
                if let comm = newComm { self.navigationCommunity = comm }
            }
        }
    }
    
    var mainContentView: some View {
        VStack(spacing: 0) {
            
            // --- HEADER ---
            OneKickHeader(onProfile: { showProfileSheet = true })
            HStack(alignment: .center) {
                Text("Deine Übersicht").font(.subheadline).fontWeight(.bold).foregroundColor(.gray)
                Spacer()
                Button(action: { showMenu = true }) {
                    HStack(spacing: 4) { Image(systemName: "plus"); Text("Hinzufügen") }
                        .font(.caption.bold()).foregroundColor(.oneKickBlack).padding(.vertical, 8).padding(.horizontal, 14).background(Color.oneKickNeon).clipShape(Capsule())
                }
            }
            .padding(.horizontal).padding(.bottom, 10)
            
            // LISTE
            ScrollView {
                LazyVStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        CommunitySectionHeader(title: "Meine Communities (\(myCommunities.count))")
                        if myCommunities.count > 5 {
                            ForEach(myCommunities.prefix(3)) { c in Button(action: { navigationCommunity = c }) { CommunityRowCard(community: c) }.buttonStyle(PlainButtonStyle()) }
                            NavigationLink(destination: AllCommunitiesView()) { HStack { Text("Alle anzeigen").font(.subheadline).bold(); Image(systemName: "arrow.right").font(.caption).bold() }.foregroundColor(.oneKickNeon).padding(.top, 5).frame(maxWidth: .infinity, alignment: .center) }
                        } else {
                            ForEach(myCommunities) { c in Button(action: { navigationCommunity = c }) { CommunityRowCard(community: c) }.buttonStyle(PlainButtonStyle()) }
                        }
                    }.padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        CommunitySectionHeader(title: "Challenges (\(challengeCount))")
                        ChallengeRowCard(title: "Herbst-Meister 2025", tippers: "3.500 Tipper", rank: "#142")
                    }.padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Image(systemName: "globe.europe.africa.fill").foregroundColor(.oneKickNeon); Text("Globale Liga").font(.headline).bold().foregroundColor(.white).textCase(.uppercase) }
                        GlobalLeagueCard()
                    }.padding(.horizontal).padding(.top, 10)
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
}

// Hilfs-Strukturen (identisch wie vorher)
struct CommunityEmptyStateView: View {
    var onAction: () -> Void; var onProfile: () -> Void
    var body: some View {
        VStack {
            OneKickHeader(onProfile: onProfile)
            Spacer()
            Image(systemName: "person.3.sequence.fill").font(.system(size: 80)).foregroundColor(.oneKickNeon).padding(.bottom, 20)
            Text("Willkommen bei One Kick").font(.largeTitle).bold().foregroundColor(.white)
            Text("Erstelle eine Liga!").foregroundColor(.gray).padding(.top, 10)
            Spacer()
            Button(action: onAction) { Text("Loslegen").bold().foregroundColor(.black).frame(maxWidth: .infinity).padding().background(Color.oneKickNeon).cornerRadius(15) }.padding(40)
        }
    }
}
struct CommunitySectionHeader: View { let title: String; var body: some View { Text(title.uppercased()).font(.caption).bold().foregroundColor(.gray) } }
struct CommunityRowCard: View { let community: CommunityModel; var body: some View { HStack { ZStack { Circle().fill(Color.oneKickNeon).frame(width: 45, height: 45); Image(systemName: "person.3.fill").font(.caption).bold().foregroundColor(.black) }; VStack(alignment: .leading) { Text(community.name).bold().foregroundColor(.white); Text("\(community.members) Tipper").font(.caption).foregroundColor(.gray) }; Spacer(); Text("#1").font(.title3).fontWeight(.black).foregroundColor(.white) }.padding(16).background(Color(UIColor.systemGray6).opacity(0.12)).cornerRadius(18) } }
struct ChallengeRowCard: View { let title: String; let tippers: String; let rank: String; var body: some View { HStack { ZStack { Circle().fill(Color.orange.opacity(0.2)).frame(width: 45, height: 45); Image(systemName: "trophy.fill").font(.subheadline).foregroundColor(.orange) }; VStack(alignment: .leading) { Text(title).bold().foregroundColor(.white); Text(tippers).font(.caption).foregroundColor(.gray) }; Spacer(); Text(rank).font(.title3).fontWeight(.black).foregroundColor(.white) }.padding(16).background(Color(UIColor.systemGray6).opacity(0.12)).cornerRadius(18) } }
struct GlobalLeagueCard: View { var body: some View { HStack { ZStack { Circle().fill(LinearGradient(colors: [.blue, .green], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 50, height: 50); Image(systemName: "globe").font(.title3).foregroundColor(.white.opacity(0.8)) }; VStack(alignment: .leading) { Text("ONE KICK\nGLOBAL").fontWeight(.black).foregroundColor(.oneKickNeon); Text("Alle Spiele").font(.caption2).foregroundColor(.gray) }; Spacer(); Text("#15.430").font(.title3).fontWeight(.black).foregroundColor(.white) }.padding(16).background(Color.black).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.oneKickNeon, lineWidth: 1.5)) } }
