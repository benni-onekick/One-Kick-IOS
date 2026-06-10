//
//  AdminBonusResultsView.swift
//  One Kick
//
//  Admin trägt hier die korrekten Saison-Endantworten ein.
//  Gespeichert in: communities/{cid}/bonusCorrectAnswers/{leagueName}
//  Mit diesen Antworten berechnet CommunityPunkteViewModel die Bonus-Punkte.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminBonusResultsView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss

    @State private var answers: [String: [String: String]] = [:]   // leagueName → {cat → answer}
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveSuccess = false

    private let db = Firestore.firestore()

    private var activeLeagues: [String] { community.activeLeagues.sorted() }
    private func activeCategorySet(for leagueName: String) -> Set<String> {
        community.activeBonusCats(for: leagueName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            infoBox

                            ForEach(activeLeagues, id: \.self) { league in
                                leagueSection(league)
                            }

                            saveButton
                                .padding(.horizontal, 20).padding(.vertical, 24)
                        }
                    }
                }
            }
            .navigationTitle("Bonus-Ergebnisse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .task { await loadResults() }
    }

    // MARK: - Sub-Views

    private var infoBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(.oneKickNeon)
            Text("Trage hier die echten Saisondergebnisse ein. Die Bonus-Punkte aller Spieler werden automatisch berechnet.")
                .font(.caption).foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(12)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func leagueSection(_ leagueName: String) -> some View {
        let activeCats = bonusCategoriesForLeague(leagueName, activeCategorySet: activeCategorySet(for: leagueName))
        guard !activeCats.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text(leagueName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.oneKickNeon)
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)

                VStack(spacing: 1) {
                    ForEach(activeCats, id: \.self) { cat in
                        categoryRow(leagueName: leagueName, category: cat)
                    }
                }
            }
        )
    }

    private func categoryRow(leagueName: String, category: String) -> some View {
        let binding = Binding<String>(
            get: { answers[leagueName]?[category] ?? "" },
            set: { answers[leagueName, default: [:]][category] = $0 }
        )
        return HStack(spacing: 12) {
            Text(category)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Antwort…", text: binding)
                .font(.system(size: 13))
                .foregroundColor(.oneKickNeon)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
        .background(Color.oneKickDarkGray)
    }

    private var saveButton: some View {
        Button(action: { Task { await saveResults() } }) {
            HStack {
                if isSaving {
                    ProgressView().tint(.black).scaleEffect(0.8)
                } else if saveSuccess {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                }
                Text(saveSuccess ? "Gespeichert" : "Ergebnisse speichern")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(saveSuccess ? Color.green : Color.oneKickNeon)
            .cornerRadius(12)
        }
        .disabled(isSaving)
    }

    // MARK: - Data

    private func loadResults() async {
        guard let cid = community.id else { isLoading = false; return }
        if let snap = try? await db.collection("communities").document(cid)
            .collection("bonusCorrectAnswers").getDocuments() {
            var loaded: [String: [String: String]] = [:]
            for doc in snap.documents {
                guard let a = doc.data()["answers"] as? [String: String] else { continue }
                loaded[doc.documentID] = a
            }
            answers = loaded
        }
        isLoading = false
    }

    private func saveResults() async {
        guard let cid = community.id, let adminId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (leagueName, cats) in answers {
                    let data: [String: Any] = [
                        "answers":   cats,
                        "updatedAt": Timestamp(),
                        "updatedBy": adminId
                    ]
                    group.addTask {
                        try await self.db.collection("communities").document(cid)
                            .collection("bonusCorrectAnswers").document(leagueName)
                            .setData(data, merge: true)
                    }
                }
                try await group.waitForAll()
            }
            saveSuccess = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            saveSuccess = false
        } catch {
            // Fehler ignorieren – UI zeigt kein Feedback (keep simple)
        }
        isSaving = false
    }
}
