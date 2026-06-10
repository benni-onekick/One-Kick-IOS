//
//  CommunitySettingsView.swift
//  One Kick
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

struct CommunitySettingsView: View {
    let community: CommunityModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var communityManager: CommunityManager

    @State private var groupName: String
    @State private var inviteCode: String
    @State private var selectedLeagues: Set<String>
    @State private var selectedBonusCategories: Set<String>  // globaler Fallback (veraltet)
    @State private var bonusCatsPerLeague: [String: Set<String>] = [:]  // neu: pro Liga
    @State private var showLeagueSelection = false
    @State private var showBonusFill = false
    @State private var showBonusResults = false
    @State private var codeCopied = false
    @State private var showLeaveConfirm = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isSavingPhoto = false
    @State private var communityPhotoBase64: String?
    @State private var showTransferAdmin = false
    @State private var transferMembers: [(userId: String, displayName: String)] = []
    @State private var isLoadingTransfer = false
    @State private var pendingNewAdmin: (userId: String, displayName: String)?
    @State private var showTransferConfirm = false
    @State private var lockedLeagues: Set<String> = []  // pro-Liga-Lock
    @State private var showAddAdmin = false
    @State private var coAdminNames: [String: String] = [:]   // uid → Anzeigename
    @State private var showBonusManage = false
    @State private var cropItem: CropItem? = nil
    @State private var showDeleteConfirm = false

    // Liest immer die aktuelle Community aus dem Manager – reagiert auf Firestore-Updates
    // (community ist eine statische let-Kopie; liveCommunity spiegelt den Live-Stand wider)
    private var liveCommunity: CommunityModel {
        communityManager.communities.first(where: { $0.id == community.id }) ?? community
    }

    init(community: CommunityModel) {
        self.community = community
        _groupName = State(initialValue: community.name)
        _inviteCode = State(initialValue: community.inviteCode ?? "—")
        _selectedLeagues = State(initialValue: community.activeLeagues)
        _communityPhotoBase64 = State(initialValue: community.photoBase64)
        // Globaler Fallback (für Speichern als Basis)
        _selectedBonusCategories = State(
            initialValue: community.activeBonusCategories.map { Set($0) }
                ?? Set(allBonusCategories)
        )
        // Pro-Liga: aus activeBonusCategoriesPerLeague oder globalem Fallback
        var perLeague: [String: Set<String>] = [:]
        for leagueName in community.activeLeagues {
            if let existing = community.activeBonusCategoriesPerLeague?[leagueName], !existing.isEmpty {
                perLeague[leagueName] = Set(existing)
            } else {
                perLeague[leagueName] = community.activeBonusCategories.map { Set($0) } ?? Set(allBonusCategories)
            }
        }
        _bonusCatsPerLeague = State(initialValue: perLeague)
    }

