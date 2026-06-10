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
    "United States": "US", "USA": "US", "Mexico": "MX", "Canada": "CA", "Panama": "PA",
    "Costa Rica": "CR", "Honduras": "HN", "Jamaica": "JM", "Cuba": "CU",
    "Trinidad and Tobago": "TT", "Haiti": "HT", "Guatemala": "GT",
    "El Salvador": "SV", "Nicaragua": "NI", "Curacao": "CW", "Curaçao": "CW",
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

/// Sonderflaggen für UK-Unterregionen (eigene Flagge statt 🇬🇧) – Unicode-Tag-Sequenzen.
private let subdivisionFlags: [String: String] = [
    "England":  "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}",
    "Scotland": "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}",
    "Wales":    "\u{1F3F4}\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}",
]

/// Gibt das Flaggen-Emoji für einen Teamnamen zurück (leer wenn unbekannt)
func nationalTeamFlag(for teamName: String) -> String {
    if let sub = subdivisionFlags[teamName] { return sub }
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

let italianTeamNames: [String: String] = [
    "Germany": "Germania", "France": "Francia", "Spain": "Spagna",
    "England": "Inghilterra", "Portugal": "Portogallo", "Netherlands": "Paesi Bassi",
    "Belgium": "Belgio", "Croatia": "Croazia", "Italy": "Italia",
    "Switzerland": "Svizzera", "Austria": "Austria", "Denmark": "Danimarca",
    "Sweden": "Svezia", "Norway": "Norvegia", "Finland": "Finlandia",
    "Poland": "Polonia", "Czech Republic": "Rep. Ceca", "Czechia": "Rep. Ceca",
    "Hungary": "Ungheria", "Romania": "Romania", "Slovakia": "Slovacchia",
    "Slovenia": "Slovenia", "Serbia": "Serbia", "Albania": "Albania",
    "Ukraine": "Ucraina", "Scotland": "Scozia", "Wales": "Galles",
    "Turkey": "Turchia", "Türkiye": "Turchia", "Greece": "Grecia",
    "Georgia": "Georgia", "Bulgaria": "Bulgaria", "Iceland": "Islanda",
    "Bosnia & Herzegovina": "Bosnia-Erzegovina", "Montenegro": "Montenegro",
    "North Macedonia": "Macedonia del Nord", "Kosovo": "Kosovo",
    "Armenia": "Armenia", "Azerbaijan": "Azerbaigian",
    "Kazakhstan": "Kazakistan", "Lithuania": "Lituania",
    "Latvia": "Lettonia", "Estonia": "Estonia", "Luxembourg": "Lussemburgo",
    "Cyprus": "Cipro", "Faroe Islands": "Isole Fær Øer", "Belarus": "Bielorussia",
    "Moldova": "Moldavia", "Russia": "Russia", "Israel": "Israele",
    "Malta": "Malta", "Gibraltar": "Gibilterra", "Andorra": "Andorra",
    "San Marino": "San Marino", "Liechtenstein": "Liechtenstein",
    "Brazil": "Brasile", "Argentina": "Argentina", "Colombia": "Colombia",
    "Uruguay": "Uruguay", "Chile": "Cile", "Ecuador": "Ecuador",
    "Paraguay": "Paraguay", "Peru": "Perù", "Venezuela": "Venezuela",
    "Bolivia": "Bolivia",
    "United States": "USA", "Mexico": "Messico", "Canada": "Canada",
    "Panama": "Panama", "Costa Rica": "Costa Rica", "Honduras": "Honduras",
    "Jamaica": "Giamaica", "Cuba": "Cuba",
    "Trinidad and Tobago": "Trinidad e Tobago", "Haiti": "Haiti",
    "Guatemala": "Guatemala", "El Salvador": "El Salvador", "Nicaragua": "Nicaragua",
    "Morocco": "Marocco", "Senegal": "Senegal", "Egypt": "Egitto",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Tunisia",
    "Cameroon": "Camerun", "Algeria": "Algeria",
    "Ivory Coast": "Costa d'Avorio", "Cote d'Ivoire": "Costa d'Avorio",
    "South Africa": "Sudafrica", "DR Congo": "RD Congo", "Congo DR": "RD Congo",
    "Cape Verde Islands": "Capo Verde", "Cape Verde": "Capo Verde",
    "Angola": "Angola", "Mali": "Mali", "Guinea": "Guinea",
    "Benin": "Benin", "Zambia": "Zambia", "Uganda": "Uganda",
    "Kenya": "Kenya", "Burkina Faso": "Burkina Faso",
    "Japan": "Giappone", "South Korea": "Corea del Sud", "Korea Republic": "Corea del Sud",
    "Australia": "Australia", "Saudi Arabia": "Arabia Saudita",
    "Iran": "Iran", "Qatar": "Qatar", "Iraq": "Iraq",
    "UAE": "Emirati Arabi Uniti", "United Arab Emirates": "Emirati Arabi Uniti",
    "Uzbekistan": "Uzbekistan", "Indonesia": "Indonesia",
    "China PR": "Cina", "China": "Cina", "India": "India",
    "Thailand": "Thailandia", "Vietnam": "Vietnam", "Jordan": "Giordania",
    "Bahrain": "Bahrein", "Kuwait": "Kuwait", "Oman": "Oman",
    "Syria": "Siria", "Lebanon": "Libano", "Philippines": "Filippine",
    "New Zealand": "Nuova Zelanda", "Fiji": "Figi",
]

let spanishTeamNames: [String: String] = [
    "Germany": "Alemania", "France": "Francia", "Spain": "España",
    "England": "Inglaterra", "Portugal": "Portugal", "Netherlands": "Países Bajos",
    "Belgium": "Bélgica", "Croatia": "Croacia", "Italy": "Italia",
    "Switzerland": "Suiza", "Austria": "Austria", "Denmark": "Dinamarca",
    "Sweden": "Suecia", "Norway": "Noruega", "Finland": "Finlandia",
    "Poland": "Polonia", "Czech Republic": "República Checa", "Czechia": "Chequia",
    "Hungary": "Hungría", "Romania": "Rumanía", "Slovakia": "Eslovaquia",
    "Slovenia": "Eslovenia", "Serbia": "Serbia", "Albania": "Albania",
    "Ukraine": "Ucrania", "Scotland": "Escocia", "Wales": "Gales",
    "Turkey": "Turquía", "Türkiye": "Turquía", "Greece": "Grecia",
    "Georgia": "Georgia", "Bulgaria": "Bulgaria", "Iceland": "Islandia",
    "Bosnia & Herzegovina": "Bosnia y Herzegovina", "Montenegro": "Montenegro",
    "North Macedonia": "Macedonia del Norte", "Kosovo": "Kosovo",
    "Armenia": "Armenia", "Azerbaijan": "Azerbaiyán",
    "Kazakhstan": "Kazajistán", "Lithuania": "Lituania",
    "Latvia": "Letonia", "Estonia": "Estonia", "Luxembourg": "Luxemburgo",
    "Cyprus": "Chipre", "Faroe Islands": "Islas Feroe", "Belarus": "Bielorrusia",
    "Moldova": "Moldavia", "Russia": "Rusia", "Israel": "Israel",
    "Malta": "Malta", "Gibraltar": "Gibraltar", "Andorra": "Andorra",
    "San Marino": "San Marino", "Liechtenstein": "Liechtenstein",
    "Brazil": "Brasil", "Argentina": "Argentina", "Colombia": "Colombia",
    "Uruguay": "Uruguay", "Chile": "Chile", "Ecuador": "Ecuador",
    "Paraguay": "Paraguay", "Peru": "Perú", "Venezuela": "Venezuela",
    "Bolivia": "Bolivia",
    "United States": "EE. UU.", "Mexico": "México", "Canada": "Canadá",
    "Panama": "Panamá", "Costa Rica": "Costa Rica", "Honduras": "Honduras",
    "Jamaica": "Jamaica", "Cuba": "Cuba",
    "Trinidad and Tobago": "Trinidad y Tobago", "Haiti": "Haití",
    "Guatemala": "Guatemala", "El Salvador": "El Salvador", "Nicaragua": "Nicaragua",
    "Morocco": "Marruecos", "Senegal": "Senegal", "Egypt": "Egipto",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Túnez",
    "Cameroon": "Camerún", "Algeria": "Argelia",
    "Ivory Coast": "Costa de Marfil", "Cote d'Ivoire": "Costa de Marfil",
    "South Africa": "Sudáfrica", "DR Congo": "RD Congo", "Congo DR": "RD Congo",
    "Cape Verde Islands": "Cabo Verde", "Cape Verde": "Cabo Verde",
    "Angola": "Angola", "Mali": "Malí", "Guinea": "Guinea",
    "Benin": "Benín", "Zambia": "Zambia", "Uganda": "Uganda",
    "Kenya": "Kenia", "Burkina Faso": "Burkina Faso",
    "Japan": "Japón", "South Korea": "Corea del Sur", "Korea Republic": "Corea del Sur",
    "Australia": "Australia", "Saudi Arabia": "Arabia Saudí",
    "Iran": "Irán", "Qatar": "Catar", "Iraq": "Irak",
    "UAE": "Emiratos Árabes Unidos", "United Arab Emirates": "Emiratos Árabes Unidos",
    "Uzbekistan": "Uzbekistán", "Indonesia": "Indonesia",
    "China PR": "China", "China": "China", "India": "India",
    "Thailand": "Tailandia", "Vietnam": "Vietnam", "Jordan": "Jordania",
    "Bahrain": "Baréin", "Kuwait": "Kuwait", "Oman": "Omán",
    "Syria": "Siria", "Lebanon": "Líbano", "Philippines": "Filipinas",
    "New Zealand": "Nueva Zelanda", "Fiji": "Fiyi",
]

let danishTeamNames: [String: String] = [
    "Germany": "Tyskland", "France": "Frankrig", "Spain": "Spanien",
    "England": "England", "Portugal": "Portugal", "Netherlands": "Holland",
    "Belgium": "Belgien", "Croatia": "Kroatien", "Italy": "Italien",
    "Switzerland": "Schweiz", "Austria": "Østrig", "Denmark": "Danmark",
    "Sweden": "Sverige", "Norway": "Norge", "Finland": "Finland",
    "Poland": "Polen", "Czech Republic": "Tjekkiet", "Czechia": "Tjekkiet",
    "Hungary": "Ungarn", "Romania": "Rumænien", "Slovakia": "Slovakiet",
    "Slovenia": "Slovenien", "Serbia": "Serbien", "Albania": "Albanien",
    "Ukraine": "Ukraine", "Scotland": "Skotland", "Wales": "Wales",
    "Turkey": "Tyrkiet", "Türkiye": "Tyrkiet", "Greece": "Grækenland",
    "Georgia": "Georgien", "Bulgaria": "Bulgarien", "Iceland": "Island",
    "Bosnia & Herzegovina": "Bosnien-Hercegovina", "Montenegro": "Montenegro",
    "North Macedonia": "Nordmakedonien", "Kosovo": "Kosovo",
    "Armenia": "Armenien", "Azerbaijan": "Aserbajdsjan",
    "Kazakhstan": "Kasakhstan", "Lithuania": "Litauen",
    "Latvia": "Letland", "Estonia": "Estland", "Luxembourg": "Luxembourg",
    "Cyprus": "Cypern", "Faroe Islands": "Færøerne", "Belarus": "Hviderusland",
    "Moldova": "Moldova", "Russia": "Rusland", "Israel": "Israel",
    "Malta": "Malta", "Gibraltar": "Gibraltar", "Andorra": "Andorra",
    "San Marino": "San Marino", "Liechtenstein": "Liechtenstein",
    "Brazil": "Brasilien", "Argentina": "Argentina", "Colombia": "Colombia",
    "Uruguay": "Uruguay", "Chile": "Chile", "Ecuador": "Ecuador",
    "Paraguay": "Paraguay", "Peru": "Peru", "Venezuela": "Venezuela",
    "Bolivia": "Bolivia",
    "United States": "USA", "Mexico": "Mexico", "Canada": "Canada",
    "Panama": "Panama", "Costa Rica": "Costa Rica", "Honduras": "Honduras",
    "Jamaica": "Jamaica", "Cuba": "Cuba",
    "Trinidad and Tobago": "Trinidad og Tobago", "Haiti": "Haiti",
    "Guatemala": "Guatemala", "El Salvador": "El Salvador", "Nicaragua": "Nicaragua",
    "Morocco": "Marokko", "Senegal": "Senegal", "Egypt": "Egypten",
    "Nigeria": "Nigeria", "Ghana": "Ghana", "Tunisia": "Tunesien",
    "Cameroon": "Cameroun", "Algeria": "Algeriet",
    "Ivory Coast": "Elfenbenskysten", "Cote d'Ivoire": "Elfenbenskysten",
    "South Africa": "Sydafrika", "DR Congo": "DR Congo", "Congo DR": "DR Congo",
    "Cape Verde Islands": "Kap Verde", "Cape Verde": "Kap Verde",
    "Angola": "Angola", "Mali": "Mali", "Guinea": "Guinea",
    "Benin": "Benin", "Zambia": "Zambia", "Uganda": "Uganda",
    "Kenya": "Kenya", "Burkina Faso": "Burkina Faso",
    "Japan": "Japan", "South Korea": "Sydkorea", "Korea Republic": "Sydkorea",
    "Australia": "Australien", "Saudi Arabia": "Saudi-Arabien",
    "Iran": "Iran", "Qatar": "Qatar", "Iraq": "Irak",
    "UAE": "Forenede Arabiske Emirater", "United Arab Emirates": "Forenede Arabiske Emirater",
    "Uzbekistan": "Usbekistan", "Indonesia": "Indonesien",
    "China PR": "Kina", "China": "Kina", "India": "Indien",
    "Thailand": "Thailand", "Vietnam": "Vietnam", "Jordan": "Jordan",
    "Bahrain": "Bahrain", "Kuwait": "Kuwait", "Oman": "Oman",
    "Syria": "Syrien", "Lebanon": "Libanon", "Philippines": "Filippinerne",
    "New Zealand": "New Zealand", "Fiji": "Fiji",
]

func localizedTeamName(_ apiName: String) -> String {
    switch LanguageManager.shared.currentLanguage {
    case "de": return germanTeamNames[apiName] ?? apiName
    case "nl": return dutchTeamNames[apiName] ?? apiName
    case "fr": return frenchTeamNames[apiName] ?? apiName
    case "it": return italianTeamNames[apiName] ?? apiName
    case "es": return spanishTeamNames[apiName] ?? apiName
    case "da": return danishTeamNames[apiName] ?? apiName
    default:   return apiName  // "en" → Original API-Name
    }
}

/// API-Rundenname → lokalisierter Anzeigename (WM/EM/KO-Runden), je nach eingestellter Sprache.
func localizedRoundName(_ round: String) -> String {
    let lang = LanguageManager.shared.currentLanguage

    // Gruppenphase (ggf. mit Rundennummer)
    if round.lowercased().hasPrefix("group stage") {
        let num = round.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }.last
        let groupBase: String
        let groupRound: (Int) -> String
        switch lang {
        case "en": groupBase = "Group Stage";    groupRound = { "Group Stage Round \($0)" }
        case "fr": groupBase = "Phase de groupes"; groupRound = { "Phase de groupes - Journée \($0)" }
        case "nl": groupBase = "Groepsfase";      groupRound = { "Groepsfase ronde \($0)" }
        case "it": groupBase = "Fase a gironi";   groupRound = { "Fase a gironi - Turno \($0)" }
        case "es": groupBase = "Fase de grupos";  groupRound = { "Fase de grupos - Jornada \($0)" }
        case "da": groupBase = "Gruppespil";      groupRound = { "Gruppespil runde \($0)" }
        default:   groupBase = "Gruppenphase";    groupRound = { "Gruppenphase Runde \($0)" }
        }
        return num != nil ? groupRound(num!) : groupBase
    }

    // K.-o.-Runden: GEORDNETE Liste — spezifischere Begriffe (die "Final" enthalten) zuerst,
    // sonst würde z.B. "Semi-finals" fälschlich auf den "Final"-Eintrag matchen.
    let maps: [String: [(key: String, value: String)]] = [
        "de": [("Round of 32","Runde der 32"), ("Round of 16","Achtelfinale"), ("Quarter-finals","Viertelfinale"), ("Semi-finals","Halbfinale"), ("3rd Place Final","Spiel um Platz 3"), ("Final","Finale"), ("Round of 48","Gruppenphase"), ("Regular Season","Hauptrunde")],
        "en": [("Round of 32","Round of 32"), ("Round of 16","Round of 16"), ("Quarter-finals","Quarter-finals"), ("Semi-finals","Semi-finals"), ("3rd Place Final","Third-place play-off"), ("Final","Final"), ("Round of 48","Group Stage"), ("Regular Season","Regular Season")],
        "fr": [("Round of 32","Seizièmes de finale"), ("Round of 16","Huitièmes de finale"), ("Quarter-finals","Quarts de finale"), ("Semi-finals","Demi-finales"), ("3rd Place Final","Match pour la 3e place"), ("Final","Finale"), ("Round of 48","Phase de groupes"), ("Regular Season","Saison régulière")],
        "nl": [("Round of 32","Zestiende finale"), ("Round of 16","Achtste finale"), ("Quarter-finals","Kwartfinale"), ("Semi-finals","Halve finale"), ("3rd Place Final","Troostfinale"), ("Final","Finale"), ("Round of 48","Groepsfase"), ("Regular Season","Reguliere seizoen")],
        "it": [("Round of 32","Sedicesimi di finale"), ("Round of 16","Ottavi di finale"), ("Quarter-finals","Quarti di finale"), ("Semi-finals","Semifinali"), ("3rd Place Final","Finale 3º posto"), ("Final","Finale"), ("Round of 48","Fase a gironi"), ("Regular Season","Stagione regolare")],
        "es": [("Round of 32","Dieciseisavos de final"), ("Round of 16","Octavos de final"), ("Quarter-finals","Cuartos de final"), ("Semi-finals","Semifinales"), ("3rd Place Final","Partido por el tercer puesto"), ("Final","Final"), ("Round of 48","Fase de grupos"), ("Regular Season","Temporada regular")],
        "da": [("Round of 32","1/16-finale"), ("Round of 16","1/8-finale"), ("Quarter-finals","Kvartfinale"), ("Semi-finals","Semifinale"), ("3rd Place Final","Bronzekamp"), ("Final","Finale"), ("Round of 48","Gruppespil"), ("Regular Season","Grundspil")],
    ]
    let map = maps[lang] ?? maps["de"]!
    return map.first(where: { round.localizedCaseInsensitiveContains($0.key) })?.value ?? round
}

/// Teamname mit Flagge und deutschem Namen
func teamNameWithFlag(_ name: String) -> String {
    let flag = nationalTeamFlag(for: name)
    let displayName = localizedTeamName(name)
    return flag.isEmpty ? displayName : "\(flag) \(displayName)"
}
