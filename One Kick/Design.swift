//
//  Design.swift
//  One Kick
//
//  Zentrale Farben und Haptik für die ganze App.
//

import SwiftUI
import UIKit // Wichtig für die Vibration

// 1. Unsere Farben (Global verfügbar für alle Seiten)
extension Color {
    static let oneKickBlack = Color(red: 0.05, green: 0.05, blue: 0.05) // Hintergrund
    static let oneKickDarkGray = Color(red: 0.12, green: 0.12, blue: 0.12) // Karten
    static let oneKickNeon = Color(red: 0.85, green: 1.0, blue: 0.0) // Akzent (Neon)
}

// 2. Haptik Manager (Für die Vibration beim Drücken)
class HapticManager {
    static let instance = HapticManager()
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
