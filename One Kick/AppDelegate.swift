//
//  AppDelegate.swift
//  One Kick
//

import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        processPendingTips()
    }

    // MARK: - Notification Kategorien registrieren

    private func registerNotificationCategories() {
        let tippen = UNNotificationAction(
            identifier: "ACTION_TIPPEN",
            title: "Jetzt tippen",
            options: [.foreground]
        )
        let later = UNNotificationAction(
            identifier: "ACTION_LATER",
            title: "Später",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "TIP_MATCH",
            actions: [tippen, later],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Ausstehende Tipps in Firebase speichern

    func processPendingTips() {
        guard let defaults = UserDefaults(suiteName: "group.com.Benni.One-Kick") else { return }
        let pending = defaults.array(forKey: "pendingTips") as? [[String: Any]] ?? []
        guard !pending.isEmpty else { return }
        defaults.removeObject(forKey: "pendingTips")

        guard let userId = Auth.auth().currentUser?.uid,
              let email  = Auth.auth().currentUser?.email else { return }

        let db = Firestore.firestore()
        for tip in pending {
            guard let fixtureId    = tip["fixtureId"]    as? Int,
                  let homeGoals    = tip["homeGoals"]    as? Int,
                  let awayGoals    = tip["awayGoals"]    as? Int,
                  let communityIds = tip["communityIds"] as? [String] else { continue }

            for cid in communityIds {
                db.collection("communities").document(cid)
                  .collection("bets").document("\(userId)_\(fixtureId)")
                  .setData([
                    "userId":    userId,
                    "email":     email,
                    "fixtureId": fixtureId,
                    "homeGoals": homeGoals,
                    "awayGoals": awayGoals
                  ])
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tipSaved, object: nil,
                                            userInfo: nil)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Reaktion auf Aktions-Button (z.B. "Später" oder Direkttipp aus dem Custom-UI)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        processPendingTips()

        if response.actionIdentifier == "ACTION_TIPPEN" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openTippenTab, object: nil)
            }
        }
        completionHandler()
    }

    // Benachrichtigung auch anzeigen wenn App im Vordergrund ist
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
