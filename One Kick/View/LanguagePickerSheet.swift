//
//  LanguagePickerSheet.swift
//  One Kick
//
//  Sprachauswahl-Sheet: DE / EN / NL / FR
//

import SwiftUI

struct LanguagePickerSheet: View {
    @EnvironmentObject var lm: LanguageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                List {
                    ForEach(LanguageManager.supportedLanguages, id: \.code) { lang in
                        Button(action: {
                            lm.currentLanguage = lang.code
                            dismiss()
                        }) {
                            HStack(spacing: 14) {
                                Text(lang.flag)
                                    .font(.system(size: 28))
                                Text(lang.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                if lm.currentLanguage == lang.code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.oneKickNeon)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.oneKickBlack)
            }
            .navigationTitle(lm.t("profile.language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lm.t("action.done")) { dismiss() }
                        .foregroundColor(.oneKickNeon)
                }
            }
        }
    }
}
