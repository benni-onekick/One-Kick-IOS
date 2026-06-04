//
//  NationalTeamFlags.swift
//  One Kick
//
//  Flaggen-Emojis für Nationalmannschaften (WM, EM, Nations League).
//  Zero-KB: iOS-native Unicode Regional Indicator Symbols, kein Bild, kein Netzwerk.
//

import Foundation

/// ISO-2-Buchstaben-Code → Flaggen-Emoji ("DE" → 🇩🇪)
func flagEmoji(_ isoCode: String) -> String {
    isoCode.uppercased().unicodeScalars.compactMap {
        Unicode.Scalar(127397 + $0.value)
    }.map(String.init).joined()
}

/// Liga-IDs bei denen Nationalflaggen angezeigt werden sollen
let nationalTeamLeagueIDs: Set<Int> = [1, 4, 5, 6, 32, 960, 1191]

/// API-Football Teamname → ISO-2-Buchstaben-Code
let nationalTeamCodes: [String: String] = [
    // Europa
    "Germany": "DE", "France": "FR", "Spain": "ES", "England": "GB",
    "Portugal": "PT", "Netherlands": "NL", "Belgium": "BE", "Croatia": "HR",
    "Italy": "IT", "Switzerland": "CH", "Austria": "AT", "Denmark": "DK",
    "Sweden": "SE", "Norway": "NO", "Finland": "FI", "Poland": "PL",
    "Czech Republic": "CZ", "Czechia": "CZ", "Hungary": "HU", "Romania": "RO",
    "Slovakia": "SK", "Slovenia": "SI", "Serbia": "RS", "Albania": "AL",
    "Ukraine": "UA", "Scotland": "GB", "Wales": "GB", "Turkey": "TR",
    "Türkiye": "TR", "Greece": "GR", "Georgia": "GE", "Bulgaria": "BG",
    "Iceland": "IS", "Bosnia & Herzegovina": "BA", "Montenegro": "ME",
    "North Macedonia": "MK", "Kosovo": "XK", "Armenia": "AM",
    "Azerbaijan": "AZ", "Kazakhstan": "KZ", "Lithuania": "LT",
    "Latvia": "LV", "Estonia": "EE", "Luxembourg": "LU", "Cyprus": "CY",
    "Faroe Islands": "FO", "Belarus": "BY", "Moldova": "MD", "Russia": "RU",
    "Israel": "IL", "Malta": "MT", "Gibraltar": "GI", "Andorra": "AD",
    "San Marino": "SM", "Liechtenstein": "LI",
    // Südamerika
    "Brazil": "BR", "Argentina": "AR", "Colombia": "CO", "Uruguay": "UY",
    "Chile": "CL", "Ecuador": "EC", "Paraguay": "PY", "Peru": "PE",
    "Venezuela": "VE", "Bolivia": "BO",
    // Nordamerika & Karibik
    "United States": "US", "Mexico": "MX", "Canada": "CA", "Panama": "PA",
    "Costa Rica": "CR", "Honduras": "HN", "Jamaica": "JM", "Cuba": "CU",
    "Trinidad and Tobago": "TT", "Haiti": "HT", "Guatemala": "GT",
    "El Salvador": "SV", "Nicaragua": "NI",
    // Afrika
    "Morocco": "MA", "Senegal": "SN", "Egypt": "EG", "Nigeria": "NG",
    "Ghana": "GH", "Tunisia": "TN", "Cameroon": "CM", "Algeria": "DZ",
    "Ivory Coast": "CI", "Cote d'Ivoire": "CI", "South Africa": "ZA",
    "DR Congo": "CD", "Congo DR": "CD", "Cape Verde Islands": "CV",
    "Cape Verde": "CV", "Angola": "AO", "Mali": "ML", "Guinea": "GN",
    "Benin": "BJ", "Zambia": "ZM", "Uganda": "UG", "Kenya": "KE",
    "Burkina Faso": "BF", "Tanzania": "TZ", "Ethiopia": "ET",
    "Mozambique": "MZ", "Sudan": "SD", "Libya": "LY",
    // Asien
    "Japan": "JP", "South Korea": "KR", "Korea Republic": "KR",
    "Australia": "AU", "Saudi Arabia": "SA", "Iran": "IR", "Qatar": "QA",
    "Iraq": "IQ", "UAE": "AE", "United Arab Emirates": "AE",
    "Uzbekistan": "UZ", "Indonesia": "ID", "China PR": "CN", "China": "CN",
    "India": "IN", "Thailand": "TH", "Vietnam": "VN", "Jordan": "JO",
    "Bahrain": "BH", "Kuwait": "KW", "Oman": "OM", "Syria": "SY",
    "Lebanon": "LB", "Philippines": "PH", "Malaysia": "MY",
    "Singapore": "SG", "Myanmar": "MM",
    // Ozeanien
    "New Zealand": "NZ", "Fiji": "FJ",
]

