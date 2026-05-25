//
//  NotificationViewController.swift
//  TipNotificationExtension
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet private var label: UILabel? // storyboard-Kompatibilität — wird ausgeblendet

    private var homeGoals = 0
    private var awayGoals = 0
    private var fixtureId = 0

    private let leagueLabel    = UILabel()
    private let promptLabel    = UILabel()
    private let homeTeamLabel  = UILabel()
    private let awayTeamLabel  = UILabel()
    private let homeScoreLabel = UILabel()
    private let awayScoreLabel = UILabel()
    private let colonLabel     = UILabel()

    private let neonColor = UIColor(red: 0.18, green: 0.85, blue: 0.37, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        label?.isHidden = true
        view.backgroundColor = UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
        buildLayout()
        updateScoreLabels()
    }

    // MARK: - Notification Content Extension

    func didReceive(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        leagueLabel.text   = (info["leagueName"] as? String ?? "").uppercased()
        homeTeamLabel.text = info["homeTeam"] as? String ?? "Heim"
        awayTeamLabel.text = info["awayTeam"] as? String ?? "Auswärts"
        fixtureId          = info["fixtureId"] as? Int ?? 0
    }

    func didReceive(_ response: UNNotificationResponse,
                   completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "ACTION_TIPPEN" {
            savePendingTip(from: response.notification)
        }
        completion(.dismiss)
    }

    // MARK: - Stepper Actions

    @objc private func homeUp()   { homeGoals = min(homeGoals + 1, 20); updateScoreLabels() }
    @objc private func homeDown() { homeGoals = max(homeGoals - 1,  0); updateScoreLabels() }
    @objc private func awayUp()   { awayGoals = min(awayGoals + 1, 20); updateScoreLabels() }
    @objc private func awayDown() { awayGoals = max(awayGoals - 1,  0); updateScoreLabels() }

    private func updateScoreLabels() {
        homeScoreLabel.text = "\(homeGoals)"
        awayScoreLabel.text = "\(awayGoals)"
    }

    // MARK: - App Group Speicher

    private func savePendingTip(from notification: UNNotification) {
        let info         = notification.request.content.userInfo
        let communityIds = info["communityIds"] as? [String] ?? []
        guard let defaults = UserDefaults(suiteName: "group.com.Benni.One-Kick") else { return }
        var pending = defaults.array(forKey: "pendingTips") as? [[String: Any]] ?? []
        pending.append([
            "fixtureId":    fixtureId,
            "homeGoals":    homeGoals,
            "awayGoals":    awayGoals,
            "communityIds": communityIds,
            "timestamp":    Date().timeIntervalSince1970
        ])
        defaults.set(pending, forKey: "pendingTips")
    }

    // MARK: - Layout

    private func buildLayout() {
        leagueLabel.font          = .systemFont(ofSize: 10, weight: .bold)
        leagueLabel.textColor     = .systemGray
        leagueLabel.textAlignment = .center

        promptLabel.text          = "Dein Tipp"
        promptLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        promptLabel.textColor     = neonColor
        promptLabel.textAlignment = .center

        for lbl in [homeTeamLabel, awayTeamLabel] {
            lbl.font          = .systemFont(ofSize: 14, weight: .semibold)
            lbl.textColor     = .white
            lbl.textAlignment = .center
            lbl.numberOfLines = 2
        }

        for lbl in [homeScoreLabel, awayScoreLabel] {
            lbl.font          = .systemFont(ofSize: 44, weight: .black)
            lbl.textColor     = .white
            lbl.textAlignment = .center
        }

        colonLabel.text          = ":"
        colonLabel.font          = .systemFont(ofSize: 44, weight: .black)
        colonLabel.textColor     = .systemGray
        colonLabel.textAlignment = .center

        let homeMinus = stepperButton("−", action: #selector(homeDown))
        let homePlus  = stepperButton("+", action: #selector(homeUp))
        let awayMinus = stepperButton("−", action: #selector(awayDown))
        let awayPlus  = stepperButton("+", action: #selector(awayUp))

        let homeStack = hStack([homeMinus, homeScoreLabel, homePlus])
        let awayStack = hStack([awayMinus, awayScoreLabel, awayPlus])
        let scoreRow  = hStack([homeStack, colonLabel, awayStack], spacing: 20, distribution: .equalCentering)
        let teamRow   = hStack([homeTeamLabel, awayTeamLabel], spacing: 8, distribution: .fillEqually)

        for sub in [leagueLabel, promptLabel, teamRow, scoreRow] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }

        NSLayoutConstraint.activate([
            leagueLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            leagueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            promptLabel.topAnchor.constraint(equalTo: leagueLabel.bottomAnchor, constant: 2),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            teamRow.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 10),
            teamRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            teamRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scoreRow.topAnchor.constraint(equalTo: teamRow.bottomAnchor, constant: 6),
            scoreRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreRow.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            scoreRow.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            scoreRow.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14),
        ])
    }

    private func stepperButton(_ title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 30, weight: .bold)
        btn.setTitleColor(neonColor, for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return btn
    }

    private func hStack(_ views: [UIView],
                        spacing: CGFloat = 8,
                        distribution: UIStackView.Distribution = .equalCentering) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = spacing
        s.alignment = .center
        s.distribution = distribution
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }
}
