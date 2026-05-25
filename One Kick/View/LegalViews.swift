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
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    LegalSection(title: "Angaben gemäß § 5 TMG") {
                        LegalText("Benjamin Diedrich")
                        LegalText("Pfenningsbusch 23")
                        LegalText("22081, Hamburg")
                    }

                    LegalSection(title: "Kontakt") {
                        LegalText("E-Mail: benni.diedrich@gmail.com")
                    }

                    LegalSection(title: "Hinweis") {
                        LegalText("""
                        Diese App wird als privates, nicht-kommerzielles Projekt betrieben. \
                        Es besteht kein eingetragenes Gewerbe.
                        """)
                    }

                    LegalSection(title: "Haftungshinweis") {
                        LegalText("""
                        Die Inhalte dieser App wurden mit größtmöglicher Sorgfalt erstellt. \
                        Da es sich um eine private Testversion handelt, wird keine \
                        Gewährleistung für die Richtigkeit, Vollständigkeit oder \
                        Aktualität der angezeigten Informationen übernommen.
                        """)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Impressum")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Datenschutz

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    LegalSection(title: "Überblick") {
                        LegalText("""
                        Diese App ist ein privates, nicht-kommerzielles Projekt in der \
                        Testphase. Die Datenschutzerklärung informiert darüber, welche \
                        Daten verarbeitet werden und wo.
                        """)
                    }

                    LegalSection(title: "Verantwortlicher (Art. 4 Nr. 7 DSGVO)") {
                        LegalText("Benjamin Diedrich")
                        LegalText("benni.diedrich@gmail.com")
                    }

                    LegalSection(title: "Firebase Authentication") {
                        LegalText("""
                        Für die Anmeldung wird Firebase Authentication von Google LLC \
                        genutzt. Dabei wird deine E-Mail-Adresse auf Servern von Google \
                        (Firebase) gespeichert. Google LLC hat seinen Sitz in den USA; \
                        die Datenübertragung erfolgt auf Basis der \
                        EU-Standardvertragsklauseln.
                        """)
                        LegalText("Datenschutzrichtlinie Firebase: firebase.google.com/support/privacy")
                    }

                    LegalSection(title: "Firebase Firestore (Datenbank)") {
                        LegalText("""
                        Tippdaten, Nutzernamen, Community-Mitgliedschaften und \
                        Spielergebnisse werden in Firebase Firestore (Google LLC) \
                        gespeichert. Diese Daten sind notwendig, um die App-Funktionen \
                        bereitzustellen (Ranglisten, offene Tipps, Community-Übersicht).
                        """)
                        LegalText("""
                        Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO \
                        (Vertragserfüllung / vorvertragliche Maßnahmen).
                        """)
                    }

                    LegalSection(title: "API-Football (Spielplandaten)") {
                        LegalText("""
                        Für Spielpläne, Ergebnisse und Statistiken werden Anfragen an \
                        die API-Football-Schnittstelle gestellt. Es werden dabei keine \
                        personenbezogenen Daten übermittelt.
                        """)
                    }

                    LegalSection(title: "Lokaler Speicher (auf deinem Gerät)") {
                        LegalText("""
                        Einstellungen wie Lieblingsligen, Lieblingsmannschaften und \
                        Anzeigeoptionen werden ausschließlich lokal über UserDefaults \
                        auf deinem Gerät gespeichert und nicht an externe Server \
                        übertragen.
                        """)
                    }

                    LegalSection(title: "Apple App Store / Absturzberichte") {
                        LegalText("""
                        Die App wird über den Apple App Store vertrieben. Apple kann dabei \
                        anonymisierte Absturz- und Nutzungsdaten erfassen. Diese Daten \
                        unterliegen der Datenschutzrichtlinie von Apple \
                        (apple.com/legal/privacy). Die Verarbeitung erfolgt anonym; \
                        eine Identifizierung einzelner Nutzer ist nicht möglich.
                        """)
                    }

                    LegalSection(title: "Deine Rechte (DSGVO)") {
                        LegalText("""
                        Du hast das Recht auf Auskunft (Art. 15), Berichtigung (Art. 16), \
                        Löschung (Art. 17), Einschränkung der Verarbeitung (Art. 18) \
                        sowie das Recht auf Datenübertragbarkeit (Art. 20).
                        """)
                        LegalText("""
                        Zur Ausübung deiner Rechte wende dich per E-Mail an: \
                        benni.diedrich@gmail.com
                        """)
                    }

                    LegalSection(title: "Keine Werbung, kein Tracking") {
                        LegalText("""
                        Diese App enthält keine Werbung, kein Tracking durch \
                        Drittanbieter und keine Analyse-Tools (z. B. Google Analytics).
                        """)
                    }

                    LegalSection(title: "Stand") {
                        LegalText("Mai 2025")
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Datenschutz")
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
