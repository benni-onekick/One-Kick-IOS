//
//  BettingComponents.swift
//  One Kick
//
//  Layout:
//  - Kein "vs" mehr. Tippen-Button rückt in die Mitte.
//  - Getippt + Zukunft: Tipp + "Ändern" in der Mitte, "Noch keine Pkte." rechts.
//  - Getippt + Live: Tipp (neon) oben, Live-Ergebnis (rot) unten in der Mitte, Punkte rechts.
//  - Getippt + Fertig: Tipp (neon), Endergebnis (weiß), "Endergebnis"-Label in der Mitte, Punkte rechts.
//

import SwiftUI

private let centerWidth: CGFloat = 72

struct ApiMatchRow: View {
    let match: MatchData
    var onTapTip: (() -> Void)? = nil
    var myTip: (home: Int, away: Int)? = nil
    var showLeague: Bool = false
    var prediction: MatchPrediction? = nil

    var isLive:     Bool { ["1H","2H","HT","ET","P","LIVE"].contains(match.fixture.status.short) }
    var isFuture:   Bool { ["NS","TBD"].contains(match.fixture.status.short) }

    var liveScore: (home: Int, away: Int) {
        (match.goals.home ?? 0, match.goals.away ?? 0)
    }

    var minuteLabel: String {
        if match.fixture.status.short == "HT" { return "HZ" }
        if let e = match.fixture.status.elapsed { return "\(e)'" }
        return ""
    }

