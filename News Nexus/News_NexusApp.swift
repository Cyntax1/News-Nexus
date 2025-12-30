//
//  News_NexusApp.swift
//  News Nexus
//
//  Created by Rishith Chennupati on 4/4/25.
//

import SwiftUI
import OSLog

@main
struct News_NexusApp: App {
    @Environment(\.colorScheme) private var colorScheme
    private let logger = Logger(subsystem: "com.nexus.news", category: "App")
    
    init() {
        #if DEBUG
        // Enable network request logging for debugging
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        // Note: URLSession.shared is a let constant and cannot be reassigned
        logger.debug("News Nexus app starting")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme) // This allows the app to follow system settings
                .onAppear {
                    logger.debug("Main view appeared")
                }
        }
    }
}