/// Gibt das Flaggen-Emoji für einen Teamnamen zurück (leer wenn unbekannt)
func nationalTeamFlag(for teamName: String) -> String {
    guard let code = nationalTeamCodes[teamName] else { return "" }
    return flagEmoji(code)
}

/// Englischer API-Teamname → deutscher Anzeigename
let germanTeamNames: [String: String] = [
    // Europa
    "Germany": "Deutschland", "France": "Frankreich", "Spain": "Spanien",
    "England": "England", "Portugal": "Portugal", "Netherlands": "Niederlande",
    "Belgium": "Belgien", "Croatia": "Kroatien", "Italy": "Italien",
    "Switzerland": "Schweiz", "Austria": "Österreich", "Denmark": "Dänemark",
    "Sweden": "Schweden", "Norway": "Norwegen", "Finland": "Finnland",
    "Poland": "Polen", "Czech Republic": "Tschechien", "Czechia": "Tschechien",
    "Hungary": "Ungarn", "Romania": "Rumänien", "Slovakia": "Slowakei",
    "Slovenia": "Slowenien", "Serbia": "Serbien", "Albania": "Albanien",
    "Ukraine": "Ukraine", "Scotland": "Schottland", "Wales": "Wales",
    "Turkey": "Türkei", "Türkiye": "Türkei", "Greece": "Griechenland",
    "Georgia": "Georgien", "Bulgaria": "Bulgarien", "Iceland": "Island",
    "Bosnia & Herzegovina": "Bosnien-Herzegowina", "Montenegro": "Montenegro",
    "North Macedonia": "Nordmazedonien", "Kosovo": "Kosovo",
    "Armenia": "Armenien", "Azerbaijan": "Aserbaidschan",
    "Kazakhstan": "Kasachstan", "Lithuania": "Litauen",
    "Latvia": "Lettland", "Estonia": "Estland", "Luxembourg": "Luxemburg",
    "Cyprus": "Zypern", "Faroe Islands": "Färöer", "Belarus": "Weißrussland",
    "Moldova": "Moldau", "Russia": "Russland", "Israel": "Israel",
    "Malta": "Malta", "Gibraltar": "Gibraltar", "Andorra": "Andorra",
    "San Marino": "San Marino", "Liechtenstein": "Liechtenstein",
    // Südamerika
    "Brazil": "Brasilien", "Argentina": "Argentinien", "Colombia": "Kolumbien",
    "Uruguay": "Uruguay", "Chile": "Chile", "Ecuador": "Ecuador",
    "Paraguay": "Paraguay", "Peru": "Peru", "Venezuela": "Venezuela",
    "Bolivia": "Bolivien",
    // Nordamerika & Karibik
    "United States": "USA", "Mexico": "Mexiko", "Canada": "Kanada",
    "Panama": "Panama", "Costa Rica": "Costa Rica", "Honduras": "Honduras",
    "Jamaica": "Jamaika", "Cuba": "Kuba",
    "Trinidad and Tobago": "Trinidad und Tobago", "Haiti": "Haiti",
    "Guatemala": "Guatemala", "El Salvador": "El Salvador", "Nicaragua": "Nicaragua",
    // Afrika
    "Morocco": "Marokko", "Senegal": "Senegal", "Egypt": "Ägypten",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Tunesien",
    "Cameroon": "Kamerun", "Algeria": "Algerien",
    "Ivory Coast": "Elfenbeinküste", "Cote d'Ivoire": "Elfenbeinküste",
    "South Africa": "Südafrika", "DR Congo": "DR Kongo", "Congo DR": "DR Kongo",
    "Cape Verde Islands": "Kap Verde", "Cape Verde": "Kap Verde",
    "Angola": "Angola", "Mali": "Mali", "Guinea": "Guinea",
    "Benin": "Benin", "Zambia": "Sambia", "Uganda": "Uganda",
    "Kenya": "Kenia", "Burkina Faso": "Burkina Faso",
    // Asien & Ozeanien
    "Japan": "Japan", "South Korea": "Südkorea", "Korea Republic": "Südkorea",
    "Australia": "Australien", "Saudi Arabia": "Saudi-Arabien",
    "Iran": "Iran", "Qatar": "Katar", "Iraq": "Irak",
    "UAE": "Ver. Arab. Emirate", "United Arab Emirates": "Ver. Arab. Emirate",
    "Uzbekistan": "Usbekistan", "Indonesia": "Indonesien",
    "China PR": "China", "China": "China", "India": "Indien",
    "Thailand": "Thailand", "Vietnam": "Vietnam", "Jordan": "Jordanien",
    "Bahrain": "Bahrain", "Kuwait": "Kuwait", "Oman": "Oman",
    "Syria": "Syrien", "Lebanon": "Libanon", "Philippines": "Philippinen",
    "New Zealand": "Neuseeland", "Fiji": "Fidschi",
]

