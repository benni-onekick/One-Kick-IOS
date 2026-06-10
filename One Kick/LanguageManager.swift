//
//  LanguageManager.swift
//  One Kick
//
//  In-App Sprachauswahl: DE / EN / NL / FR
//

import SwiftUI

@MainActor
class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    static let supportedLanguages: [(code: String, name: String, flag: String)] = [
        ("de", "Deutsch",    "🇩🇪"),
        ("en", "English",    "🇬🇧"),
        ("nl", "Nederlands", "🇳🇱"),
        ("fr", "Français",   "🇫🇷"),
        ("it", "Italiano",   "🇮🇹"),
        ("es", "Español",    "🇪🇸"),
        ("da", "Dansk",      "🇩🇰"),
    ]

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            loadBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage")
            ?? Locale.current.language.languageCode?.identifier
            ?? "de"
        let supported = LanguageManager.supportedLanguages.map(\.code)
        currentLanguage = supported.contains(saved) ? saved : "de"
        loadBundle()
    }

    private func loadBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main
        }
    }

    func t(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
