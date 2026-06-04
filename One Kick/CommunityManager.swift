//
//  CommunityManager.swift
//  One Kick
//
//  REFACTOR (Milestone A):
//  - CommunityModel ist jetzt vollständig Firestore-kompatibel (@DocumentID, Codable).
//  - 'members: Int' und 'isCreatedByUser: Bool' sind keine Storage-Felder mehr,
//    sondern werden aus 'memberIds' bzw. 'adminId' abgeleitet.
//  - Echter Snapshot-Listener: Communities kommen LIVE aus Firestore.
//  - CRUD-Methoden mit Admin-Checks und Error-Handling.
//  - Reagiert auf Login/Logout und räumt den Zustand sauber auf.
//
//  HOTFIX: 'deinit' entfernt, weil der Manager als @StateObject in One_KickApp
//          die App-Lebenszeit lebt — Cleanup-Code im deinit würde nie laufen.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// ============================================================
// MARK: - Model
// ============================================================

struct CommunityModel: Identifiable, Codable, Equatable, Hashable {

    /// Firestore Document ID. Wird automatisch beim Decoden befüllt.
    @DocumentID var id: String?

    /// User-ID des Erstellers/Admins.
    var adminId: String?

    /// Anzeigename der Liga.
    var name: String

    /// Alle Mitglieder dieser Liga (User-IDs).
    var memberIds: [String]

    /// Welche Wettbewerbe sind in dieser Liga aktiv?
    var activeLeagues: Set<String>

    /// Welche Bonus-Kategorien sind aktiv? nil = alle aktiv.
    var activeBonusCategories: [String]?

    /// Einladungscode zum Beitreten.
    var inviteCode: String?

    /// Erstellzeitpunkt (für Sortierung).
    var createdAt: Date

    /// Ausgewählte Spiele pro Liga (leagueName → [fixtureIds]). nil/leer = alle Spiele tippbar.
    var selectedMatchIds: [String: [Int]]?

    /// Community-Profilbild als base64-kodiertes JPEG. nil = kein Bild gesetzt.
    var photoBase64: String?

    init(
        id: String? = nil,
        adminId: String? = nil,
        name: String,
        memberIds: [String] = [],
        activeLeagues: Set<String> = [],
        inviteCode: String? = nil,
        createdAt: Date = Date(),
        selectedMatchIds: [String: [Int]]? = nil,
        photoBase64: String? = nil
    ) {
        self.id = id
        self.adminId = adminId
        self.name = name
        self.memberIds = memberIds
        self.activeLeagues = activeLeagues
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.selectedMatchIds = selectedMatchIds
        self.photoBase64 = photoBase64
    }

    // MARK: Computed Properties (Drop-in-Ersatz für die alten Felder)

    /// Anzahl Mitglieder – ersetzt das alte hartcodierte `members: Int`.
    var members: Int { memberIds.count }

    /// Darf der aktuelle User Admin-Aktionen ausführen?
    /// Ersetzt das alte hartcodierte `isCreatedByUser`.
    var isCreatedByUser: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let adminId = adminId else { return false }
        return adminId == currentUserId
    }
}

// ============================================================
// MARK: - Errors
// ============================================================

enum CommunityError: LocalizedError {
    case notAuthenticated
    case notAdmin
    case missingId
    case emptyName
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Du musst eingeloggt sein, um diese Aktion auszuführen."
        case .notAdmin:
            return "Nur der Admin dieser Liga darf das ändern."
        case .missingId:
            return "Diese Liga hat keine gültige Firestore-ID."
        case .emptyName:
            return "Der Name der Liga darf nicht leer sein."
        case .unknown:
            return "Es ist ein unbekannter Fehler aufgetreten."
        }
    }
}

// ============================================================
// MARK: - Manager
// ============================================================

class CommunityManager: ObservableObject {

    // MARK: Published State

    @Published var communities: [CommunityModel] = []
    @Published var selectedCommunity: CommunityModel? = nil
    @Published var selectedTab: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    /// Wird aktualisiert sobald die App in den Vordergrund kommt → Views reagieren mit Refresh
    @Published var appBecameActive: Date = .now
    /// Deep-Link-Code der über onekick://join?code=... empfangen wurde
    @Published var pendingJoinCode: String? = nil

    // MARK: Private

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: Init

