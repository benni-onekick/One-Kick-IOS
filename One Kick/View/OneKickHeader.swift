//
//  OneKickHeader.swift
//  One Kick
//

import SwiftUI

struct OneKickHeader: View {
    var onProfile: (() -> Void)?
    @ObservedObject private var userSettings = UserSettings.shared

    var body: some View {
        HStack {
            Text("ONE KICK")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(.oneKickNeon)
            Spacer()
            if let onProfile {
                Button(action: onProfile) {
                    if let b64 = userSettings.photoBase64,
                       let data = Data(base64Encoded: b64),
                       let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable().scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
