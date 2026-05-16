//
//  NewsView.swift
//  One Kick
//
//  DESIGN UPDATE:
//  - Profil-Icon oben rechts, konsistent mit Community & Startseite.
//

import SwiftUI

struct NewsView: View {
    // Falls du den NewsService schon hast (aus StartseiteView), nutzen wir ihn hier
    @EnvironmentObject var newsService: NewsService
    @State private var showProfileSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // --- HEADER ---
                    OneKickHeader(onProfile: {
                        HapticManager.instance.impact(style: .light)
                        showProfileSheet = true
                    })
                    HStack {
                        Text("Aktuelles aus der Fußballwelt")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // --- CONTENT ---
                    ScrollView {
                        VStack(spacing: 20) {
                            if newsService.articles.isEmpty {
                                // Lade-Indikator oder Platzhalter
                                ProgressView()
                                    .tint(.oneKickNeon)
                                    .padding(.top, 50)
                                Text("Lade Nachrichten...")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(newsService.articles) { article in
                                    Link(destination: URL(string: article.url)!) {
                                        NewsCard(article: article)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .task {
                // News laden, falls noch leer
                if newsService.articles.isEmpty {
                    await newsService.fetchNews()
                }
            }
        }
    }
}

// --- NEWS CARD DESIGN ---
struct NewsCard: View {
    let article: NewsArticle // Nutzt dein bestehendes NewsArticle Model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bild
            if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2).frame(height: 180)
                    }
                }
            }
            
            // Text Bereich
            VStack(alignment: .leading, spacing: 8) {
                Text(article.source.name.uppercased())
                    .font(.caption).bold()
                    .foregroundColor(.oneKickNeon)
                
                Text(article.title)
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                Text("Mehr lesen")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            .padding(16)
            .background(Color.oneKickDarkGray)
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
