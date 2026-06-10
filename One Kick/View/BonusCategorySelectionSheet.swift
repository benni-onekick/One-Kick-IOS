//
//  BonusCategorySelectionSheet.swift
//  One Kick
//
//  Analog zu LeagueSelectionSheet – wählt aktive Bonus-Kategorien für eine Community.
//

import SwiftUI

private struct BonusCategory {
    let name: String
    let categories: [String]
}

struct BonusCategorySelectionSheet: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) var dismiss

    private let groups: [BonusCategory] = [
        BonusCategory(name: "Allgemein", categories: [
            "Torschützenkönig", "Meiste Vorlagen",
            "Meiste Tore (Team)", "Meiste Gegentore", "Endtabelle"
        ]),
        BonusCategory(name: "Specials", categories: [
            "Meiste Aluminium-Treffer", "Meiste Karten", "Meiste Zu-Null-Spiele"
        ]),
        BonusCategory(name: "KO-Runden", categories: [
            "Sieger tippen", "Finalisten tippen", "Halbfinalisten tippen"
        ]),
        BonusCategory(name: "WM / EM", categories: [groupStageCategory])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.name) { idx, group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.name.uppercased())
                                    .font(.caption).bold()
                                    .foregroundColor(.oneKickNeon)
                                    .padding(.leading, 5)
                                    .padding(.horizontal)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                                    spacing: 12
                                ) {
                                    ForEach(group.categories, id: \.self) { cat in
                                        LeagueSelectionChip(
                                            title: cat,
                                            isSelected: isOn(cat),
                                            onTap: { toggle(cat) }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 20)

                            if idx < groups.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Bonus-Tipps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Alle") {
                        HapticManager.instance.impact(style: .light)
                        selected = Set(allBonusCategories)
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        HapticManager.instance.impact(style: .light)
                        dismiss()
                    }
                    .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
        }
    }

    private func isOn(_ cat: String) -> Bool {
        if cat == groupStageCategory {
            return wmGroupCategories.allSatisfy { selected.contains($0) }
        }
        return selected.contains(cat)
    }

    private func toggle(_ cat: String) {
        HapticManager.instance.impact(style: .light)
        if cat == groupStageCategory {
            if wmGroupCategories.allSatisfy({ selected.contains($0) }) {
                wmGroupCategories.forEach { selected.remove($0) }
            } else {
                wmGroupCategories.forEach { selected.insert($0) }
            }
        } else if selected.contains(cat) {
            selected.remove(cat)
        } else {
            selected.insert(cat)
        }
    }
}
