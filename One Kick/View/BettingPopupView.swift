//
//  BettingPopupView.swift
//  One Kick
//
//  UPDATE:
//  - communityId-Parameter hinzugefügt.
//  - Speichern-Button schreibt Tipp in Firestore via BetManager.
//  - onSaved-Callback für Aktualisierung der aufrufenden View.
//

import SwiftUI
import FirebaseAuth

struct BettingPopupView: View {
    @Binding var isPresented: Bool
    let match: MatchData
    let communityId: String
    var onSaved: (() -> Void)? = nil

    @State private var homeTip: String = ""
    @State private var awayTip: String = ""
    @State private var isSaving = false
    @State private var inputError = false

    private let betManager = BetManager()

    var matchDateTime: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: match.fixture.date) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EE. dd.MM. – HH:mm 'Uhr'"
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 20) {
                // HEADER
                VStack(spacing: 4) {
                    Text("Tipp abgeben")
                        .font(.title2).bold().foregroundColor(.white)
                    Text(matchDateTime)
                        .font(.caption).foregroundColor(.gray)
                }

                // TEAMS & EINGABE
                HStack(spacing: 15) {
                    teamColumn(name: match.teams.home.name, logo: match.teams.home.logo, tip: $homeTip)
                    Text(":")
                        .font(.title).bold().foregroundColor(.gray).padding(.top, 40)
                    teamColumn(name: match.teams.away.name, logo: match.teams.away.logo, tip: $awayTip)
                }
                .padding(.vertical, 10)

                if inputError {
                    Text("Bitte gültige Zahlen eingeben.")
                        .font(.caption).foregroundColor(.orange)
                }

                // BUTTONS
                HStack(spacing: 15) {
                    Button(action: {
                        HapticManager.instance.impact(style: .light)
                        isPresented = false
                    }) {
                        Text("Abbrechen")
                            .font(.subheadline).bold().foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.oneKickBlack).cornerRadius(12)
                    }

                    Button(action: saveBet) {
                        Group {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("Speichern").font(.subheadline).bold().foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.oneKickNeon).cornerRadius(12)
                    }
                    .disabled(isSaving)
                }
            }
            .padding(25)
            .background(Color.oneKickDarkGray)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.horizontal, 30)
        }
    }

    @ViewBuilder
    private func teamColumn(name: String, logo: String, tip: Binding<String>) -> some View {
        VStack(spacing: 10) {
            AsyncImage(url: URL(string: logo)) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else { Circle().fill(Color.gray.opacity(0.3)) }
            }
            .frame(width: 50, height: 50)

            Text(name)
                .font(.caption).bold().foregroundColor(.white).lineLimit(1)

            TextField("-", text: tip)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title.bold())
                .frame(width: 65, height: 55)
                .background(Color.oneKickBlack)
                .cornerRadius(12)
                .foregroundColor(.oneKickNeon)
        }
    }

    private func saveBet() {
        guard let home = Int(homeTip), let away = Int(awayTip) else {
            inputError = true
            HapticManager.instance.impact(style: .light)
            return
        }
        inputError = false
        isSaving = true
        HapticManager.instance.impact(style: .medium)

        Task {
            try? await betManager.saveBet(
                fixtureId: match.fixture.id,
                communityId: communityId,
                homeGoals: home,
                awayGoals: away
            )
            isPresented = false
            onSaved?()
        }
    }
}
