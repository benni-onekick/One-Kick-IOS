//
//  CreateCommunityView.swift
//  One Kick
//

import SwiftUI
import PhotosUI

struct CreateCommunityView: View {
    var onDismiss: () -> Void
    var onCreate: (CommunityModel) -> Void

    @State private var groupName: String = ""
    @State private var groupStake: String = ""
    @State private var selectedLeagues: Set<String> = []

    @State private var showLeagueSelection = false

    @State private var communityLogo: UIImage?
    @State private var showImageSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    // PHPickerViewController state
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.oneKickBlack.ignoresSafeArea()

                CreateCommunityForm(
                    groupName: $groupName,
                    groupStake: $groupStake,
                    selectedLeagues: $selectedLeagues,
                    communityLogo: $communityLogo,
                    onLogoTap: { showImageSourceDialog = true },
                    onLeaguesTap: { showLeagueSelection = true }
                )

                // Fester Button am unteren Rand – bewegt sich NICHT mit der Tastatur
                VStack(spacing: 0) {
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
                    .padding(.bottom, 28)
                    .shadow(color: canCreate ? Color.oneKickNeon.opacity(0.3) : .clear, radius: 20, x: 0, y: 10)
                    .background(Color.oneKickBlack)
                }
            }
            // Tastatur überlagert den Inhalt – Button bleibt unten
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Community erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { onDismiss() }.foregroundColor(.white)
                }
            }
            .confirmationDialog("Logo auswählen", isPresented: $showImageSourceDialog) {
                Button("Foto aufnehmen") { showCamera = true }
                Button("Aus Fotos auswählen") { showPhotoPicker = true }
                Button("Datei verwenden") { showFileImporter = true }
                Button("Abbrechen", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(selectedImage: $communityLogo, sourceType: .camera).ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        communityLogo = image
                    }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $showLeagueSelection) {
                LeagueSelectionSheet(selectedLeagues: $selectedLeagues)
            }
        }
    }

    var canCreate: Bool {
        groupName.trimmingCharacters(in: .whitespaces).count >= 2 && !selectedLeagues.isEmpty
    }

    func createCommunity() {
        HapticManager.instance.notification(type: .success)
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