let dutchTeamNames: [String: String] = [
    // Europa
    "Germany": "Duitsland", "France": "Frankrijk", "Spain": "Spanje",
    "England": "Engeland", "Portugal": "Portugal", "Netherlands": "Nederland",
    "Belgium": "Belgi\u{00eb}", "Croatia": "Kroati\u{00eb}", "Italy": "Itali\u{00eb}",
    "Switzerland": "Zwitserland", "Austria": "Oostenrijk", "Denmark": "Denemarken",
    "Sweden": "Zweden", "Norway": "Noorwegen", "Finland": "Finland",
    "Poland": "Polen", "Czech Republic": "Tsjechisch", "Czechia": "Tsjechisch",
    "Hungary": "Hongarije", "Romania": "Roemeni\u{00eb}", "Slovakia": "Slowakije",
    "Slovenia": "Sloveni\u{00eb}", "Serbia": "Servi\u{00eb}", "Albania": "Albani\u{00eb}",
    "Ukraine": "Oekra\u{00ef}ne", "Scotland": "Schotland", "Wales": "Wales",
    "Turkey": "Turkije", "T\u{00fc}rkiye": "Turkije", "Greece": "Griekenland",
    "Georgia": "Georgi\u{00eb}", "Bulgaria": "Bulgarije", "Iceland": "IJsland",
    "Bosnia & Herzegovina": "Bosni\u{00eb}", "North Macedonia": "Noord-Macedoni\u{00eb}",
    "Bosnia": "Bosni\u{00eb}", "Bosnia and Herzegovina": "Bosni\u{00eb}",
    // Zuid-Amerika
    "Brazil": "Brazili\u{00eb}", "Argentina": "Argentini\u{00eb}", "Colombia": "Colombia",
    "Uruguay": "Uruguay", "Chile": "Chili", "Ecuador": "Ecuador",
    "Paraguay": "Paraguay", "Peru": "Peru", "Venezuela": "Venezuela",
    // Noord-Amerika
    "United States": "VS", "USA": "VS", "Mexico": "Mexico", "Canada": "Canada",
    "Panama": "Panama", "Haiti": "Ha\u{00ef}ti", "Costa Rica": "Costa Rica",
    // Afrika
    "Morocco": "Marokko", "Senegal": "Senegal", "Egypt": "Egypte",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Tunesi\u{00eb}",
    "Cameroon": "Kameroen", "Algeria": "Algerije",
    "Ivory Coast": "Ivoorkust", "Cote d'Ivoire": "Ivoorkust",
    "South Africa": "Zuid-Afrika", "DR Congo": "DR Congo", "Congo DR": "DR Congo",
    "Cape Verde Islands": "Kaapverdi\u{00eb}", "Cape Verde": "Kaapverdi\u{00eb}",
    // Azi\u{00eb} & Oceani\u{00eb}
    "Japan": "Japan", "South Korea": "Zuid-Korea", "Korea Republic": "Zuid-Korea",
    "Australia": "Australi\u{00eb}", "Saudi Arabia": "Saoedi-Arabi\u{00eb}",
    "Iran": "Iran", "Qatar": "Qatar", "Iraq": "Irak",
    "Uzbekistan": "Oezbekistan", "Jordan": "Jordani\u{00eb}",
    "New Zealand": "Nieuw-Zeeland",
    "Curacao": "Cura\u{00e7}ao",
]

