import Foundation

// Model representing a news response from NewsAPI
struct NewsResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

// Model representing a news article
struct Article: Identifiable, Codable, Hashable {
    let id: UUID = UUID()
    let source: Source
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?
    
    // Additional properties for full article content
    var fullArticleContent: String?
    var isFullArticleLoaded: Bool = false
    
    // AI-generated properties
    var aiSummary: String?
    var isAISummaryLoaded: Bool = false
    var isSummarizationInProgress: Bool = false
    
    // Computed property to format published date
    var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, yyyy"
        
        if let date = inputFormatter.date(from: publishedAt) {
            return outputFormatter.string(from: date)
        }
        return publishedAt
    }
    
    // Computed property to clean content by removing truncation markers
    var cleanContent: String? {
        if let fullContent = fullArticleContent {
            return fullContent
        }
        
        guard let content = content else { return nil }
        
        // Remove character count suffixes like [+1234 chars]
        let cleanedContent = content.replacingOccurrences(
            of: "\\s*\\[\\+\\d+\\s*chars\\]\\s*$",
            with: "",
            options: .regularExpression
        )
        
        return cleanedContent
    }
    
    // Computed property to get headline from the title
    var headline: String {
        // Extract the headline portion (before any colon or dash)
        if let colonRange = title.range(of: ":") {
            return String(title[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let dashRange = title.range(of: " - ") {
            return String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return title
    }
    
    // Computed property to get subheading from the title (if available)
    var subheading: String? {
        if let colonRange = title.range(of: ":") {
            let afterColon = String(title[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterColon.isEmpty {
                return afterColon
            }
        } else if let dashRange = title.range(of: " - ") {
            if dashRange.upperBound < title.endIndex {
                let afterDash = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !afterDash.isEmpty && afterDash != source.name {
                    return afterDash
                }
            }
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case source, author, title, description, url, urlToImage, publishedAt, content
    }
    
    // Implement Hashable requirements
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Article, rhs: Article) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model representing a news source
struct Source: Codable, Hashable {
    let id: String?
    let name: String
} 