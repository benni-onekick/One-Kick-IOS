//
//  NotificationManager.swift
//  One Kick
//

import UserNotifications
import Foundation

struct UntippedMatchEntry {
    let match: MatchData
    let communityIds: [String]
}

// MARK: - Erinnerungszeiten

enum ReminderInterval: Int, CaseIterable, Identifiable {
    case h24 = 1440
    case h12 = 720
    case h3  = 180
    case h2  = 120
    case h1  = 60
    case m45 = 45
    case m30 = 30
    case m15 = 15
    case m10 = 10
    case m5  = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .h24: return "24 Stunden vorher"
        case .h12: return "12 Stunden vorher"
        case .h3:  return "3 Stunden vorher"
        case .h2:  return "2 Stunden vorher"
        case .h1:  return "1 Stunde vorher"
        case .m45: return "45 Minuten vorher"
        case .m30: return "30 Minuten vorher"
        case .m15: return "15 Minuten vorher"
        case .m10: return "10 Minuten vorher"
        case .m5:  return "5 Minuten vorher"
        }
    }

    var notificationTitle: String {
        switch self {
        case .h24: return "Tipp noch abgeben!"
        case .h12: return "Tipp noch abgeben!"
        case .h3:  return "Noch 3 Stunden bis Anpfiff!"
        case .h2:  return "Noch 2 Stunden bis Anpfiff!"
        case .h1:  return "Noch 1 Stunde bis Anpfiff!"
        case .m45: return "Noch 45 Minuten bis Anpfiff!"
        case .m30: return "Noch 30 Minuten bis Anpfiff!"
        case .m15: return "Noch 15 Minuten bis Anpfiff!"
        case .m10: return "Noch 10 Minuten bis Anpfiff!"
        case .m5:  return "Noch 5 Minuten bis Anpfiff!"
        }
    }

    var timeInterval: TimeInterval { TimeInterval(rawValue) * 60 }
    var idSuffix: String { "\(rawValue)m" }

    // Serialisierung: kommaseparierter String aus rawValues
    static let storageKey = "selectedReminderMinutes"

    static func load() -> Set<Int> {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return Set(raw.split(separator: ",").compactMap { Int($0) })
    }

    static func save(_ selected: Set<Int>) {
        UserDefaults.standard.set(selected.sorted().map { "\($0)" }.joined(separator: ","),
                                  forKey: storageKey)
    }

    // Standard nach erstmaligem Erlauben: „1 Stunde vorher" – nur wenn noch keine Auswahl existiert.
    static func seedDefaultIfNeeded() {
        if load().isEmpty { save([ReminderInterval.h1.rawValue]) }
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // Alle Erinnerungen neu planen — bestehende werden vorher gelöscht.
    // selectedMinutes: Set der gewählten Vorlaufzeiten in Minuten (z.B. {1440, 60, 5})
    func scheduleReminders(untippedMatches: [UntippedMatchEntry], selectedMinutes: Set<Int>) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard !selectedMinutes.isEmpty else { return }

        let intervals = ReminderInterval.allCases.filter { selectedMinutes.contains($0.rawValue) }
        let isoFmt = ISO8601DateFormatter()
        var scheduled = 0

        let sorted = untippedMatches
            .compactMap { entry -> (UntippedMatchEntry, Date)? in
                guard let d = isoFmt.date(from: entry.match.fixture.date) else { return nil }
                return (entry, d)
            }
            .filter { $0.1 > Date() }
            .sorted { $0.1 < $1.1 }

        for (entry, kickoff) in sorted {
            guard scheduled < 60 else { break }
            let match  = entry.match
            let home   = match.teams.home.name
            let away   = match.teams.away.name
            let info: [String: Any] = [
                "fixtureId":    match.fixture.id,
                "homeTeam":     home,
                "awayTeam":     away,
                "leagueName":   match.league.name,
                "communityIds": entry.communityIds
            ]

            for interval in intervals {
                guard scheduled < 60 else { break }
                let fire = kickoff.addingTimeInterval(-interval.timeInterval)
                guard fire > Date() else { continue }
                add(id: "tip_\(interval.idSuffix)_\(match.fixture.id)",
                    title: interval.notificationTitle,
                    body: "\(home) – \(away)",
                    userInfo: info,
                    at: fire)
                scheduled += 1
            }
        }
    }

    private func add(id: String, title: String, body: String,
                     userInfo: [String: Any] = [:], at date: Date) {
        let content = UNMutableNotificationContent()
        content.title              = title
        content.body               = body
        content.sound              = .none
        content.categoryIdentifier = "TIP_MATCH"
        content.userInfo           = userInfo

        let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