    var shareMessage: String {
        "Komm in meine One Kick Tipprunde! ⚽\n\nCommunity beitreten:\nhttps://benni-onekick.github.io/join?code=\(inviteCode)\n\nOneKick herunterladen:\nhttps://apps.apple.com/de/app/one-kick/id6773107845"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                List {
                    // --- FOTO (nur Admin) ---
                    if liveCommunity.isAdmin {
                        Section(header: sectionHeader("Community-Foto")) {
                            HStack {
                                Spacer()
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Group {
                                            if let b64 = communityPhotoBase64,
                                               let data = Data(base64Encoded: b64),
                                               let img = UIImage(data: data) {
                                                Image(uiImage: img)
                                                    .resizable().scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            } else {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.oneKickDarkGray)
                                                        .frame(width: 80, height: 80)
                                                    Image(systemName: "person.3.fill")
                                                        .font(.title2).foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        if isSavingPhoto {
                                            ProgressView()
                                                .tint(.oneKickNeon)
                                                .offset(x: 4, y: 4)
                                        } else {
                                            Image(systemName: "camera.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.oneKickNeon)
                                                .offset(x: 4, y: 4)
                                        }
                                    }
                                }
                                .onChange(of: selectedPhoto) { _, item in
                                    Task {
                                        guard let item,
                                              let data = try? await item.loadTransferable(type: Data.self),
                                              let uiImage = UIImage(data: data) else { return }
                                        await MainActor.run { cropItem = CropItem(image: uiImage) }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- NAME ---
                    Section(header: sectionHeader("Allgemein")) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Name der Runde").font(.caption2).foregroundColor(.gray)
                            if liveCommunity.isAdmin {
                                TextField("Name", text: $groupName)
                                    .font(.headline).foregroundColor(.white)
                            } else {
                                Text(community.name).font(.headline).foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 5)
                        .listRowBackground(Color.oneKickDarkGray)
                    }

                    // --- ADMIN-VERWALTUNG (nur Owner/Ersteller) ---
                    if liveCommunity.isOwner {
                        Section(header: sectionHeader("Admin")) {
                            // Admin hinzufügen (Co-Admin)
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showAddAdmin = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Admin hinzufügen")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Mitglied zusätzlich zum Admin machen")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.oneKickNeon)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)

                            // Liste aktueller Co-Admins mit Entfernen
                            ForEach(liveCommunity.coAdminIds ?? [], id: \.self) { coAdminId in
                                HStack {
                                    Image(systemName: "person.fill.checkmark")
                                        .foregroundColor(.oneKickNeon)
                                    Text(coAdminNames[coAdminId] ?? String(coAdminId.prefix(8)))
                                        .font(.subheadline).foregroundColor(.white)
                                    Spacer()
                                    Button(action: {
                                        HapticManager.instance.impact(style: .light)
                                        Task {
                                            try? await communityManager.removeCoAdmin(
                                                community: community, removeId: coAdminId)
                                        }
                                    }) {
                                        Text("Entfernen")
                                            .font(.caption.bold()).foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 5)
                                .listRowBackground(Color.oneKickDarkGray)
                            }

                            // Admin weitergeben (Owner-Übergabe)
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showTransferAdmin = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Admin weitergeben")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Ersteller-Rolle an ein Mitglied übergeben")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.key.fill")
                                        .foregroundColor(.oneKickNeon)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- WETTBEWERBE (nur Admin) ---
                    if liveCommunity.isAdmin {
                        Section(header: sectionHeader("Wettbewerbe")) {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showLeagueSelection = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Ligen verwalten")
                                            .font(.headline).foregroundColor(.white)
                                        Text("\(selectedLeagues.count) Ligen aktiv")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- BONUSTIPPS VERWALTEN (nur Admin) ---
                    if liveCommunity.isAdmin {
                        Section(header: sectionHeader("Bonustipps")) {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showBonusManage = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bonustipps verwalten")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Pro Liga & Pokal festlegen")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- BONUS NACHTRAGEN + ERGEBNISSE (nur Admin) ---
                    if liveCommunity.isAdmin {
                        Section(header: sectionHeader("Mitglieder")) {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showBonusFill = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bonus-Tipps nachtragen")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Für spät beigetretene Mitglieder ausfüllen")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.oneKickNeon)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)

                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showBonusResults = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bonus-Ergebnisse eintragen")
                                            .font(.headline).foregroundColor(.white)
                                        Text("Korrekte Saison-Endantworten für Punkteberechnung")
                                            .font(.caption).foregroundColor(.oneKickNeon)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.oneKickNeon)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.oneKickDarkGray)
                        }
                    }

                    // --- EINLADEN ---
                    Section(header: sectionHeader("Freunde einladen")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dein Einladungscode").font(.caption2).foregroundColor(.gray)
                                Text(inviteCode)
                                    .font(.title3).fontDesign(.monospaced).fontWeight(.bold)
                                    .foregroundColor(.oneKickNeon)
                            }
                            Spacer()
                            HStack(spacing: 15) {
                                Button(action: {
                                    UIPasteboard.general.string = inviteCode
                                    HapticManager.instance.notification(type: .success)
                                    withAnimation { codeCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { codeCopied = false }
                                    }
                                }) {
                                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.title2)
                                        .foregroundColor(codeCopied ? .green : .white)
                                        .frame(width: 44, height: 44)
                                }.buttonStyle(PlainButtonStyle())
                                ShareLink(item: shareMessage) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.title2).foregroundColor(.oneKickNeon)
                                        .frame(width: 44, height: 44)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.oneKickDarkGray)
                    }

