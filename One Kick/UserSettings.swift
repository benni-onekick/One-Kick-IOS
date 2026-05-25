//
//  UserSettings.swift
//  One Kick
//
//  Persistierte Nutzereinstellungen: Lieblingsteams (max 5) & Lieblingsligen.
//  Speicherstrategie: UserDefaults (lokaler Cache, schnell) + Firestore (permanent, geräteübergreifend).
//  Beim Login werden Einstellungen aus Firebase geladen und überschreiben den lokalen Stand.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

struct FavoriteTeam: Codable, Equatable {
    let id: Int
    let name: String
    let logo: String
}

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let db = Firestore.firestore()

    @Published var favoriteTeams: [FavoriteTeam] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(favoriteTeams) {
                UserDefaults.standard.set(data, forKey: "favoriteTeams")
            }
            saveToFirebase()
        }
    }

    @Published var favoriteLeagueIds: [Int] = [] {
        didSet {
            UserDefaults.standard.set(favoriteLeagueIds, forKey: "favoriteLeagueIds")
            saveToFirebase()
        }
    }

    @Published var crossCommunityTipping: Bool = false {
        didSet {
            UserDefaults.standard.set(crossCommunityTipping, forKey: "crossCommunityTipping")
            saveToFirebase()
        }
    }

    @Published var showOdds: Bool = true {
        didSet {
            UserDefaults.standard.set(showOdds, forKey: "showOdds")
            saveToFirebase()
        }
    }

    @Published var photoBase64: String? = nil {
        didSet {
            if let b64 = photoBase64 {
                UserDefaults.standard.set(b64, forKey: "profilePhotoBase64")
            } else {
                UserDefaults.standard.removeObject(forKey: "profilePhotoBase64")
            }
            saveToFirebase()
        }
    }

    var favoriteTeamIds: [Int] { favoriteTeams.map { $0.id } }

    private init() {
        // Lokalen Stand sofort laden → App startet ohne Wartezeit
        if let data = UserDefaults.standard.data(forKey: "favoriteTeams"),
           let teams = try? JSONDecoder().decode([FavoriteTeam].self, from: data) {
            favoriteTeams = teams
        }
        favoriteLeagueIds = UserDefaults.standard.array(forKey: "favoriteLeagueIds") as? [Int] ?? []
        crossCommunityTipping = UserDefaults.standard.bool(forKey: "crossCommunityTipping")
        showOdds = UserDefaults.standard.object(forKey: "showOdds") as? Bool ?? true
        photoBase64 = UserDefaults.standard.string(forKey: "profilePhotoBase64")
    }

    // MARK: - Firebase laden (beim Login aufrufen)

    func loadFromFirebase(uid: String) {
        Task {
            guard let doc = try? await db.collection("users").document(uid).getDocument(),
                  let data = doc.data() else { return }

            await MainActor.run {
                // Teams
                if let raw = data["favoriteTeams"] as? [[String: Any]] {
                    let teams = raw.compactMap { d -> FavoriteTeam? in
                        guard let id   = d["id"]   as? Int,
                              let name = d["name"] as? String,
                              let logo = d["logo"] as? String else { return nil }
                        return FavoriteTeam(id: id, name: name, logo: logo)
                    }
                    // Nur überschreiben wenn Firebase-Daten vorhanden sind
                    if !teams.isEmpty || data["favoriteTeams"] != nil {
                        self.favoriteTeams = teams
                    }
                }

                // Ligen
                if let ids = data["favoriteLeagueIds"] as? [Int] {
                    self.favoriteLeagueIds = ids
                }

                // Cross-Community-Tippen
                if let cct = data["crossCommunityTipping"] as? Bool {
                    self.crossCommunityTipping = cct
                }

                // Wettquoten anzeigen
                if let so = data["showOdds"] as? Bool {
                    self.showOdds = so
                }

                // Profilfoto: immer überschreiben (verhindert Fremdfoto bei Account-Wechsel)
                self.photoBase64 = data["photoBase64"] as? String
            }
        }
    }

    // MARK: - Foto beim Logout löschen
    func clearPhoto() {
        UserDefaults.standard.removeObject(forKey: "profilePhotoBase64")
        photoBase64 = nil
    }

    // MARK: - Firebase schreiben

    private func saveToFirebase() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let teamsData = favoriteTeams.map { ["id": $0.id, "name": $0.name, "logo": $0.logo] }
        var payload: [String: Any] = [
            "favoriteTeams":         teamsData,
            "favoriteLeagueIds":     favoriteLeagueIds,
            "crossCommunityTipping": crossCommunityTipping,
            "showOdds":              showOdds
        ]
        if let b64 = photoBase64 { payload["photoBase64"] = b64 }
        db.collection("users").document(uid).setData(payload, merge: true)
    }
}