let frenchTeamNames: [String: String] = [
    // Europe
    "Germany": "Allemagne", "France": "France", "Spain": "Espagne",
    "England": "Angleterre", "Portugal": "Portugal", "Netherlands": "Pays-Bas",
    "Belgium": "Belgique", "Croatia": "Croatie", "Italy": "Italie",
    "Switzerland": "Suisse", "Austria": "Autriche", "Denmark": "Danemark",
    "Sweden": "Su\u{00e8}de", "Norway": "Norv\u{00e8}ge", "Finland": "Finlande",
    "Poland": "Pologne", "Czech Republic": "R\u{00e9}publique tch\u{00e8}que",
    "Czechia": "R\u{00e9}publique tch\u{00e8}que",
    "Hungary": "Hongrie", "Romania": "Roumanie", "Slovakia": "Slovaquie",
    "Slovenia": "Slov\u{00e9}nie", "Serbia": "Serbie", "Albania": "Albanie",
    "Ukraine": "Ukraine", "Scotland": "\u{00c9}cosse", "Wales": "Pays de Galles",
    "Turkey": "Turquie", "T\u{00fc}rkiye": "Turquie", "Greece": "Gr\u{00e8}ce",
    "Georgia": "G\u{00e9}orgie", "Bulgaria": "Bulgarie", "Iceland": "Islande",
    "Bosnia & Herzegovina": "Bosnie-Herz\u{00e9}govine",
    "Bosnia": "Bosnie", "Bosnia and Herzegovina": "Bosnie-Herz\u{00e9}govine",
    "North Macedonia": "Mac\u{00e9}doine du Nord",
    // Am\u{00e9}rique du Sud
    "Brazil": "Br\u{00e9}sil", "Argentina": "Argentine", "Colombia": "Colombie",
    "Uruguay": "Uruguay", "Chile": "Chili", "Ecuador": "\u{00c9}quateur",
    "Paraguay": "Paraguay", "Peru": "P\u{00e9}rou", "Venezuela": "Venezuela",
    // Am\u{00e9}rique du Nord
    "United States": "\u{00c9}tats-Unis", "USA": "\u{00c9}tats-Unis",
    "Mexico": "Mexique", "Canada": "Canada", "Panama": "Panama",
    "Haiti": "Ha\u{00ef}ti", "Costa Rica": "Costa Rica",
    // Afrique
    "Morocco": "Maroc", "Senegal": "S\u{00e9}n\u{00e9}gal", "Egypt": "\u{00c9}gypte",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Tunisie",
    "Cameroon": "Cameroun", "Algeria": "Alg\u{00e9}rie",
    "Ivory Coast": "C\u{00f4}te d'Ivoire", "Cote d'Ivoire": "C\u{00f4}te d'Ivoire",
    "South Africa": "Afrique du Sud", "DR Congo": "RD Congo", "Congo DR": "RD Congo",
    "Cape Verde Islands": "Cap-Vert", "Cape Verde": "Cap-Vert",
    // Asie & Oc\u{00e9}anie
    "Japan": "Japon", "South Korea": "Cor\u{00e9}e du Sud", "Korea Republic": "Cor\u{00e9}e du Sud",
    "Australia": "Australie", "Saudi Arabia": "Arabie saoudite",
    "Iran": "Iran", "Qatar": "Qatar", "Iraq": "Irak",
    "Uzbekistan": "Ouzb\u{00e9}kistan", "Jordan": "Jordanie",
    "New Zealand": "Nouvelle-Z\u{00e9}lande",
    "Curacao": "Cura\u{00e7}ao",
]

func localizedTeamName(_ apiName: String) -> String {
    switch LanguageManager.shared.currentLanguage {
    case "de": return germanTeamNames[apiName] ?? apiName
    case "nl": return dutchTeamNames[apiName] ?? apiName
    case "fr": return frenchTeamNames[apiName] ?? apiName
    default:   return apiName  // "en" → Original API-Name
    }
}

/// API-Rundenname → deutscher Anzeigename (WM/EM/KO-Runden)
func localizedRoundName(_ round: String) -> String {
    if round.lowercased().hasPrefix("group stage") {
        let num = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }.last
        return num != nil ? "Gruppenphase Runde \(num!)" : "Gruppenphase"
    }
    let map: [String: String] = [
        "Round of 32": "Runde der 32",
        "Round of 16": "Achtelfinale",
        "Quarter-finals": "Viertelfinale",
        "Semi-finals": "Halbfinale",
        "Final": "Finale",
        "3rd Place Final": "Spiel um Platz 3",
        "Round of 48": "Gruppenphase",
        "Regular Season": "Hauptrunde",
    ]
    return map.first(where: { round.localizedCaseInsensitiveContains($0.key) })?.value ?? round
}

/// Teamname mit Flagge und deutschem Namen
func teamNameWithFlag(_ name: String) -> String {
    let flag = nationalTeamFlag(for: name)
    let displayName = localizedTeamName(name)
    return flag.isEmpty ? displayName : "\(flag) \(displayName)"
}