    var formattedDateTime: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: match.fixture.date) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EE HH:mm"   // EE gibt in de_DE bereits "Fr." zurück
        return fmt.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if showLeague {
                    HStack(spacing: 5) {
                        if isLive {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.red)
                        }
                        Text(match.league.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.75))
                            .lineLimit(1)
                    }
                } else if isLive {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.red)
                }

                HStack(spacing: 0) {
                    // Heimteam
                    HStack(spacing: 6) {
                        teamLogo(match.teams.home.logo)
                        Text(match.teams.home.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Mitte (feste Breite)
                    centerView
                        .frame(width: centerWidth)

                    // Auswärtsteam
                    HStack(spacing: 6) {
                        Text(match.teams.away.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.trailing)
                        teamLogo(match.teams.away.logo)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if isFuture {
                    HStack(spacing: 12) {
                        Text(formattedDateTime)
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let pred = prediction {
                            predictionBadge(pred)
                        }
                    }
                }
            }

            rightColumnView
        }
        .padding(14)
        .background(Color.oneKickDarkGray)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isLive ? Color.red.opacity(0.6) : Color.white.opacity(0.05),
                    lineWidth: isLive ? 1.5 : 1
                )
        )
        // LIVE-Badge erscheint inline neben dem Liga-Namen (showLeague=true)
        // oder der rote Kartenrand signalisiert Live (showLeague=false)
    }

    // MARK: - Mitte

    @ViewBuilder
    private var centerView: some View {
        if isFuture {
            if let tip = myTip {
                tippedFutureCenter(tip: tip)
            } else if let action = onTapTip {
                tippenButton(action: action)
            } else {
                // Nur Anzeige (z.B. Startseite) – Trennzeichen
                Text("vs").font(.caption).bold().foregroundColor(.gray)
            }
        } else if isLive {
            if let tip = myTip {
                liveTippedCenter(tip: tip)
            } else {
                liveScoreCenter
            }
        } else {
            // Abgeschlossen
            if let tip = myTip {
                finishedTippedCenter(tip: tip)
            } else {
                let h = match.goals.home.map { String($0) } ?? "-"
                let a = match.goals.away.map { String($0) } ?? "-"
                VStack(spacing: 2) {
                    Text("Kein Tipp")
                        .font(.system(size: 7, weight: .bold)).foregroundColor(.gray)
                    Text("\(h):\(a)").font(.subheadline).fontWeight(.black).foregroundColor(.white)
                }
            }
        }
    }

    // Tippen-Button (kein Tipp, Zukunft)
    private func tippenButton(action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.instance.impact(style: .light); action() }) {
            Text("Tippen")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.oneKickNeon)
                .cornerRadius(10)
        }
    }

    // Tipp + Ändern (getippt, Zukunft)
    private func tippedFutureCenter(tip: (home: Int, away: Int)) -> some View {
        Button(action: { HapticManager.instance.impact(style: .light); onTapTip?() }) {
            VStack(spacing: 1) {
                Text("\(tip.home):\(tip.away)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.black)
                Text("Ändern")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .background(Color.oneKickNeon)
            .cornerRadius(10)
        }
    }

    // Tipp (neon) + Live-Ergebnis (rot) (getippt, live)
    private func liveTippedCenter(tip: (home: Int, away: Int)) -> some View {
        VStack(spacing: 2) {
            Text("\(tip.home):\(tip.away)")
                .font(.system(size: 12, weight: .black)).foregroundColor(.oneKickNeon)
            Text("\(liveScore.home):\(liveScore.away)")
                .font(.system(size: 12, weight: .black)).foregroundColor(.red)
            if !minuteLabel.isEmpty {
                Text(minuteLabel)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.red.opacity(0.85))
            }
        }
    }

    // Live-Ergebnis + Minute (kein Tipp, live)
    private var liveScoreCenter: some View {
        VStack(spacing: 2) {
            Text("\(liveScore.home):\(liveScore.away)")
                .font(.subheadline).fontWeight(.black).foregroundColor(.red)
            if !minuteLabel.isEmpty {
                Text(minuteLabel)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.red.opacity(0.85))
            }
        }
    }

    // Tipp (neon) + Endergebnis (weiß) (getippt, abgeschlossen)
    private func finishedTippedCenter(tip: (home: Int, away: Int)) -> some View {
        let h = match.goals.home.map { String($0) } ?? "-"
        let a = match.goals.away.map { String($0) } ?? "-"
        return VStack(spacing: 2) {
            Text("\(tip.home):\(tip.away)")
                .font(.system(size: 12, weight: .black)).foregroundColor(.oneKickNeon)
            Text("\(h):\(a)")
                .font(.system(size: 12, weight: .black)).foregroundColor(.white)
        }
    }

    // MARK: - Rechte Spalte

    @ViewBuilder
    private var rightColumnView: some View {
        if isFuture {
            // Zukunft: rechte Spalte immer leer (Tippen/Ändern ist in der Mitte)
        } else if let tip = myTip {
            let pts = calculatePoints(tip: tip)
            VStack(spacing: 0) {
                Text("\(pts)").font(.title2).bold()
                    .foregroundColor(pts > 0 ? .oneKickNeon : .white)
                Text("Pkt").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }
            .frame(width: 50)
        } else {
            VStack(spacing: 0) {
                Text("0").font(.title2).bold().foregroundColor(.white)
                Text("Pkt").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }
            .frame(width: 50)
        }
    }

    // MARK: - Punkte

    private func calculatePoints(tip: (home: Int, away: Int)) -> Int {
        let aH: Int; let aA: Int
        if isLive {
            aH = liveScore.home; aA = liveScore.away
        } else {
            guard let h = match.goals.home, let a = match.goals.away else { return 0 }
            aH = h; aA = a
        }
        var pts = 0
        if tip.home == aH { pts += 1 }
        if tip.away == aA { pts += 1 }
        let td = tip.home - tip.away; let ad = aH - aA
        if td == ad { pts += 2 }
        let tr = td > 0 ? 1 : (td < 0 ? -1 : 0)
        let ar = ad > 0 ? 1 : (ad < 0 ? -1 : 0)
        if tr == ar { pts += 3 }
        return pts
    }

    // MARK: - Prognose

    private func predictionBadge(_ pred: MatchPrediction) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundColor(.oneKickNeon)
            Text(predictionSummary(pred))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    private func predictionSummary(_ pred: MatchPrediction) -> String {
        let h = parsePercent(pred.percent.home)
        let a = parsePercent(pred.percent.away)
        let d = parsePercent(pred.percent.draw)
        if h >= a && h >= d { return "Heimsieg \(pred.percent.home)" }
        if a > h && a >= d  { return "Auswärtssieg \(pred.percent.away)" }
        return "Unentschieden \(pred.percent.draw)"
    }

    private func parsePercent(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    // MARK: - Logo

    @ViewBuilder
    private func teamLogo(_ url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Circle().fill(Color.gray.opacity(0.3)) }
        }
        .frame(width: 26, height: 26)
    }
}

struct TeamRow: View {
    let name: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: URL(string: icon)) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else { Circle().fill(Color.gray.opacity(0.3)) }
            }
            .frame(width: 24, height: 24)
            Text(name).font(.subheadline).bold().foregroundColor(.white).lineLimit(1)
        }
    }
}

struct CircleButton: View {
    let icon: String
    let enabled: Bool

    var body: some View {
        Image(systemName: icon)
            .font(.title3.bold())
            .foregroundColor(enabled ? .white : .gray.opacity(0.3))
            .frame(width: 30, height: 30)
            .background(Color.oneKickDarkGray)
            .clipShape(Circle())
    }
}