    init() {
        NotificationCenter.default.addObserver(
            forName: .openTippenTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.selectedTab = 1
        }

        // Reagiere auf Login/Logout.
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.startListening(for: user.uid)
            } else {
                self.stopListening()
                DispatchQueue.main.async {
                    self.communities = []
                    self.selectedCommunity = nil
                }
            }
        }
    }

    // MARK: - Firestore Listener

    private func startListening(for userId: String) {
        listener?.remove()

        DispatchQueue.main.async { self.isLoading = true }

        listener = db.collection("communities")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async { self.isLoading = false }

                if let error = error {
                    print("🚨 Firestore Listener Fehler: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Konnte Ligen nicht laden: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async { self.communities = [] }
                    return
                }

                let parsed: [CommunityModel] = documents.compactMap { doc in
                    do {
                        return try doc.data(as: CommunityModel.self)
                    } catch {
                        print("⚠️ Konnte Community \(doc.documentID) nicht decoden: \(error)")
                        return nil
                    }
                }

                let sorted = parsed.sorted { $0.createdAt > $1.createdAt }

                self.migrateLeagueNamesIfNeeded(communities: sorted)

                DispatchQueue.main.async {
                    self.communities = sorted
                    self.syncSelectedCommunity()
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Hält selectedCommunity mit den Live-Daten aus communities synchron.
    private func syncSelectedCommunity() {
        guard let id = selectedCommunity?.id,
              let live = communities.first(where: { $0.id == id }) else { return }
        selectedCommunity = live
    }

    // MARK: - CRUD

    /// Erstellt eine neue Liga in Firestore.
    /// Der aktuelle User wird automatisch Admin und erstes Mitglied.
    func createCommunity(
        name: String,
        activeLeagues: Set<String>,
        completion: ((Result<CommunityModel, Error>) -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(.failure(CommunityError.notAuthenticated))
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            completion?(.failure(CommunityError.emptyName))
            return
        }

        let newCommunity = CommunityModel(
            adminId: userId,
            name: trimmedName,
            memberIds: [userId],
            activeLeagues: activeLeagues,
            inviteCode: Self.generateInviteCode(),
            createdAt: Date()
        )

        do {
            let ref = try db.collection("communities").addDocument(from: newCommunity)

            ref.getDocument { snapshot, error in
                if let error = error {
                    completion?(.failure(error))
                    return
                }
                if let snapshot = snapshot,
                   let created = try? snapshot.data(as: CommunityModel.self) {
                    print("✅ Liga \"\(created.name)\" in Firestore angelegt (ID: \(created.id ?? "?")).")
                    completion?(.success(created))
                } else {
                    completion?(.failure(CommunityError.unknown))
                }
            }
        } catch {
            print("🚨 Encoding-Fehler beim Anlegen: \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }

    /// Legacy-API für bestehende Views (z.B. CreateCommunityView, AddCommunitySheet).
    func addCommunity(_ community: CommunityModel) {
        createCommunity(name: community.name, activeLeagues: community.activeLeagues) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Aktive Wettbewerbe einer Liga ändern. Nur Admins dürfen das.
    func updateActiveLeagues(
        for community: CommunityModel,
        newLeagues: Set<String>,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(CommunityError.notAuthenticated); return
        }
        guard community.adminId == userId else {
            completion?(CommunityError.notAdmin); return
        }
        guard let id = community.id else {
            completion?(CommunityError.missingId); return
        }

        db.collection("communities").document(id).updateData([
            "activeLeagues": Array(newLeagues)
        ]) { [weak self] error in
            if let error = error {
                print("🚨 Update fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
            }
            completion?(error)
        }
    }

    /// Bonus-Kategorien einer Community setzen. Nur Admins.
    func updateBonusCategories(
        for community: CommunityModel,
        categories: [String],
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(CommunityError.notAuthenticated); return
        }
        guard community.adminId == userId else {
            completion?(CommunityError.notAdmin); return
        }
        guard let id = community.id else {
            completion?(CommunityError.missingId); return
        }
        db.collection("communities").document(id).updateData([
            "activeBonusCategories": categories
        ]) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { self?.errorMessage = error.localizedDescription }
            }
            completion?(error)
        }
    }

    /// Community-Profilbild setzen. Nur Admins.
    func updateCommunityPhoto(_ base64: String, for community: CommunityModel) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw CommunityError.notAuthenticated }
        guard community.adminId == userId else { throw CommunityError.notAdmin }
        guard let id = community.id else { throw CommunityError.missingId }
        try await db.collection("communities").document(id).updateData(["photoBase64": base64])
        if let idx = communities.firstIndex(where: { $0.id == id }) {
            communities[idx].photoBase64 = base64
        }
    }

    /// Admin-Rolle an ein anderes Mitglied übertragen. Nur aktueller Admin.
    func transferAdmin(community: CommunityModel, to newAdminId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw CommunityError.notAuthenticated }
        guard community.adminId == userId else { throw CommunityError.notAdmin }
        guard let id = community.id else { throw CommunityError.missingId }
        try await db.collection("communities").document(id).updateData(["adminId": newAdminId])
        if let idx = communities.firstIndex(where: { $0.id == id }) {
            communities[idx].adminId = newAdminId
        }
    }

    /// Liga komplett löschen. Nur Admins.
    func deleteCommunity(
        _ community: CommunityModel,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(CommunityError.notAuthenticated); return
        }
        guard community.adminId == userId else {
            completion?(CommunityError.notAdmin); return
        }
        guard let id = community.id else {
            completion?(CommunityError.missingId); return
        }

        db.collection("communities").document(id).delete { [weak self] error in
            if let error = error {
                print("🚨 Löschen fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
            } else {
                DispatchQueue.main.async {
                    if self?.selectedCommunity?.id == id {
                        self?.selectedCommunity = nil
                    }
                }
            }
            completion?(error)
        }
    }

    // MARK: - Invite Code

    static func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let part = { String((0..<4).map { _ in chars.randomElement()! }) }
        return "\(part())-\(part())"
    }

    @discardableResult
    func generateAndSaveInviteCode(for community: CommunityModel) async throws -> String {
        guard let id = community.id else { throw CommunityError.missingId }
        let code = Self.generateInviteCode()
        try await db.collection("communities").document(id).updateData(["inviteCode": code])
        return code
    }

    func joinCommunity(code: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { throw CommunityError.notAuthenticated }
        let normalized = code.uppercased().trimmingCharacters(in: .whitespaces)
        let snapshot = try await db.collection("communities")
            .whereField("inviteCode", isEqualTo: normalized).getDocuments()
        guard let doc = snapshot.documents.first else {
            throw NSError(domain: "OneKick", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Code nicht gefunden. Prüfe die Eingabe."])
        }
        let community = try doc.data(as: CommunityModel.self)
        guard !community.memberIds.contains(userId) else {
            throw NSError(domain: "OneKick", code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Du bist bereits Mitglied dieser Tipprunde."])
        }
        try await db.collection("communities").document(doc.documentID).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    func leaveCommunity(_ community: CommunityModel) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let id = community.id else { return }
        do {
            try await db.collection("communities").document(id).updateData([
                "memberIds": FieldValue.arrayRemove([userId])
            ])
            await MainActor.run {
                if selectedCommunity?.id == id { selectedCommunity = nil }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - League Name Migration

    private static let migrationKey = "leagueNamesMigrated_v1"

    private static let leagueNameMap: [String: String] = [
        "Premier League (ENG)":   "Premier League",
        "Primera Division (ESP)": "La Liga",
        "Serie A (IT)":           "Serie A",
        "Ligue 1 (FRA)":          "Ligue 1",
        "Süper Lig (TR)":         "Süper Lig",
        "Bundesliga (AT)":        "Österreich Liga",
        "FA Cup (ENG)":           "FA Cup",
        "Copa Del Rey (ESP)":     "Copa del Rey",
        "Coppa Italia (ITA)":     "Coppa Italia"
    ]

    /// Läuft einmalig beim ersten App-Start nach der Umbenennung.
    /// Aktualisiert activeLeagues aller Communities (auch als Mitglied — jeder darf seinen eigenen Namen-Stand lesen).
    func migrateLeagueNamesIfNeeded(communities: [CommunityModel]) {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else { return }

        let map = Self.leagueNameMap
        var didMigrate = false

        for community in communities {
            guard let id = community.id else { continue }
            let migrated = Set(community.activeLeagues.map { map[$0] ?? $0 })
            guard migrated != community.activeLeagues else { continue }
            didMigrate = true
            db.collection("communities").document(id).updateData([
                "activeLeagues": Array(migrated)
            ]) { error in
                if let error = error {
                    print("🚨 Migration fehlgeschlagen für \(id): \(error.localizedDescription)")
                } else {
                    print("✅ Liga-Namen migriert für Community \(id)")
                }
            }
        }

        if didMigrate || !communities.isEmpty {
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        }
    }

    /// Hilfsmethode: Liga erstellen und direkt auswählen (für Quick-Flow).
    func createAndOpen(name: String, activeLeagues: Set<String> = ["1. Bundesliga"]) {
        createCommunity(name: name, activeLeagues: activeLeagues) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let created):
                    self?.selectedCommunity = created
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
