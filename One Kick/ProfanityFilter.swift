import Foundation

struct ProfanityFilter {

    private static let blockedWords: Set<String> = [
        // Deutsch – Sexuell
        "ficken", "ficker", "fick", "fotze", "möse", "muschi", "schwanz",
        "wichsen", "wichser", "wichse", "bumsen", "vögeln", "nutte", "hure", "bordell",
        "porno", "dildo", "blasen", "handjob", "blowjob", "orgie",
        "titten", "arschficker", "scheiße", "scheißkerl", "drecksau",
        // Deutsch – fehlende Basisformen
        "arsch", "arschloch", "schlampe", "schwuchtel", "spast", "spastiker",
        "missgeburt", "kacke", "kack", "pisser", "dreckschwein", "vollidiot",
        "wixer", "verpisst",
        // Deutsch – Gewalt
        "umbringen", "abstechen", "erschießen", "ich kill", "ich töte",
        "vergewaltigen", "vergewaltigung", "mörder",
        // Deutsch – Beleidigungen/Rassismus
        "hurensohn", "hurenkind", "wichsgesicht", "dreckskerl",
        "kanake", "neger", "judensau", "nazi", "heil hitler",
        // Englisch – Sexuell
        "fuck", "fucker", "fucking", "pussy", "cunt", "cock",
        "bitch", "slut", "whore", "porn",
        // Englisch – fehlende Standardbegriffe
        "shit", "bullshit", "wanker", "bastard", "dickhead", "asshole",
        "motherfucker", "fuckhead", "dumbass", "prick", "tosser", "twat",
        "son of a bitch",
        // Englisch – Gewalt
        "kill you", "i will kill", "murder", "rape", "rapist",
        "suicide", "shoot you", "stab you",
        // Englisch – Beleidigungen/Rassismus
        "nigger", "nigga", "faggot", "retard", "kike", "spic", "chink",
        "cracker", "wetback", "towelhead", "gook", "beaner", "coon",
        "zipperhead", "sandnigger"
    ]

    static func containsProfanity(_ text: String) -> Bool {
        let lower = text.lowercased()
        return blockedWords.contains { lower.contains($0) }
    }
}
