//
//  NewsService.swift
//  One Kick
//

import Foundation
import SwiftUI
import Combine

class NewsService: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var personalizedArticles: [NewsArticle] = []
    @Published var transferArticles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var isLoadingPersonalized = false
    @Published var isLoadingTransfers = false
    @Published var errorMessage: String?

    private let apiKey = "7500892a8f3f4623b8df35bbd25dcc22"
    private let baseURL = "https://newsapi.org/v2/everything"

    // MARK: - Public

    func fetchNews() async {
        let fetched = await fetchArticles(query: "Fussball Bundesliga", language: "de")
        await MainActor.run { articles = fetched }
    }

    func fetchPersonalizedNews(teamNames: [String], leagueNames: [String]) async {
        await MainActor.run { isLoadingPersonalized = true }
        let terms = buildTerms(teams: teamNames, leagues: leagueNames)
        let query: String
        if terms.isEmpty {
            query = "Fussball Bundesliga"
        } else {
            query = "(\(terms)) AND Fußball"
        }
        let fetched = await fetchArticles(query: query, language: "de")
        await MainActor.run {
            personalizedArticles = fetched
            isLoadingPersonalized = false
        }
    }

    func fetchTransferNews(teamNames: [String], leagueNames: [String]) async {
        await MainActor.run { isLoadingTransfers = true }
        let terms = buildTerms(teams: teamNames, leagues: leagueNames)
        let query: String
        if terms.isEmpty {
            query = "Fussball Transfer OR Wechsel"
        } else {
            query = "(\(terms)) AND (Transfer OR Wechsel)"
        }
        let fetched = await fetchArticles(query: query, language: "de")
        await MainActor.run {
            transferArticles = fetched
            isLoadingTransfers = false
        }
    }

    // MARK: - Private

    private func buildTerms(teams: [String], leagues: [String]) -> String {
        let allTerms = Array(Set(teams + leagues)).prefix(6)
        return allTerms.map { "\"\($0)\"" }.joined(separator: " OR ")
    }

    private func fetchArticles(query: String, language: String) async -> [NewsArticle] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?q=\(encodedQuery)&language=\(language)&sortBy=publishedAt&pageSize=30&apiKey=\(apiKey)") else {
            return []
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(NewsResponse.self, from: data) else {
            return []
        }
        return response.articles.filter { $0.title != "[Removed]" }
    }
}
