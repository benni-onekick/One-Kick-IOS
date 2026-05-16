//
//  OneKickHeader.swift
//  One Kick
//

import SwiftUI

struct OneKickHeader: View {
    var onProfile: (() -> Void)?

    var body: some View {
        HStack {
            Text("ONE KICK")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(.oneKickNeon)
            Spacer()
            if let onProfile {
                Button(action: onProfile) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
