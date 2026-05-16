//
//  CreateCommunityView.swift
//  One Kick
//
//  ÄNDERUNG (Milestone A):
//  - `createCommunity()` baut das Model jetzt nur noch mit `name` + `activeLeagues`.
//  - Der CommunityManager setzt `adminId`, `memberIds` und `createdAt` selbst
//    aus dem aktuellen Firebase-User. Wir geben hier nichts mehr hartcodiert mit.
//  - `groupStake` wird aktuell noch nicht persistiert (siehe TODO unten).
//

import SwiftUI
import PhotosUI

struct CreateCommunityView: View {
    // Callback, wenn abgebrochen wird
    var onDismiss: () -> Void
    
    // Callback, wenn erfolgreich erstellt wurde (Gibt das neue Model zurück)
    var onCreate: (CommunityModel) -> Void
    
    // --- EINGABEN ---
    @State private var groupName: String = ""
    @State private var groupStake: String = ""
    @State private var selectedLeagues: Set<String> = []
    
    // --- STEUERUNG ---
    @State private var showLeagueSelection = false
    
    // --- BILD LOGIK ---
    @State private var communityLogo: UIImage?
    @State private var showImageSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showFileImporter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()

                // Formular-UI (Ausgelagert für Übersichtlichkeit)
                CreateCommunityForm(
                    groupName: $groupName,
                    groupStake: $groupStake,
                    selectedLeagues: $selectedLeagues,
                    communityLogo: $communityLogo,
                    onLogoTap: { showImageSourceDialog = true },
                    onLeaguesTap: { showLeagueSelection = true }
                )
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: createCommunity) {
                    Text("Jetzt gründen")
                        .font(.headline).bold()
                        .foregroundColor(canCreate ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreate ? Color.oneKickNeon : Color.oneKickDarkGray)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(canCreate ? 0 : 0.08), lineWidth: 1)
                        )
                }
                .disabled(!canCreate)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .shadow(color: canCreate ? Color.oneKickNeon.opacity(0.3) : .clear, radius: 20, x: 0, y: 10)
                .background(Color.oneKickBlack)
            }
            .navigationTitle("Community erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { onDismiss() }.foregroundColor(.white)
                }
            }
            // --- MODALS & SHEETS ---
            .confirmationDialog("Logo auswählen", isPresented: $showImageSourceDialog) {
                Button("Foto aufnehmen") { showCamera = true }
                Button("Foto verwenden") { showPhotoLibrary = true }
                Button("Datei verwenden") { showFileImporter = true }
                Button("Abbrechen", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(selectedImage: $communityLogo, sourceType: .camera).ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(selectedImage: $communityLogo, sourceType: .photoLibrary).ignoresSafeArea()
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $showLeagueSelection) {
                LeagueSelectionSheet(selectedLeagues: $selectedLeagues)
            }
        }
    }
    
    // Validierung: Name muss mind. 2 Zeichen haben & Ligen gewählt
    var canCreate: Bool {
        return groupName.trimmingCharacters(in: .whitespaces).count >= 2 && !selectedLeagues.isEmpty
    }
    
    func createCommunity() {
        HapticManager.instance.notification(type: .success)
        
        // Wir bauen nur das Skelett. adminId, memberIds und createdAt setzt
        // der CommunityManager mit den richtigen Firebase-Werten.
        // TODO: groupStake & communityLogo werden noch nicht persistiert —
        //       wird in einem späteren Milestone nachgereicht.
        let newCommunity = CommunityModel(
            name: groupName,
            activeLeagues: selectedLeagues
        )
        
        onCreate(newCommunity)
    }
    
    func handleFileImport(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                communityLogo = image
            }
        }
    }
}
