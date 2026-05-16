//
//  TippPopupView.swift
//  One Kick
//
//  ROBUST: Verhindert Texteingaben (nur Zahlen erlaubt).
//

import SwiftUI
import Combine // Für die Input-Validierung

struct TippPopupView: View {
    let game: OpenGame
    var onSave: () -> Void
    
    @State private var tipHome = ""
    @State private var tipGuest = ""
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Dein Tipp").font(.headline).foregroundColor(.oneKickNeon).textCase(.uppercase).padding(.top, 10)
            
            HStack(spacing: 15) {
                // HEIM
                VStack(spacing: 8) {
                    TeamLogoView(teamName: game.home, size: 50)
                    Text(game.home).font(.headline).bold().foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                    
                    TextField("-", text: $tipHome)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2.bold())
                        .foregroundColor(.oneKickNeon)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oneKickNeon.opacity(0.5), lineWidth: 1))
                        .focused($isInputActive)
                        .onReceive(Just(tipHome)) { newValue in
                            // Filter: Nur Zahlen erlauben (max 2 Stellen)
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue { self.tipHome = filtered }
                            if filtered.count > 2 { self.tipHome = String(filtered.prefix(2)) }
                        }
                }.frame(maxWidth: .infinity)
                
                Text(":").font(.largeTitle).bold().foregroundColor(.gray).padding(.top, 40)
                
                // GAST
                VStack(spacing: 8) {
                    TeamLogoView(teamName: game.guest, size: 50)
                    Text(game.guest).font(.headline).bold().foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                    
                    TextField("-", text: $tipGuest)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2.bold())
                        .foregroundColor(.oneKickNeon)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oneKickNeon.opacity(0.5), lineWidth: 1))
                        .focused($isInputActive)
                        .onReceive(Just(tipGuest)) { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue { self.tipGuest = filtered }
                            if filtered.count > 2 { self.tipGuest = String(filtered.prefix(2)) }
                        }
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal, 5)
            
            // Button nur Aktiv wenn Eingaben da sind
            if !tipHome.isEmpty && !tipGuest.isEmpty {
                Button(action: { onSave() }) {
                    Text("Speichern").font(.headline).bold().foregroundColor(.black).frame(maxWidth: .infinity).padding(12).background(Color.oneKickNeon).cornerRadius(25).shadow(color: .oneKickNeon.opacity(0.4), radius: 10)
                }.padding(.horizontal, 20).padding(.bottom, 10).transition(.scale.combined(with: .opacity))
            } else {
                Text("Gib dein Ergebnis ein").font(.caption).foregroundColor(.gray).padding(.bottom, 20)
            }
        }
        .padding(20).background(Color.oneKickDarkGray).cornerRadius(25).shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10).overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isInputActive = true } }
    }
}
