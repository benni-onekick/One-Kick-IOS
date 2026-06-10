//
//  BadgeView.swift
//  One Kick
//
//  SwiftUI-Komponenten für das Badge-System.
//

import SwiftUI

// MARK: - Badge-Visual (Tier-Ring + SF-Symbol)

/// Programmatisch gestaltetes Badge: Kreis mit Tier-Verlaufsring (Bronze/Silber/Gold)
/// und SF-Symbol mittig. Keine fremden Bilder/Marken → App-Store-konform.
struct BadgeIcon: View {
    let badge: Badge
    var size: CGFloat = 44
    var locked: Bool = false

    private var tierColors: [Color] {
        switch badge.tier {
        case 3:  return [Color(red: 1.0, green: 0.84, blue: 0.0),  Color(red: 0.95, green: 0.70, blue: 0.10)] // Gold
        case 2:  return [Color(white: 0.85), Color(white: 0.55)]                                              // Silber
        default: return [Color(red: 0.82, green: 0.55, blue: 0.28), Color(red: 0.60, green: 0.36, blue: 0.16)] // Bronze
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.oneKickDarkGray)
            Circle()
                .strokeBorder(
                    AngularGradient(colors: locked ? [Color.white.opacity(0.12)] : tierColors + [tierColors[0]],
                                    center: .center),
                    lineWidth: max(2, size * 0.07)
                )
            Image(systemName: badge.icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(
                    locked
                    ? AnyShapeStyle(Color.gray.opacity(0.5))
                    : AnyShapeStyle(LinearGradient(colors: tierColors, startPoint: .top, endPoint: .bottom))
                )
        }
        .frame(width: size, height: size)
        .opacity(locked ? 0.55 : 1)
    }
}

// MARK: - Einzelnes Badge-Chip

struct BadgeChip: View {
    let badge: Badge
    var isSelected: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            BadgeIcon(badge: badge, size: compact ? 18 : 24)
            if !compact {
                Text(badge.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 7)
        .background(isSelected ? Color.oneKickNeon.opacity(0.15) : Color.oneKickDarkGray)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.oneKickNeon : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Horizontale Badge-Reihe (bis zu 3)

struct BadgesRow: View {
    let badgeIds: [String]
    var placeholder: String = "Noch keine Badges ausgewählt"

    private var badges: [Badge] { badgeIds.compactMap { BadgeSystem.shared.badge(for: $0) } }

    var body: some View {
        if badges.isEmpty {
            Text(placeholder)
                .font(.caption)
                .foregroundColor(.gray)
        } else {
            HStack(spacing: 8) {
                ForEach(badges) { badge in BadgeChip(badge: badge) }
                Spacer()
            }
        }
    }
}

// MARK: - Badge-Picker Sheet

struct BadgePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let earnedIds: [String]
    @Binding var selectedIds: [String]

    private let lm = LanguageManager.shared
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]
    private var earnedBadges: [Badge] { earnedIds.compactMap { BadgeSystem.shared.badge(for: $0) } }
    private var unearnedBadges: [Badge] { allBadges.filter { !earnedIds.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(lm.t("badge.pickHint"))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        if earnedBadges.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "trophy").font(.system(size: 40)).foregroundColor(.gray)
                                Text(lm.t("badge.noneYet"))
                                    .font(.subheadline).foregroundColor(.gray)
                                Text("Tippe mehr, erreiche Serien und erziele exakte Tipps um Badges zu verdienen.")
                                    .font(.caption).foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            badgeGrid(title: lm.t("badge.unlocked"), badges: earnedBadges, locked: false)
                        }

                        if !unearnedBadges.isEmpty {
                            badgeGrid(title: lm.t("badge.toEarn"), badges: unearnedBadges, locked: true)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(lm.t("badge.pickTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lm.t("action.done")) {
                        Task { await BadgeSystem.shared.saveSelectedBadges(selectedIds) }
                        dismiss()
                    }
                    .foregroundColor(.oneKickNeon)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(lm.t("action.cancel")) { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }

    @ViewBuilder
    private func badgeGrid(title: String, badges: [Badge], locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.bold()).foregroundColor(.gray).tracking(1)
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(badges) { badge in
                    BadgePickerCell(
                        badge: badge,
                        isSelected: selectedIds.contains(badge.id),
                        locked: locked
                    ) {
                        guard !locked else { return }
                        if selectedIds.contains(badge.id) {
                            selectedIds.removeAll { $0 == badge.id }
                        } else if selectedIds.count < 3 {
                            selectedIds.append(badge.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct BadgePickerCell: View {
    let badge: Badge
    let isSelected: Bool
    let locked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                BadgeIcon(badge: badge, size: 46, locked: locked)
                Text(badge.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(locked ? .gray : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(badge.description)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Fortschrittsbalken für noch nicht erreichte, numerische Badges
                if locked, badge.metric.isProgressable,
                   let value = BadgeSystem.shared.currentValue(for: badge) {
                    let prog = BadgeSystem.shared.progress(for: badge)
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(Color.oneKickNeon)
                                    .frame(width: max(0, geo.size.width * prog))
                            }
                        }
                        .frame(height: 5)
                        Text("\(min(value, badge.goal))/\(badge.goal) · \(Int(prog * 100)) %")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(locked ? Color.oneKickDarkGray.opacity(0.4) : (isSelected ? Color.oneKickNeon.opacity(0.1) : Color.oneKickDarkGray))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.oneKickNeon : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10)).foregroundColor(.gray)
                        .padding(6)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16)).foregroundColor(.oneKickNeon)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Neu-freigeschaltet Toast

struct BadgeUnlockedToast: View {
    let badge: Badge
    var body: some View {
        HStack(spacing: 12) {
            BadgeIcon(badge: badge, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Badge freigeschaltet!")
                    .font(.caption.bold()).foregroundColor(.oneKickNeon)
                Text(badge.name)
                    .font(.subheadline.bold()).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.oneKickNeon, lineWidth: 1.5))
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}
