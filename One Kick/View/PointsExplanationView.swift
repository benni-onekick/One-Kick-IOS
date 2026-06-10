//
//  PointsExplanationView.swift
//  One Kick
//
//  Erklärt das Punkte-Schema pro Spiel (und kurz die Bonus-Punkte).
//

import SwiftUI

struct PointsExplanationView: View {

    private struct Rule: Identifiable {
        let id = UUID()
        let points: String
        let title: String
        let detail: String
    }

    private let matchRules: [Rule] = [
        Rule(points: "3", title: "Richtige Tendenz", detail: "Sieg, Unentschieden oder Niederlage korrekt getippt"),
        Rule(points: "2", title: "Richtige Tordifferenz", detail: "z.B. Tipp 2:1 und Ergebnis 3:2 (beide +1)"),
        Rule(points: "1", title: "Richtige Heimtore", detail: "Anzahl der Heimtore exakt getippt"),
        Rule(points: "1", title: "Richtige Auswärtstore", detail: "Anzahl der Auswärtstore exakt getippt"),
    ]

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Pro Spiel
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PUNKTE PRO SPIEL")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray).tracking(0.5)

                        VStack(spacing: 0) {
                            ForEach(Array(matchRules.enumerated()), id: \.element.id) { idx, rule in
                                HStack(spacing: 14) {
                                    Text(rule.points)
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(.oneKickNeon)
                                        .frame(width: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rule.title).font(.subheadline).bold().foregroundColor(.white)
                                        Text(rule.detail).font(.caption).foregroundColor(.gray)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                if idx < matchRules.count - 1 {
                                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        HStack(spacing: 10) {
                            Image(systemName: "star.fill").foregroundColor(.oneKickNeon)
                            Text("Exakter Tipp (alles richtig): **maximal 7 Punkte** pro Spiel")
                                .font(.caption).foregroundColor(.white)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.oneKickNeon.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Bonus
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BONUS-TIPPS (ZUSÄTZLICH)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.gray).tracking(0.5)
                        VStack(alignment: .leading, spacing: 8) {
                            bonusLine("Sieger tippen", "20 Punkte")
                            bonusLine("Finalisten / Halbfinalisten", "10 Punkte pro richtigem Team")
                            bonusLine("Einzel-Kategorien (Torschützenkönig, …)", "10 Punkte")
                            bonusLine("Endtabelle", "5 Punkte pro richtiger Position")
                            bonusLine("Gruppenphase Tabelle", "2 Punkte pro richtig platzierter Nation")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
        }
        .navigationTitle("Punkte-Erklärung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bonusLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(.oneKickNeon).padding(.top, 6)
            Text(title).font(.caption).foregroundColor(.white)
            Spacer()
            Text(value).font(.caption).bold().foregroundColor(.oneKickNeon)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
        }
    }
}
