//
//  GlobalCommunityLeagueSelectionView.swift
//  One Kick
//

import SwiftUI

struct GlobalCommunityLeagueSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = GlobalCommunityViewModel()
    @State private var selected: Set<String> = []
    @State private var isSaving = false
    @State private var showRemoveAlert = false
    @State private var leagueToRemove = ""

    let categories: [(name: String, leagues: [String])] = [
        ("Deutscher Fußball", ["1. Bundesliga", "2. Bundesliga", "3. Liga", "DFB-Pokal"]),
        ("Europäische Club-Wettbewerbe", ["Champions League", "Europa League", "Conference League"]),
        ("Europäische Top-Ligen", ["Premier League", "La Liga", "Serie A", "Ligue 1", "Eredivisie", "Liga Portugal", "Super League", "Süper Lig"]),
        ("Internationale Ligen", ["MLS", "Saudi Pro League"]),
        ("Nationalmannschaften", ["Weltmeisterschaft", "Europameisterschaft", "Nations League"]),
        ("Frauenfußball", ["1. Frauen-Bundesliga", "Frauen Champions League"]),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Wähle die Ligen, für die du im globalen Ranking mitspielen möchtest.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 16)

                        ForEach(Array(categories.enumerated()), id: \.element.name) { idx, cat in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(cat.name.uppercased())
                                    .font(.caption).bold()
                                    .foregroundColor(.oneKickNeon)
                                    .padding(.leading, 4)
                                    .padding(.horizontal)

                                ForEach(cat.leagues, id: \.self) { league in
                                    let isSelected = selected.contains(league)
                                    Button(action: { toggle(league) }) {
                                        HStack {
                                            Text(league)
                                                .font(.subheadline)
                                                .foregroundColor(isSelected ? .white : .gray)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.oneKickNeon)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray.opacity(0.4))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? Color.oneKickNeon.opacity(0.08) : Color.oneKickDarkGray)
                                        .cornerRadius(12)
                                        .overlay(RoundedCornerShape(cornerRadius: 12)
                                            .stroke(isSelected ? Color.oneKickNeon.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 14)

                            if idx < categories.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationTitle("Globale Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        if isSaving { ProgressView().tint(.oneKickNeon).scaleEffect(0.8) }
                        else { Text("Speichern").bold().foregroundColor(.oneKickNeon) }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Liga entfernen?", isPresented: $showRemoveAlert) {
                Button("Entfernen", role: .destructive) {
                    selected.remove(leagueToRemove)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Deine Punkte für \"\(leagueToRemove)\" werden aus der Globalen Community entfernt. Beim erneuten Hinzufügen startest du bei 0 Punkten.")
            }
        }
        .task {
            await vm.load()
            selected = Set(vm.selectedLeagues)
        }
    }

    private func toggle(_ league: String) {
        if selected.contains(league) && vm.selectedLeagues.contains(league) {
            // Liga war vorher aktiv → Warnung
            leagueToRemove = league
            showRemoveAlert = true
        } else if selected.contains(league) {
            selected.remove(league)
        } else {
            selected.insert(league)
        }
    }

    private func save() {
        isSaving = true
        Task {
            await vm.saveLeagues(Array(selected).sorted())
            isSaving = false
            dismiss()
        }
    }
}

private struct RoundedCornerShape: Shape {
    var cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
    }
}
