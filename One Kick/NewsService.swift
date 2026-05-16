//
//  NewsService.swift
//  One Kick
//
//  FIX: 'import Combine' und 'import SwiftUI' hinzugefügt.
//  Damit funktionieren ObservableObject und @Published.
//

import Foundation
import SwiftUI
import Combine // <--- DAS HAT GEFEHLT!

class NewsService: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // -----------------------------------------------------------
    // ACHTUNG: Hier deinen API-Key von newsapi.org einfügen!
    // -----------------------------------------------------------
    private let apiKey = "7500892a8f3f4623b8df35bbd25dcc22"
    
    func fetchNews() async {
        // Wir suchen nach "Fußball Bundesliga" auf Deutsch
        let query = "Fussball Bundesliga"
        
        // URL encoden
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        let urlString = "https://newsapi.org/v2/everything?q=\(encodedQuery)&language=de&sortBy=publishedAt&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            // UI Updates auf MainActor
            await MainActor.run { self.errorMessage = "Ungültige URL" }
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NewsResponse.self, from: data)
            
            await MainActor.run {
                self.articles = response.articles
                self.isLoading = false
            }
        } catch {
            print("Fehler beim Laden: \(error)")
            await MainActor.run {
                self.errorMessage = "Konnte Nachrichten nicht laden. (API Key geprüft?)"
                self.isLoading = false
            }
        }
    }
}
