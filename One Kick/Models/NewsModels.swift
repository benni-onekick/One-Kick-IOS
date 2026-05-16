//
//  NewsModels.swift
//  One Kick
//
//  Modell für die API-Antwort von NewsAPI.org
//

import Foundation
import Combine

// Die oberste Ebene der Antwort
struct NewsResponse: Codable {
    let status: String
    let articles: [NewsArticle]
}

// Ein einzelner Artikel
struct NewsArticle: Identifiable, Codable {
    let id = UUID() // Erstellen wir selbst für SwiftUI
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let source: Source
    
    // API-Keys ignorieren, die wir nicht brauchen
    private enum CodingKeys: String, CodingKey {
        case title, description, url, urlToImage, publishedAt, source
    }
}

struct Source: Codable {
    let name: String
}
