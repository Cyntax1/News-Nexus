import Foundation
import OSLog

class ArticleContentService {
    private let logger = Logger(subsystem: "com.nexus.news", category: "ContentScraper")
    
    // Fetch full article content from the source website
    func fetchFullArticleContent(for article: Article) async throws -> String {
        guard let url = URL(string: article.url) else {
            throw URLError(.badURL)
        }
        
        logger.debug("Fetching full content from: \(url.absoluteString)")
        
        do {
            // Fetch the HTML content
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let htmlString = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "ArticleContentService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTML encoding"])
            }
            
            // Extract content using simple regex patterns for paragraphs
            var content = extractContentFromHTML(htmlString, for: article)
            
            // Clean up the content
            content = cleanContent(content)
            
            if content.isEmpty {
                // If still empty, fall back to the description or content from API
                return article.cleanContent ?? article.description ?? "Unable to retrieve full article content."
            }
            
            logger.debug("Successfully extracted \(content.count) characters of content")
            return content
        } catch {
            logger.error("Error fetching article content: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Extract content from HTML using regex
    private func extractContentFromHTML(_ html: String, for article: Article) -> String {
        // First, try to find article content by looking for common article containers
        let patterns = [
            // Pattern for paragraphs inside article tags
            "<article[^>]*>(.*?)</article>",
            // Pattern for div with article-content class
            "<div[^>]*class=[\"'].*?article-content.*?[\"'][^>]*>(.*?)</div>",
            // Pattern for div with entry-content class
            "<div[^>]*class=[\"'].*?entry-content.*?[\"'][^>]*>(.*?)</div>",
            // Pattern for div with story-body class
            "<div[^>]*class=[\"'].*?story-body.*?[\"'][^>]*>(.*?)</div>",
            // Pattern for div with content class
            "<div[^>]*class=[\"'].*?content.*?[\"'][^>]*>(.*?)</div>",
            // Pattern for div with post-content class
            "<div[^>]*class=[\"'].*?post-content.*?[\"'][^>]*>(.*?)</div>",
            // Main content
            "<main[^>]*>(.*?)</main>"
        ]
        
        // Try each pattern
        for pattern in patterns {
            if let articleContent = extractWithPattern(pattern, from: html) {
                if let paragraphs = extractParagraphs(from: articleContent) {
                    if paragraphs.count > 3 { // Ensure we have enough paragraphs
                        return paragraphs
                    }
                }
            }
        }
        
        // If we couldn't find article content with containers, try to extract all paragraphs
        if let paragraphs = extractParagraphs(from: html) {
            return paragraphs
        }
        
        // BBC-specific handling
        if article.source.name.contains("BBC") {
            if let bbcContent = extractWithPattern("<div[^>]*class=[\"'].*?ssrcss-11r1m41-RichTextComponentWrapper.*?[\"'][^>]*>(.*?)</div>", from: html) {
                if let paragraphs = extractParagraphs(from: bbcContent) {
                    return paragraphs
                }
            }
        }
        
        // If still no content, try to extract any paragraph tags
        return extractParagraphs(from: html) ?? ""
    }
    
    // Extract content matching a pattern
    private func extractWithPattern(_ pattern: String, from html: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    return String(html[contentRange])
                }
            }
        } catch {
            logger.error("Regex error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Extract paragraphs from HTML content
    private func extractParagraphs(from html: String) -> String? {
        do {
            // Pattern to extract paragraph content
            let pattern = "<p[^>]*>(.*?)</p>"
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            let matches = regex.matches(in: html, options: [], range: range)
            
            // Extract paragraph texts
            var paragraphs: [String] = []
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: html) {
                    let text = String(html[textRange])
                    // Remove HTML tags from paragraph text
                    let cleanText = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    
                    if !cleanText.isEmpty {
                        paragraphs.append(cleanText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            
            // Combine paragraphs
            if paragraphs.isEmpty {
                return nil
            }
            
            return paragraphs.joined(separator: "\n\n")
        } catch {
            logger.error("Paragraph extraction error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Clean up extracted content
    private func cleanContent(_ content: String) -> String {
        var cleaned = content
        
        // Decode HTML entities
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        
        // Remove any remaining HTML tags
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\n\\s*\\n", with: "\n\n", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 