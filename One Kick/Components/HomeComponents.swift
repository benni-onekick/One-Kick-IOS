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
    var odds: MatchWinnerOdds? = nil
    var onTap: (() -> Void)? = nil

    @AppStorage("showOdds") private var showOdds = true

    var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: tip.match.fixture.date) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "d.M. EE HH:mm"   // z.B. "11.6. Do 21:00"
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

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(teamNameWithFlag(tip.match.teams.home.name))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
                            .frame(width: 68)
                            .background(Color.oneKickNeon)
                            .cornerRadius(10)
                    }
                }

                HStack(spacing: 6) {
                    Text(teamNameWithFlag(tip.match.teams.away.name))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if showOdds, let o = odds {
                oddsRow(o)
            }
            Text(formattedDate).font(.caption).foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
    }

    private func oddsRow(_ o: MatchWinnerOdds) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.2f", o.home))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                Text("Sieg")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .center, spacing: 1) {
                Text(String(format: "%.2f", o.draw))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Text("Unentschieden")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.gray.opacity(0.65))
            }
            .frame(width: 68, alignment: .center)

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.2f", o.away))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                Text("Sieg")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

}
