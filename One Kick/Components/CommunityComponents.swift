//
//  CommunityComponents.swift
//  One Kick
//
//  UPDATE: CommunityRankCard zeigt jetzt LIVE + Offene Tipps an.
//

import SwiftUI

// 1. HEADER & TEXTE
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.caption).bold().foregroundColor(.gray).textCase(.uppercase)
    }
}

// LIVE BADGE
struct LiveBadge: View {
    var body: some View {
        Text("LIVE")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.red)
            .cornerRadius(6)
            .shadow(color: Color.red.opacity(0.6), radius: 4, x: 0, y: 0)
    }
}

// NEU: BADGE FÜR OFFENE TIPPS
struct OpenTipsBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .frame(width: 24, height: 24)
            .background(Color.oneKickNeon)
            .clipShape(Circle())
            .shadow(color: Color.oneKickNeon.opacity(0.4), radius: 4, x: 0, y: 0)
    }
}

// 2. BUTTONS & INPUTS
struct SheetOptionButton: View {
    let title: String; let subtitle: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: { HapticManager.instance.impact(style: .light); action() }) {
            HStack {
                Image(systemName: icon).font(.title2).foregroundColor(color).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline).bold().foregroundColor(.white); Text(subtitle).font(.caption).foregroundColor(.gray) }
                Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray)
            }.padding().background(Color.oneKickDarkGray).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(color == .oneKickNeon ? Color.oneKickNeon.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct CustomTextField: View {
    let title: String; let placeholder: String; @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption).bold().foregroundColor(.gray).padding(.leading, 5)
            TextField(placeholder, text: $text).padding().background(Color.oneKickDarkGray).cornerRadius(12).foregroundColor(.white).overlay(RoundedRectangle(cornerRadius: 12).stroke(text.isEmpty ? Color.white.opacity(0.1) : Color.oneKickNeon, lineWidth: 1))
        }.padding(.horizontal)
    }
}

struct LeagueSelectionChip: View {
    let title: String; let isSelected: Bool; var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(title).font(.caption).bold().foregroundColor(isSelected ? .black : .white).padding(.vertical, 12).padding(.horizontal, 10).frame(maxWidth: .infinity).background(isSelected ? Color.oneKickNeon : Color.oneKickDarkGray).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.oneKickNeon : Color.white.opacity(0.15), lineWidth: 1)).lineLimit(2).minimumScaleFactor(0.8)
        }
    }
}

// 3. LISTEN-KARTEN

// 4. Onboarding
struct OnboardingCommunityView: View {
    var onCreate: () -> Void; var onJoin: () -> Void; var onChallenge: () -> Void
    var body: some View {
        VStack(spacing: 25) {
            Spacer(); Image(systemName: "person.3.sequence.fill").font(.system(size: 70)).foregroundColor(.oneKickDarkGray).padding(.bottom, 10)
            VStack(spacing: 8) { Text("Willkommen bei One Kick").font(.title2).fontWeight(.black).foregroundColor(.white).multilineTextAlignment(.center); Text("Starte jetzt durch! Erstelle eine Runde, tritt Freunden bei oder stelle dich einer Challenge.").font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 30) }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onCreate) { HStack { Image(systemName: "plus.square.fill.on.square.fill").font(.title3); Text("Community erstellen").font(.headline).bold() }.foregroundColor(.oneKickBlack).frame(maxWidth: .infinity).padding().background(Color.oneKickNeon).cornerRadius(15) }
                Button(action: onJoin) { HStack { Image(systemName: "person.2.badge.gearshape.fill").font(.title3); Text("Community beitreten").font(.headline).bold() }.foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.oneKickDarkGray).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1)) }
                Button(action: onChallenge) { HStack { Image(systemName: "trophy.fill").font(.title3); Text("Challenge suchen").font(.headline).bold() }.foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.oneKickDarkGray).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.oneKickNeon.opacity(0.5), lineWidth: 1)) }
            }.padding(.horizontal, 30).padding(.bottom, 50)
        }
    }
}