                    // --- GEFAHRENZONE ---
                    Section(header: sectionHeader("Gefahrenzone", color: .red)) {
                        if liveCommunity.isOwner {
                            Button(action: {
                                HapticManager.instance.impact(style: .medium)
                                showDeleteConfirm = true
                            }) {
                                HStack { Image(systemName: "trash.fill"); Text("Community löschen"); Spacer() }
                                    .foregroundColor(.red).bold()
                                    .contentShape(Rectangle())
                            }
                            .listRowBackground(Color.oneKickDarkGray)
                            .confirmationDialog(
                                "Community löschen?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Löschen", role: .destructive) {
                                    HapticManager.instance.notification(type: .warning)
                                    communityManager.deleteCommunity(community)
                                    dismiss()
                                }
                                Button("Abbrechen", role: .cancel) {}
                            } message: {
                                Text("\"\(community.name)\" wird endgültig gelöscht. Das kann nicht rückgängig gemacht werden.")
                            }
                        } else {
                            Button(action: { showLeaveConfirm = true }) {
                                HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Community verlassen"); Spacer() }
                                    .foregroundColor(.red).bold()
                                    .contentShape(Rectangle())
                            }
                            .listRowBackground(Color.oneKickDarkGray)
                            .confirmationDialog(
                                "Community verlassen?",
                                isPresented: $showLeaveConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Verlassen", role: .destructive) {
                                    HapticManager.instance.notification(type: .warning)
                                    Task {
                                        await communityManager.leaveCommunity(community)
                                        dismiss()
                                    }
                                }
                                Button("Abbrechen", role: .cancel) {}
                            } message: {
                                Text("Du wirst aus \"\(community.name)\" entfernt und siehst die Gruppe nicht mehr.")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 10)
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        HapticManager.instance.impact(style: .light)
                        if liveCommunity.isAdmin {
                            communityManager.updateActiveLeagues(for: liveCommunity, newLeagues: selectedLeagues)
                            // Pro-Liga-Kategorien speichern
                            var categoriesPerLeague: [String: [String]] = [:]
                            for (league, cats) in bonusCatsPerLeague {
                                let isAllActive = cats == Set(allBonusCategories)
                                categoriesPerLeague[league] = isAllActive ? [] : Array(cats)
                            }
                            communityManager.updateBonusCategoriesPerLeague(
                                for: liveCommunity,
                                categoriesPerLeague: categoriesPerLeague
                            )
                        }
                        dismiss()
                    }
                    .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
            .fullScreenCover(isPresented: $showLeagueSelection) {
                ManageLeaguesView(selectedLeagues: $selectedLeagues)
            }
            .fullScreenCover(isPresented: $showBonusManage) {
                ManageBonusView(
                    community: liveCommunity,
                    bonusCatsPerLeague: $bonusCatsPerLeague,
                    lockedLeagues: lockedLeagues
                )
            }
            .fullScreenCover(item: $cropItem) { item in
                ImageCropView(
                    image: item.image,
                    onCancel: { cropItem = nil },
                    onCrop: { cropped in
                        cropItem = nil
                        Task { await saveCommunityPhoto(cropped) }
                    }
                )
            }
            .sheet(isPresented: $showBonusFill) {
                AdminBonusFillView(community: community)
            }
            .sheet(isPresented: $showBonusResults) {
                AdminBonusResultsView(community: community)
            }
            .onChange(of: showTransferAdmin) { _, isShowing in
                if isShowing { Task { await loadTransferMembers() } }
            }
            .onChange(of: showAddAdmin) { _, isShowing in
                if isShowing { Task { await loadTransferMembers() } }
            }
            .sheet(isPresented: $showTransferAdmin) {
                TransferAdminSheet(
                    members: transferMembers,
                    isLoading: isLoadingTransfer,
                    onSelect: { member in
                        pendingNewAdmin = member
                        showTransferConfirm = true
                    }
                )
            }
            .sheet(isPresented: $showAddAdmin) {
                AddAdminSheet(
                    members: transferMembers.filter { !liveCommunity.allAdminIds.contains($0.userId) },
                    isLoading: isLoadingTransfer,
                    onSelect: { member in
                        Task {
                            try? await communityManager.addCoAdmin(
                                community: community, newAdminId: member.userId)
                            coAdminNames[member.userId] = member.displayName
                            showAddAdmin = false
                        }
                    }
                )
            }
            .confirmationDialog(
                "Admin weitergeben?",
                isPresented: $showTransferConfirm,
                titleVisibility: .visible
            ) {
                if let member = pendingNewAdmin {
                    Button("\(member.displayName) zum Admin machen", role: .destructive) {
                        Task {
                            try? await communityManager.transferAdmin(community: community, to: member.userId)
                            showTransferAdmin = false
                            dismiss()
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                if let member = pendingNewAdmin {
                    Text("\(member.displayName) wird neuer Admin. Du verlierst deine Admin-Rechte.")
                }
            }
            .task {
                guard community.inviteCode == nil, liveCommunity.isAdmin else { return }
                if let code = try? await communityManager.generateAndSaveInviteCode(for: community) {
                    inviteCode = code
                }
            }
            .task(id: liveCommunity.coAdminIds) {
                // Anzeigenamen der Co-Admins laden (für die Liste)
                for uid in liveCommunity.coAdminIds ?? [] where coAdminNames[uid] == nil {
                    let doc = try? await Firestore.firestore().collection("users").document(uid).getDocument()
                    coAdminNames[uid] = doc?.data()?["displayName"] as? String
                        ?? doc?.data()?["email"] as? String
                        ?? String(uid.prefix(8))
                }
            }
            .task(id: community.id) {
                // Pro-Liga-Lock: jede Liga prüft eigenständig ob md > 1
                var locked = Set<String>()
                for leagueName in community.activeLeagues {
                    let lid = LeagueMapper.getID(for: leagueName)
                    if let d = UserDefaults.standard.dictionary(forKey: "lmd_\(lid)"),
                       let md = d["md"] as? Int, md > 1 {
                        locked.insert(leagueName)
                    }
                }
                lockedLeagues = locked
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color = .gray) -> some View {
        Text(title).foregroundColor(color).font(.caption).bold()
    }

    private func loadTransferMembers() async {
        guard let myId = Auth.auth().currentUser?.uid else { return }
        isLoadingTransfer = true
        var result: [(userId: String, displayName: String)] = []
        for uid in community.memberIds where uid != myId {
            let doc = try? await Firestore.firestore().collection("users").document(uid).getDocument()
            let name = doc?.data()?["displayName"] as? String
                    ?? doc?.data()?["email"] as? String
                    ?? uid
            result.append((userId: uid, displayName: name))
        }
        transferMembers = result.sorted {
            $0.displayName.localizedCompare($1.displayName) == .orderedAscending
        }
        isLoadingTransfer = false
    }

    // Bereits quadratisch zugeschnittenes Bild auf 120×120px verkleinern + speichern.
    private func saveCommunityPhoto(_ croppedImage: UIImage) async {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        let squared = renderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = squared.jpegData(compressionQuality: 0.6) else { return }
        let b64 = jpeg.base64EncodedString()

        isSavingPhoto = true
        try? await communityManager.updateCommunityPhoto(b64, for: liveCommunity)
        communityPhotoBase64 = b64
        isSavingPhoto = false
    }
}

// MARK: - Admin weitergeben Sheet

struct TransferAdminSheet: View {
    let members: [(userId: String, displayName: String)]
    let isLoading: Bool
    let onSelect: (( userId: String, displayName: String)) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Keine weiteren Mitglieder")
                            .foregroundColor(.gray)
                    }
                } else {
                    List(members, id: \.userId) { member in
                        Button(action: {
                            HapticManager.instance.impact(style: .medium)
                            onSelect(member)
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.oneKickNeon)
                                Text(member.displayName)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Neuen Admin wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Admin hinzufügen Sheet (Co-Admin)

struct AddAdminSheet: View {
    let members: [(userId: String, displayName: String)]
    let isLoading: Bool
    let onSelect: (( userId: String, displayName: String)) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.oneKickNeon)
                } else if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Keine weiteren Mitglieder")
                            .foregroundColor(.gray)
                    }
                } else {
                    List(members, id: \.userId) { member in
                        Button(action: {
                            HapticManager.instance.impact(style: .medium)
                            onSelect(member)
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.oneKickNeon)
                                Text(member.displayName)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(Color.oneKickDarkGray)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Admin hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Bonustipps verwalten (Liga-Liste)

struct ManageBonusView: View {
    let community: CommunityModel
    @Binding var bonusCatsPerLeague: [String: Set<String>]
    let lockedLeagues: Set<String>
    @Environment(\.dismiss) var dismiss

    private var sortedLeagues: [String] {
        community.activeLeagues.sorted {
            LeagueMapper.sortOrder(for: $0) < LeagueMapper.sortOrder(for: $1)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Text("Wähle pro Liga & Pokal, welche Bonustipps verfügbar sind. Gestartete Wettbewerbe sind gesperrt.")
                            .font(.caption).foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4).padding(.bottom, 4)

                        ForEach(sortedLeagues, id: \.self) { leagueName in
                            let isLocked = lockedLeagues.contains(leagueName)
                            NavigationLink(destination: LeagueBonusEditView(
                                leagueName: leagueName,
                                isLocked: isLocked,
                                bonusCatsPerLeague: $bonusCatsPerLeague
                            )) {
                                HStack(spacing: 12) {
                                    Image(systemName: koLeagueNames.contains(leagueName) ? "trophy.fill" : "soccerball")
                                        .font(.system(size: 16))
                                        .foregroundColor(koLeagueNames.contains(leagueName) ? .yellow : .oneKickNeon)
                                        .frame(width: 30)
                                    Text(leagueName)
                                        .font(.headline).foregroundColor(.white).lineLimit(1)
                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption).foregroundColor(.orange)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                                }
                                .padding(16)
                                .background(Color.oneKickDarkGray)
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Bonustipps verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
        }
    }
}

// MARK: - Bonus-Kategorien einer Liga editieren

struct LeagueBonusEditView: View {
    let leagueName: String
    let isLocked: Bool
    @Binding var bonusCatsPerLeague: [String: Set<String>]
    @Environment(\.dismiss) var dismiss

    private var currentSet: Set<String> {
        bonusCatsPerLeague[leagueName] ?? Set(allBonusCategories)
    }

    private func isOn(_ category: String) -> Bool {
        if category == groupStageCategory {
            return wmGroupCategories.allSatisfy { currentSet.contains($0) }
        }
        return currentSet.contains(category)
    }

    private func toggle(_ category: String) {
        guard !isLocked else { return }
        HapticManager.instance.impact(style: .light)
        var updated = bonusCatsPerLeague[leagueName] ?? Set(allBonusCategories)
        if category == groupStageCategory {
            if wmGroupCategories.allSatisfy({ updated.contains($0) }) {
                wmGroupCategories.forEach { updated.remove($0) }
            } else {
                wmGroupCategories.forEach { updated.insert($0) }
            }
        } else if updated.contains(category) {
            updated.remove(category)
        } else {
            updated.insert(category)
        }
        bonusCatsPerLeague[leagueName] = updated
    }

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(leagueName)
                            .font(.title3).bold().foregroundColor(.white)
                        if isLocked {
                            Image(systemName: "lock.fill").foregroundColor(.orange).font(.caption)
                            Text("Läuft bereits").font(.caption).foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)

                    ForEach(allBonusCategoriesForLeague(leagueName), id: \.self) { category in
                        let on = isOn(category)
                        HStack {
                            Text(category)
                                .font(.subheadline)
                                .foregroundColor(on ? .white : .gray)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(on ? .oneKickNeon : .gray.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .onTapGesture { toggle(category) }
                        .opacity(isLocked ? 0.6 : 1.0)

                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Bonustipps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Ligen verwalten

struct ManageLeaguesView: View {
    @Binding var selectedLeagues: Set<String>
    @Environment(\.dismiss) var dismiss
    @State private var showConfirmPopup = false
    @State private var showLeaveConfirm = false

    let categories: [LeagueCategory] = [
        LeagueCategory(name: "Deutscher Fußball",       leagues: ["1. Bundesliga", "2. Bundesliga", "3. Liga", "DFB-Pokal"]),
        LeagueCategory(name: "International (Club)",     leagues: ["Champions League", "Europa League", "Conference League"]),
        LeagueCategory(name: "Nationalmannschaften",    leagues: ["Weltmeisterschaft", "Europameisterschaft", "Nations League", "WM Qualifikation", "EM Qualifikation"]),
        LeagueCategory(name: "Frauenfußball",            leagues: ["1. Frauen-Bundesliga", "Frauen Champions League", "Frauen WM", "Frauen EM"]),
        LeagueCategory(name: "Europäische Top-Ligen",   leagues: ["Premier League", "La Liga", "Serie A", "Ligue 1", "Eredivisie", "Liga Portugal", "Super League", "Süper Lig", "Österreich Liga"]),
        LeagueCategory(name: "Internationale Ligen",     leagues: ["MLS", "Saudi Pro League"]),
        LeagueCategory(name: "Europäische Pokale",       leagues: ["FA Cup", "Copa del Rey", "Coppa Italia", "Coupe de France"]),
        LeagueCategory(name: "Sonstiges",                leagues: ["Relegation"])
    ]

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Text("Ligen verwalten").font(.headline).bold().foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .overlay(
                    HStack {
                        Button("Abbrechen") { dismiss() }.font(.subheadline).foregroundColor(.white)
                        Spacer()
                    }.padding(.horizontal)
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Wähle die Wettbewerbe für deine Tipprunde.")
                            .font(.caption).foregroundColor(.gray).padding(.horizontal)

                        ForEach(categories, id: \.name) { category in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.name.uppercased())
                                    .font(.caption).bold()
                                    .foregroundColor(.oneKickNeon)
                                    .padding(.horizontal)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)], spacing: 15) {
                                    ForEach(category.leagues, id: \.self) { league in
                                        LeagueSelectionChip(
                                            title: league,
                                            isSelected: selectedLeagues.contains(league),
                                            onTap: {
                                                HapticManager.instance.impact(style: .light)
                                                if selectedLeagues.contains(league) {
                                                    selectedLeagues.remove(league)
                                                } else {
                                                    selectedLeagues.insert(league)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)

                                Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 10)
                }

                Spacer()

                Button(action: {
                    HapticManager.instance.impact(style: .medium)
                    withAnimation(.spring()) { showConfirmPopup = true }
                }) {
                    Text("Bestätigen").font(.headline).bold().foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.oneKickNeon).cornerRadius(15)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .blur(radius: showConfirmPopup ? 5 : 0)
            .disabled(showConfirmPopup)

            if showConfirmPopup {
                Color.black.opacity(0.6).ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Willst du mit diesen Ligen fortfahren?")
                        .font(.headline).multilineTextAlignment(.center).foregroundColor(.white).padding(.top, 10)

                    HStack(spacing: 15) {
                        Button(action: {
                            HapticManager.instance.impact(style: .light)
                            withAnimation { showConfirmPopup = false }
                        }) {
                            Text("Nein").font(.headline).bold().foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red).cornerRadius(12)
                        }
                        Button(action: {
                            HapticManager.instance.notification(type: .success)
                            withAnimation { showConfirmPopup = false }
                            dismiss()
                        }) {
                            Text("Ja").font(.headline).bold().foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.oneKickNeon).cornerRadius(12)
                        }
                    }
                }
                .padding(25)
                .background(Color.oneKickDarkGray).cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
