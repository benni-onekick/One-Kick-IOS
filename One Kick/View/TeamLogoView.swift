//
//  TeamLogoView.swift
//  One Kick
//
//  ROBUST: Fallback für leere Namen und fehlende Bilder.
//

import SwiftUI

struct TeamLogoView: View {
    let teamName: String
    let size: CGFloat
    
    var body: some View {
        // Safe Cleaning: Entfernt Leerzeichen und macht alles klein
        let imageName = teamName.lowercased().replacingOccurrences(of: " ", with: "")
        
        if !imageName.isEmpty, UIImage(named: imageName) != nil {
            // Echtes Bild vorhanden
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback: Farbiger Kreis
            ZStack {
                Circle()
                    .fill(getTeamColor(name: teamName))
                    .frame(width: size, height: size)
                
                // Sicherstellen, dass ein Buchstabe existiert
                if let firstChar = teamName.first {
                    Text(String(firstChar))
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    // Wenn Name komplett leer ist: Fragezeichen
                    Text("?")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // Robuste Farb-Logik (Erweiterbar)
    func getTeamColor(name: String) -> Color {
        let n = name.lowercased()
        if n.contains("bayern") || n.contains("leipzig") || n.contains("stuttgart") || n.contains("liverpool") || n.contains("arsenal") { return Color.red }
        if n.contains("bvb") || n.contains("dortmund") || n.contains("alemannia") { return Color.yellow }
        if n.contains("hsv") || n.contains("hamburger") || n.contains("schalke") || n.contains("hertha") || n.contains("city") || n.contains("chelsea") || n.contains("leicester") { return Color.blue }
        if n.contains("werder") || n.contains("wolfsburg") || n.contains("celtic") { return Color.green }
        if n.contains("frankfurt") || n.contains("juventus") || n.contains("newcastle") { return Color.black }
        if n.contains("real") || n.contains("madrid") || n.contains("tottenham") { return Color.white }
        if n.contains("barca") || n.contains("barcelona") { return Color.purple }
        if n.contains("milan") { return Color.red }
        if n.contains("inter") { return Color.blue }
        if n.contains("paris") || n.contains("psg") { return Color.blue }
        if n.contains("galatasaray") { return Color.orange }
        if n.contains("fenerbahce") { return Color.yellow }
        
        return Color.gray // Sicherer Standardwert
    }
}
