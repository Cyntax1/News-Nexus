import Foundation
import SwiftUI
import OSLog
import CoreLocation

@MainActor
class NewsViewModel: ObservableObject {
    private let service = NewsService()
    private let contentService = ArticleContentService()
    private let summaryService = AISummaryService()
    private let notificationManager = NotificationManager.shared
    private let logger = Logger(subsystem: "com.nexus.news", category: "ViewModel")
    
    // Published properties
    @Published var articles: [Article] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingFullContent: Bool = false
    @Published var errorMessage: String?
    @Published var selectedCategory: Category = .general
    @Published var searchQuery: String = ""
    @Published var hasNotificationPermission: Bool = false
    @Published var hasLocationPermission: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var permissionAlertType: PermissionAlertType = .notification
    @Published var aiSummaryError: String?
    
    // Alert types for permissions
    enum PermissionAlertType {
        case notification, location
    }
    
    // Categories for news
    enum Category: String, CaseIterable, Identifiable {
        case general, business, technology, entertainment, sports, science, health
        
        var id: String { self.rawValue }
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var icon: String {
            switch self {
            case .general: return "newspaper"
            case .business: return "briefcase"
            case .technology: return "desktop.computer"
            case .entertainment: return "tv"
            case .sports: return "sportscourt"
            case .science: return "atom"
            case .health: return "heart"
            }
        }
    }
    
    init() {
        // Set up notification observing
        updatePermissionStatus()
        
        // Listen for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePermissionStatus),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func updatePermissionStatus() {
        hasNotificationPermission = notificationManager.isAuthorizedForNotifications
        hasLocationPermission = notificationManager.isAuthorizedForLocation
    }
    
    // Request notification permission
    func requestNotificationPermission() {
        notificationManager.requestNotificationPermission()
    }
    
    // Request location permission
    func requestLocationPermission() {
        notificationManager.requestLocationPermission()
    }
    
    // Start location updates for local news
    func startLocationUpdates() {
        notificationManager.startLocationUpdates()
        notificationManager.startLocalBreakingNewsMonitoring()
    }
    
    // Check permission status and show appropriate alerts
    func checkAndRequestPermissions() {
        if !hasNotificationPermission {
            permissionAlertType = .notification
            showPermissionAlert = true
        } else if !hasLocationPermission {
            permissionAlertType = .location
            showPermissionAlert = true
        }
    }
    
    // Fetch top headlines for the selected category
    func fetchTopHeadlines() async {
        isLoading = true
        errorMessage = nil
        
        logger.debug("Fetching top headlines for category: \(self.selectedCategory.rawValue)")
        
        do {
            let response = try await service.fetch(
                endpoint: .topHeadlines(
                    country: "us",
                    category: self.selectedCategory == .general ? nil : self.selectedCategory.rawValue
                )
            )
            
            if response.articles.isEmpty {
                logger.warning("Received empty articles list from API")
                errorMessage = "No articles found for this category. Try another category."
            } else {
                logger.debug("Received \(response.articles.count) articles")
                articles = response.articles
                
                // Check for breaking news - in a real app this would use more sophisticated criteria
                if let firstArticle = articles.first, 
                   firstArticle.title.lowercased().contains("breaking") {
                    notificationManager.scheduleBreakingNewsNotification(
                        title: firstArticle.title,
                        body: firstArticle.description ?? "Breaking news update",
                        articleURL: firstArticle.url
                    )
                }
            }
        } catch {
            logger.error("Error fetching top headlines: \(error.localizedDescription)")
            handleError(error)
        }
        
        isLoading = false
    }
    
    // Search for news with the given query
    func searchNews() async {
        guard !searchQuery.isEmpty else {
            await fetchTopHeadlines()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        logger.debug("Searching for news with query: \(self.searchQuery)")
        
        do {
            let response = try await service.fetch(endpoint: .everything(query: self.searchQuery))
            
            if response.articles.isEmpty {
                logger.warning("No search results found")
                errorMessage = "No articles found for '\(self.searchQuery)'. Try a different search term."
            } else {
                logger.debug("Received \(response.articles.count) search results")
                articles = response.articles
            }
        } catch {
            logger.error("Error searching news: \(error.localizedDescription)")
            handleError(error)
        }
        
        isLoading = false
    }
    
    // Fetch full article content by scraping the source website
    func fetchFullArticleContent(for articleIndex: Int) async {
        guard articleIndex >= 0 && articleIndex < articles.count else { return }
        
        var article = articles[articleIndex]
        
        // Skip if we already have the full content
        if article.isFullArticleLoaded { return }
        
        isLoadingFullContent = true
        
        do {
            let fullContent = try await contentService.fetchFullArticleContent(for: article)
            
            // Update the article with full content
            article.fullArticleContent = fullContent
            article.isFullArticleLoaded = true
            
            // Update the articles array
            articles[articleIndex] = article
            
            logger.debug("Fetched full content: \(fullContent.count) characters")
        } catch {
            logger.error("Error fetching full article content: \(error.localizedDescription)")
            // We don't show an error to the user, we'll just use the snippet we already have
        }
        
        isLoadingFullContent = false
    }
    
    // Generate AI summary for an article
    func generateAISummary(for articleIndex: Int) async {
        guard articleIndex >= 0 && articleIndex < articles.count else { return }
        
        var article = articles[articleIndex]
        
        // Skip if we already have the summary or are in progress
        if article.isAISummaryLoaded || article.isSummarizationInProgress { return }
        
        // Mark as in progress to prevent duplicate requests
        article.isSummarizationInProgress = true
        articles[articleIndex] = article
        
        // Clear any previous error
        aiSummaryError = nil
        
        do {
            // Ensure we have the full content first
            if !article.isFullArticleLoaded {
                await fetchFullArticleContent(for: articleIndex)
                article = articles[articleIndex] // Get updated article after content fetch
            }
            
            // Generate the summary
            let summary = try await summaryService.generateSummary(for: article)
            
            // Update the article with the summary
            article.aiSummary = summary
            article.isAISummaryLoaded = true
            article.isSummarizationInProgress = false
            
            // Update the articles array
            articles[articleIndex] = article
            
            logger.debug("Generated AI summary: \(summary)")
        } catch {
            // Update article status
            article.isSummarizationInProgress = false
            articles[articleIndex] = article
            
            // Set error message
            aiSummaryError = "Failed to generate summary: \(error.localizedDescription)"
            logger.error("Error generating AI summary: \(error.localizedDescription)")
        }
    }
    
    // Check if Ollama is running and available
    func checkOllamaAvailability() async -> Bool {
        do {
            let url = URL(string: "http://localhost:11434/api/tags")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            logger.error("Error checking Ollama availability: \(error.localizedDescription)")
            return false
        }
    }
    
    // Handle errors from the API
    private func handleError(_ error: Error) {
        if let newsError = error as? NewsService.NewsError {
            switch newsError {
            case .invalidURL:
                errorMessage = "Invalid URL. Please try again later."
            case .networkError(let err):
                errorMessage = "Network error: \(err.localizedDescription)"
            case .decodingError(let err):
                errorMessage = "Could not process the data: \(err.localizedDescription)"
            case .apiError(let message):
                errorMessage = message
            }
        } else {
            errorMessage = "An unknown error occurred: \(error.localizedDescription)"
        }
        
        logger.error("Error message set to: \(self.errorMessage ?? "nil")")
    }
} 