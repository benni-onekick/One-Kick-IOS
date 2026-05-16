//
//  StatistikView.swift
//  One Kick
//
//  DESIGN UPDATE:
//  - Profil-Icon oben rechts.
//  - Schickes Grid-Layout für Stats.
//

import SwiftUI

struct StatistikView: View {
    @State private var showProfileSheet = false
    
    // Dummy Daten für die Statistik
    let stats = [
        StatItem(title: "Punkte", value: "1.240", icon: "star.fill", color: .oneKickNeon),
        StatItem(title: "Trefferquote", value: "68%", icon: "target", color: .blue),
        StatItem(title: "Volltreffer", value: "42", icon: "scope", color: .red),
        StatItem(title: "Spieltage", value: "18", icon: "calendar", color: .orange)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // --- HEADER (Konsistent) ---
                    VStack(spacing: 0) {
                        HStack {
                            Text("Statistik")
                                .font(.system(size: 40, weight: .black))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Profil Button (Oben Rechts)
                            Button(action: {
                                HapticManager.instance.impact(style: .light)
                                showProfileSheet = true
                            }) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Sub-Header
                        HStack {
                            Text("Deine Performance")
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .padding(.bottom, 15)
                    }
                    
                    // --- CONTENT ---
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            // Große Karte: Globales Ranking
                            GlobalRankCard()
                            
                            // Grid für Details
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                ForEach(stats) { stat in
                                    StatCard(item: stat)
                                }
                            }
                            
                            // Diagramm Platzhalter
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Punkteverlauf")
                                    .font(.headline).bold()
                                    .foregroundColor(.white)
                                
                                Rectangle()
                                    .fill(Color.oneKickDarkGray)
                                    .frame(height: 200)
                                    .cornerRadius(16)
                                    .overlay(
                                        Image(systemName: "chart.xyaxis.line")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                    )
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
        }
    }
}

// --- HELPER COMPONENTS ---

struct StatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}

struct StatCard: View {
    let item: StatItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(item.color)
                Spacer()
            }
            
            Text(item.value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(item.title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct GlobalRankCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("GLOBALES RANKING")
                    .font(.caption).bold()
                    .foregroundColor(.gray)
                
                Text("#15.430")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.oneKickNeon)
                
                Text("Top 15% aller Spieler")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            Spacer()
            
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 60))
                .foregroundColor(.oneKickDarkGray.opacity(0.8)) // Hintergrund Deko
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundColor(.oneKickNeon)
                )
        }
        .padding(20)
        .background(Color.oneKickBlack)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.oneKickNeon, lineWidth: 1))
    }
}
