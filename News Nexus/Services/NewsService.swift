import Foundation
import Combine
import OSLog

class NewsService {
    // API key from NewsAPI.org
    private let apiKey = "f63c3d2f9ae64fd7be85cf689cd371c2"
    private let baseURL = "https://newsapi.org/v2"
    private let logger = Logger(subsystem: "com.nexus.news", category: "API")
    
    enum Endpoint {
        case topHeadlines(country: String, category: String?)
        case everything(query: String)
        
        var path: String {
            switch self {
            case .topHeadlines:
                return "/top-headlines"
            case .everything:
                return "/everything"
            }
        }
        
        var queryItems: [URLQueryItem] {
            switch self {
            case .topHeadlines(let country, let category):
                var items = [URLQueryItem(name: "country", value: country)]
                if let category = category {
                    items.append(URLQueryItem(name: "category", value: category))
                }
                return items
            case .everything(let query):
                return [URLQueryItem(name: "q", value: query)]
            }
        }
    }
    
    enum NewsError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Data parsing error: \(error.localizedDescription)"
            case .apiError(let message):
                return "API Error: \(message)"
            }
        }
    }
    
    func fetch(endpoint: Endpoint) async throws -> NewsResponse {
        var components = URLComponents(string: baseURL + endpoint.path)
        var queryItems = endpoint.queryItems
        queryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            logger.error("Invalid URL created")
            throw NewsError.invalidURL
        }
        
        logger.debug("Fetching from URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    // Try to parse error message from API
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       let message = errorResponse["message"] {
                        logger.error("API Error: \(message)")
                        throw NewsError.apiError(message)
                    } else {
                        logger.error("HTTP Error: \(httpResponse.statusCode)")
                        throw NewsError.apiError("HTTP Error \(httpResponse.statusCode)")
                    }
                }
            }
            
            let decoder = JSONDecoder()
            logger.debug("Decoding response data")
            return try decoder.decode(NewsResponse.self, from: data)
        } catch let error as DecodingError {
            logger.error("Decoding error: \(error.localizedDescription)")
            throw NewsError.decodingError(error)
        } catch let error as NewsError {
            logger.error("News error: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw NewsError.networkError(error)
        }
    }
} 