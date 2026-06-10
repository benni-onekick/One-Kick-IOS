//
//  NotificationPermissionPrompt.swift
//  One Kick
//
//  Einmaliger Pre-Prompt nach dem ersten Login: fragt nach Benachrichtigungen und
//  stellt bei „Erlauben" standardmäßig „1 Stunde vorher" als Tipp-Erinnerung ein.
//

import SwiftUI

struct NotificationPermissionPrompt: View {
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.oneKickBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(Color.oneKickNeon.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.oneKickNeon)
                }

                VStack(spacing: 12) {
                    Text("Verpasse keinen Tipp mehr")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Wir erinnern dich rechtzeitig vor Anpfiff, wenn du noch nicht getippt hast. Standard: **1 Stunde vorher** – jederzeit im Profil änderbar.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: allow) {
                        Text("Benachrichtigungen erlauben")
                            .font(.headline).bold().foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.oneKickNeon).cornerRadius(14)
                    }

                    Button(action: finish) {
                        Text("Vielleicht später")
                            .font(.subheadline).foregroundColor(.gray)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .interactiveDismissDisabled(true)
    }

    private func allow() {
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            if granted { ReminderInterval.seedDefaultIfNeeded() }
            finish()
        }
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}
