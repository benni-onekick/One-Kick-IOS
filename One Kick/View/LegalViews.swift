//
//  LegalViews.swift
//  One Kick
//
//  Impressum und Datenschutzerklärung als In-App-Views.
//  Aufruf über ProfileView → NavigationLink (kein eigenes NavigationStack nötig).
//
//  PLATZHALTER zum Ausfüllen:
//    [Dein Name]                  → vollständiger Name
//    [Deine Straße und Hausnummer]
//    [PLZ Ort]
//    [deine@email.de]
//

import SwiftUI

// MARK: - Impressum

struct ImpressumView: View {
    private let lm = LanguageManager.shared
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    LegalSection(title: lm.t("legal.impressum.section1")) {
                        LegalText("Benjamin Diedrich")
                        LegalText("Pfenningsbusch 23")
                        LegalText("22081, Hamburg")
                    }

                    LegalSection(title: lm.t("legal.impressum.section2")) {
                        LegalText("E-Mail: benni.diedrich@gmail.com")
                    }

                    LegalSection(title: lm.t("legal.impressum.section3")) {
                        LegalText(lm.t("legal.impressum.note"))
                    }

                    LegalSection(title: lm.t("legal.impressum.section4")) {
                        LegalText(lm.t("legal.impressum.liability"))
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle(lm.t("legal.impressum.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Datenschutz

struct PrivacyPolicyView: View {
    private let lm = LanguageManager.shared
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    LegalSection(title: lm.t("legal.privacy.s1.title")) {
                        LegalText(lm.t("legal.privacy.s1.text"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s2.title")) {
                        LegalText("Benjamin Diedrich")
                        LegalText("benni.diedrich@gmail.com")
                    }

                    LegalSection(title: lm.t("legal.privacy.s3.title")) {
                        LegalText(lm.t("legal.privacy.s3.text"))
                        LegalText(lm.t("legal.privacy.s3.link"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s4.title")) {
                        LegalText(lm.t("legal.privacy.s4.intro"))
                        LegalText(lm.t("legal.privacy.s4.b1"))
                        LegalText(lm.t("legal.privacy.s4.b2"))
                        LegalText(lm.t("legal.privacy.s4.b3"))
                        LegalText(lm.t("legal.privacy.s4.b4"))
                        LegalText(lm.t("legal.privacy.s4.b5"))
                        LegalText(lm.t("legal.privacy.s4.legal"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s5.title")) {
                        LegalText(lm.t("legal.privacy.s5.text1"))
                        LegalText(lm.t("legal.privacy.s5.text2"))
                        LegalText(lm.t("legal.privacy.s5.link1"))
                        LegalText(lm.t("legal.privacy.s5.link2"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s6.title")) {
                        LegalText(lm.t("legal.privacy.s6.text"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s7.title")) {
                        LegalText(lm.t("legal.privacy.s7.text"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s8.title")) {
                        LegalText(lm.t("legal.privacy.s8.text"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s9.title")) {
                        LegalText(lm.t("legal.privacy.s9.text1"))
                        LegalText(lm.t("legal.privacy.s9.text2"))
                    }

                    LegalSection(title: lm.t("legal.privacy.s10.title")) {
                        LegalText(lm.t("legal.privacy.s10.text"))
                    }

                    LegalSection(title: lm.t("legal.privacy.stand")) {
                        LegalText(lm.t("legal.privacy.date"))
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle(lm.t("legal.privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Hilfkomponenten

private struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.4)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.oneKickDarkGray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

private struct LegalText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }
}
