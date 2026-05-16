//
//  HomeComponents.swift
//  One Kick
//

import SwiftUI

struct OpenTipItem: Identifiable {
    let id: String
    let match: MatchData
    let community: CommunityModel
    let leagueName: String
}

struct OpenGameCard: View {
    let tip: OpenTipItem
    var onTap: (() -> Void)? = nil

    var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: tip.match.fixture.date) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EE HH:mm"   // EE gibt in de_DE bereits "Fr." zurück
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(tip.community.name)
                    .font(.caption).bold()
                    .foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.oneKickNeon)
                    .cornerRadius(6)
                Text(tip.leagueName)
                    .font(.caption).foregroundColor(.gray)
            }

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    teamLogo(tip.match.teams.home.logo)
                    Text(tip.match.teams.home.name)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let action = onTap {
                    Button(action: {
                        HapticManager.instance.impact(style: .light)
                        action()
                    }) {
                        Text("Tippen")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.vertical, 7)
                            .frame(width: 72)
                            .background(Color.oneKickNeon)
                            .cornerRadius(10)
                    }
                }

                HStack(spacing: 6) {
                    Text(tip.match.teams.away.name)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                    teamLogo(tip.match.teams.away.logo)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(formattedDate).font(.caption).foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
    }

    @ViewBuilder
    private func teamLogo(_ url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Circle().fill(Color.gray.opacity(0.3)) }
        }
        .frame(width: 28, height: 28)
    }
}
