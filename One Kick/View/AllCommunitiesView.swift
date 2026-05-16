//
//  AllCommunitiesView.swift
//  One Kick
//
//  NEU: Die Gesamtübersicht aller beigetretenen Ligen.
//  FIX: Leitet jetzt korrekt zur CommunityLeaguesView weiter.
//

import SwiftUI

struct AllCommunitiesView: View {
    @EnvironmentObject var manager: CommunityManager
    
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("Alle meine Ligen (\(manager.communities.count))")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    
                    LazyVStack(spacing: 15) {
                        ForEach(manager.communities) { community in
                            // HIER IST DER FIX: Ziel ist jetzt die CommunityLeaguesView
                            NavigationLink(destination: CommunityLeaguesView(community: community)) {
                                CommunityRowCard(community: community)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Übersicht")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
