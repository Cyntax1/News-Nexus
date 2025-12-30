import Foundation
import OSLog

class AISummaryService {
    private let logger = Logger(subsystem: "com.nexus.news", category: "AISummary")
    private let ollamaURL = URL(string: "http://localhost:11434/api/generate")!
    
    // Model to use for summarization
    private let model = "gemma2:2b"
    
    // Generate a summary for an article using Ollama
    func generateSummary(for article: Article) async throws -> String {
        // Construct the content to summarize
        let title = article.title
        let content = article.fullArticleContent ?? article.cleanContent ?? article.description ?? ""
        
        // Bail early if there's not enough content
        guard !content.isEmpty else {
            throw SummaryError.insufficientContent
        }
        
        // Prepare a prompt that works well for summarization
        let prompt = """
        Article Title: \(title)
        
        Article Content:
        \(content)
        
        Please provide a concise 2-3 sentence summary of this article. Focus on the key facts and main points only.
        """
        
        logger.debug("Attempting to summarize article: \(title)")
        
        do {
            let summary = try await requestSummaryFromOllama(prompt: prompt)
            return summary
        } catch {
            logger.error("Failed to generate summary: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Request a summary from Ollama
    private func requestSummaryFromOllama(prompt: String) async throws -> String {
        // Create the request
        var request = URLRequest(url: ollamaURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1, // Low temperature for factual responses
                "top_p": 0.9,
                "max_tokens": 200   // Limit summary length
            ]
        ]
        
        // Serialize the request body to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        // Ensure we got a successful response
        guard httpResponse.statusCode == 200 else {
            logger.error("Ollama API returned status code: \(httpResponse.statusCode)")
            throw SummaryError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generatedText = jsonResponse["response"] as? String else {
            throw SummaryError.invalidResponseFormat
        }
        
        // Clean up the response
        let cleanedSummary = cleanSummary(generatedText)
        
        logger.debug("Successfully generated summary")
        return cleanedSummary
    }
    
    // Clean up the generated summary
    private func cleanSummary(_ summary: String) -> String {
        var cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes that LLMs might add
        let prefixesToRemove = [
            "Summary:", "Here's a summary:", "In summary:", "To summarize:",
            "Concise summary:", "Brief summary:", "TL;DR:", "TLDR:"
        ]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                let startIndex = cleaned.index(cleaned.startIndex, offsetBy: prefix.count)
                cleaned = String(cleaned[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        return cleaned
    }
    
    // Error types
    enum SummaryError: Error, LocalizedError {
        case insufficientContent
        case invalidResponse
        case invalidResponseFormat
        case apiError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .insufficientContent:
                return "Not enough content to generate a summary"
            case .invalidResponse:
                return "Invalid response from Ollama API"
            case .invalidResponseFormat:
                return "Unable to parse Ollama API response"
            case .apiError(let statusCode):
                return "Ollama API error with status code: \(statusCode)"
            }
        }
    }
} 