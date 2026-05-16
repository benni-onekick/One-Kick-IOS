//
//  AdminBonusFillView.swift
//  One Kick
//
//  Admin kann für Mitglieder, die später beigetreten sind, Bonus-Tipps nachtragen.
//  Pfad: communities/{communityId}/bonusBets/{userId}
//  Felder: { userId, answers: {"Liga|Kategorie": "Antwort"}, updatedAt, updatedBy }
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - BonusBetManager

class BonusBetManager {
    private let db = Firestore.firestore()

    func saveBonusAnswers(
        communityId: String,
        targetUserId: String,
        answers: [String: String],
        adminId: String
    ) async throws {
        try await db.collection("communities")
            .document(communityId)
            .collection("bonusBets")
            .document(targetUserId)
            .setData([
                "userId":    targetUserId,
                "answers":   answers,
                "updatedAt": Timestamp(),
                "updatedBy": adminId
            ], merge: true)
    }

    func loadBonusAnswers(communityId: String, userId: String) async -> [String: String] {
        guard let doc = try? await db.collection("communities")
            .document(communityId)
            .collection("bonusBets")
            .document(userId)
            .getDocument()
        else { return [:] }
        return (doc.data()?["answers"] as? [String: String]) ?? [:]
    }

    /// Gibt alle Mitglieder zurück, die mindestens einen Match-Tipp abgegeben haben (email + userId).
    func loadMembersFromBets(communityId: String) async -> [(userId: String, email: String)] {
        guard let snapshot = try? await db.collection("communities")
            .document(communityId)
            .collection("bets")
            .getDocuments()
        else { return [] }

        var seen = Set<String>()
        var members: [(userId: String, email: String)] = []
        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let email  = data["email"]  as? String,
                  seen.insert(userId).inserted
            else { continue }
            members.append((userId: userId, email: email))
        }
        return members.sorted { $0.email < $1.email }
    }
}

// MARK: - AdminBonusFillView

struct AdminBonusFillView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss

    @State private var members: [(userId: String, email: String)] = []
    @State private var isLoading = true

    private let bonusManager = BonusBetManager()

    private var activeLeagues: [String] { community.activeLeagues.sorted() }
    private var activeCategorySet: Set<String> {
        community.activeBonusCategories.map { Set($0) } ?? Set(allBonusCategories)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40)).foregroundColor(.gray)
                        Text("Noch keine Mitglieder mit Match-Tipps gefunden.")
                            .font(.subheadline).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    List {
                        Section(header: Text("Mitglied auswählen")
                            .foregroundColor(.gray).font(.caption).bold()) {
                            ForEach(members, id: \.userId) { member in
                                NavigationLink(destination: MemberBonusEditView(
                                    community:        community,
                                    memberId:         member.userId,
                                    memberEmail:      member.email,
                                    activeLeagues:    activeLeagues,
                                    activeCategorySet: activeCategorySet
                                )) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.email)
                                            .font(.subheadline).foregroundColor(.white)
                                        Text("Bonus-Tipps nachtragen")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.oneKickDarkGray)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Bonus nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .task { await loadMembers() }
    }

    private func loadMembers() async {
        members    = await bonusManager.loadMembersFromBets(communityId: community.id ?? "")
        isLoading  = false
    }
}

// MARK: - MemberBonusEditView

struct MemberBonusEditView: View {
    let community: CommunityModel
    let memberId: String
    let memberEmail: String
    let activeLeagues: [String]
    let activeCategorySet: Set<String>

    @State private var answers:     [String: String] = [:]
    @State private var isLoading    = true
    @State private var isSaving     = false
    @State private var saveSuccess  = false

    private let bonusManager = BonusBetManager()

    private let koLeagues: Set<String> = [
        "Champions League", "Europa League", "Conference League",
        "DFB-Pokal", "FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France",
        "Weltmeisterschaft", "Europameisterschaft", "Nations League",
        "WM Qualifikation", "EM Qualifikation",
        "Frauen Champions League", "Frauen WM", "Frauen EM"
    ]

    private func categories(for league: String) -> [String] {
        let isKO = koLeagues.contains(league)
        var cats: [String] = isKO
            ? ["Finalisten tippen", "Halbfinalisten tippen"]
            : ["Torschützenkönig", "Meiste Tore (Team)", "Meiste Gegentore", "Endtabelle"]
        cats += ["Meiste Aluminium-Treffer", "Meiste Karten", "Meiste Zu-Null-Spiele"]
        return cats.filter { activeCategorySet.contains($0) }
    }

    private var shortName: String {
        memberEmail.components(separatedBy: "@").first ?? memberEmail
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.oneKickNeon)
            } else {
                ScrollView {
                    VStack(spacing: 20) {

                        // Mitglieds-Info-Banner
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 34)).foregroundColor(.oneKickNeon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memberEmail)
                                    .font(.subheadline).bold().foregroundColor(.white).lineLimit(1)
                                Text("Tipps werden stellvertretend eingetragen")
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.oneKickDarkGray)
                        .cornerRadius(14)
                        .padding(.horizontal)

                        // Ligen + Kategorien
                        ForEach(activeLeagues, id: \.self) { league in
                            let cats = categories(for: league)
                            if !cats.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(league)
                                        .font(.headline).bold().foregroundColor(.white)
                                        .padding(.horizontal)

                                    VStack(spacing: 0) {
                                        ForEach(Array(cats.enumerated()), id: \.offset) { idx, category in
                                            let key = "\(league)|\(category)"
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(category)
                                                    .font(.caption).foregroundColor(.gray)
                                                TextField("Antwort eingeben …", text: Binding(
                                                    get: { answers[key] ?? "" },
                                                    set: { answers[key] = $0 }
                                                ))
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.oneKickDarkGray)

                                            if idx < cats.count - 1 {
                                                Divider().background(Color.white.opacity(0.06))
                                                    .padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .cornerRadius(14)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("Bonus für \(shortName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: saveAnswers) {
                    if isSaving {
                        ProgressView().tint(.oneKickNeon).scaleEffect(0.8)
                    } else {
                        Text(saveSuccess ? "✓ Gespeichert" : "Speichern")
                            .font(.headline)
                            .foregroundColor(saveSuccess ? .green : .oneKickNeon)
                    }
                }
                .disabled(isSaving)
            }
        }
        .task { await loadExisting() }
    }

    private func loadExisting() async {
        answers   = await bonusManager.loadBonusAnswers(communityId: community.id ?? "", userId: memberId)
        isLoading = false
    }

    private func saveAnswers() {
        guard let adminId     = Auth.auth().currentUser?.uid,
              let communityId = community.id else { return }
        isSaving = true
        let filtered = answers.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }

        Task {
            do {
                try await bonusManager.saveBonusAnswers(
                    communityId:    communityId,
                    targetUserId:   memberId,
                    answers:        filtered,
                    adminId:        adminId
                )
                isSaving     = false
                saveSuccess  = true
                HapticManager.instance.notification(type: .success)
                try? await Task.sleep(for: .seconds(1.5))
                saveSuccess = false
            } catch {
                isSaving = false
            }
        }
    }
}
