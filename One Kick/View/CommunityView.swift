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
import FirebaseAuth

struct CommunityView: View {
    @EnvironmentObject var manager: CommunityManager
    @EnvironmentObject var lm: LanguageManager

    @State private var showMenu = false
    @State private var showProfileSheet = false
    @State private var showGlobalLeaderboard = false
    @State private var showGlobalCommunityDetail = false
    @State private var navigationCommunity: CommunityModel?
    @StateObject private var globalCommunityVM = GlobalCommunityViewModel()
    @State private var showGlobalLeagueSelection = false

    var myCommunities: [CommunityModel] { manager.communities }
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
            .sheet(isPresented: $showGlobalLeaderboard) {
                GlobalCommunityLeaderboardView(vm: globalCommunityVM)
            }
            .sheet(isPresented: $showGlobalCommunityDetail) {
                GlobalCommunityTippenDetailView(vm: globalCommunityVM)
                    .environmentObject(manager)
            }
            .sheet(isPresented: $showGlobalLeagueSelection, onDismiss: {
                Task { await globalCommunityVM.load() }
            }) {
                GlobalCommunityLeagueSelectionView()
            }
            .onChange(of: manager.selectedCommunity) { _, newComm in
                if let comm = newComm { self.navigationCommunity = comm }
            }
            .task { await globalCommunityVM.load() }
        }
    }
    
    var mainContentView: some View {
        VStack(spacing: 0) {
            
            // --- HEADER ---
            OneKickHeader(onProfile: { showProfileSheet = true })
            HStack(alignment: .center) {
                Text(lm.t("community.overview")).font(.subheadline).fontWeight(.bold).foregroundColor(.gray)
                Spacer()
                Button(action: { showMenu = true }) {
                    HStack(spacing: 4) { Image(systemName: "plus"); Text(lm.t("action.add")) }
                        .font(.caption.bold()).foregroundColor(.oneKickBlack).padding(.vertical, 8).padding(.horizontal, 14).background(Color.oneKickNeon).clipShape(Capsule())
                }
            }
            .padding(.horizontal).padding(.bottom, 10)
            
            // LISTE
            ScrollView {
                LazyVStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        CommunitySectionHeader(title: "\(lm.t("community.my")) (\(myCommunities.count))")
                        if myCommunities.count > 5 {
                            ForEach(myCommunities.prefix(3)) { c in Button(action: { navigationCommunity = c }) { CommunityRowCard(community: c) }.buttonStyle(PlainButtonStyle()) }
                            NavigationLink(destination: AllCommunitiesView()) { HStack { Text("Alle anzeigen").font(.subheadline).bold(); Image(systemName: "arrow.right").font(.caption).bold() }.foregroundColor(.oneKickNeon).padding(.top, 5).frame(maxWidth: .infinity, alignment: .center) }
                        } else {
                            ForEach(myCommunities) { c in Button(action: { navigationCommunity = c }) { CommunityRowCard(community: c) }.buttonStyle(PlainButtonStyle()) }
                        }
                    }.padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "globe.europe.africa.fill").foregroundColor(.oneKickNeon)
                            Text("Globale Community").font(.headline).bold().foregroundColor(.white)
                            Spacer()
                            Button(action: { showGlobalLeagueSelection = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                        if globalCommunityVM.selectedLeagues.isEmpty {
                            GlobalCommunityEmptyCard(onJoin: { showGlobalLeagueSelection = true })
                        } else {
                            Button(action: { showGlobalCommunityDetail = true }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.oneKickNeon.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "globe.europe.africa.fill")
                                            .foregroundColor(.oneKickNeon)
                                            .font(.system(size: 18))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lm.t("community.global"))
                                            .font(.headline).bold().foregroundColor(.white)
                                        Text("\(globalCommunityVM.selectedLeagues.count) \(lm.t("punkteview.leagues"))")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.oneKickDarkGray)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.oneKickNeon.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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
struct CommunityRowCard: View {
    let community: CommunityModel
    var body: some View {
        HStack {
            AvatarView(displayName: community.name, photoBase64: community.photoBase64, size: 45)
            VStack(alignment: .leading) {
                Text(community.name).bold().foregroundColor(.white)
                Text("\(community.members) \(LanguageManager.shared.t("community.tipper"))").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text("1.").font(.title3).fontWeight(.black).foregroundColor(.white)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.12))
        .cornerRadius(18)
    }
}
struct ChallengeRowCard: View { let title: String; let tippers: String; let rank: String; var body: some View { HStack { ZStack { Circle().fill(Color.orange.opacity(0.2)).frame(width: 45, height: 45); Image(systemName: "trophy.fill").font(.subheadline).foregroundColor(.orange) }; VStack(alignment: .leading) { Text(title).bold().foregroundColor(.white); Text(tippers).font(.caption).foregroundColor(.gray) }; Spacer(); Text(rank).font(.title3).fontWeight(.black).foregroundColor(.white) }.padding(16).background(Color(UIColor.systemGray6).opacity(0.12)).cornerRadius(18) } }
// MARK: - Globale Community Cards

struct GlobalCommunityEmptyCard: View {
    let onJoin: () -> Void
    var body: some View {
        Button(action: onJoin) {
            HStack {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title2).foregroundColor(.oneKickNeon)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Globale Community beitreten")
                        .font(.subheadline).bold().foregroundColor(.white)
                    Text("Messe dich mit allen App-Nutzern")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.oneKickDarkGray)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.oneKickNeon.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GlobalCommunityLeagueCard: View {
    let leagueName: String
    let points: Int
    let rank: Int?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, Color.oneKickNeon],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Image(systemName: "globe")
                    .font(.system(size: 16)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(leagueName)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    .lineLimit(1)
                Text("\(points) Pkt")
                    .font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            if isLoading {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else if let rank {
                VStack(spacing: 1) {
                    Text("Platz")
                        .font(.caption2).foregroundColor(.gray)
                    Text("\(rank).")
                        .font(.headline).fontWeight(.black).foregroundColor(.white)
                }
            } else {
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Globale Community Leaderboard

struct GlobalCommunityLeaderboardView: View {
    @ObservedObject var vm: GlobalCommunityViewModel
    @Environment(\.dismiss) var dismiss
    @State private var entries: [GlobalCommunityEntry] = []
    @State private var isLoadingEntries = true
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    var leagueName: String { vm.selectedLeagueForLeaderboard ?? "" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                if isLoadingEntries {
                    ProgressView().tint(.oneKickNeon)
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "globe").font(.system(size: 40)).foregroundColor(.gray)
                        Text("Noch keine Einträge").font(.headline).foregroundColor(.white)
                        Text("Tippe in einer Community mit \(leagueName), um im globalen Ranking zu erscheinen.")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                                let isMe = entry.id == currentUserId
                                HStack(spacing: 12) {
                                    Text("\(i + 1).")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isMe ? .black : .gray)
                                        .frame(width: 32, alignment: .trailing)
                                    ZStack {
                                        Circle()
                                            .fill(isMe ? Color.oneKickNeon : Color.oneKickDarkGray)
                                            .frame(width: 34, height: 34)
                                        Text(String(entry.displayName.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(isMe ? .black : .white)
                                    }
                                    Text(entry.displayName)
                                        .font(.system(size: 14, weight: isMe ? .bold : .regular))
                                        .foregroundColor(isMe ? .black : .white).lineLimit(1)
                                    Spacer()
                                    Text("\(entry.points) Pkt")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(isMe ? .black : .white)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                .background(isMe ? Color.oneKickNeon : Color.clear)
                                if i < entries.count - 1 {
                                    Rectangle().fill(Color.white.opacity(0.06))
                                        .frame(height: 0.5).padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(leagueName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }.foregroundColor(.oneKickNeon)
                }
            }
        }
        .task {
            guard !leagueName.isEmpty else { isLoadingEntries = false; return }
            entries = await vm.loadLeaderboard(for: leagueName)
            isLoadingEntries = false
        }
    }
}
