//
//  AvatarView.swift
//  One Kick
//

import SwiftUI

struct AvatarView: View {
    let displayName: String
    let photoBase64: String?
    let size: CGFloat

    private var initial: String { String(displayName.prefix(1)).uppercased() }

    var body: some View {
        Group {
            if let b64 = photoBase64,
               let data = Data(base64Encoded: b64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.oneKickDarkGray
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
