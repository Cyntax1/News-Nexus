//
//  ContentView.swift
//  News Nexus
//
//  Created by Rishith Chennupati on 4/4/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var selectedArticleIndex: Int? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $viewModel.searchQuery) {
                        Task {
                            await viewModel.searchNews()
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Category Selector
                    CategorySelector(selectedCategory: $viewModel.selectedCategory)
                        .onChange(of: viewModel.selectedCategory) { _, _ in
                            Task {
                                await viewModel.fetchTopHeadlines()
                            }
                        }
                        .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // News List
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                                ArticleCard(article: article)
                                    .onTapGesture {
                                        selectedArticleIndex = index
                                    }
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 16) // Add extra bottom padding
                    }
                    .refreshable {
                        if viewModel.searchQuery.isEmpty {
                            await viewModel.fetchTopHeadlines()
                        } else {
                            await viewModel.searchNews()
                        }
                    }
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    LoadingView()
                }
                
                // Error Overlay
                if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            if viewModel.searchQuery.isEmpty {
                                await viewModel.fetchTopHeadlines()
                            } else {
                                await viewModel.searchNews()
                            }
                        }
                    }
                }
            }
            .navigationTitle("News Nexus")
            .navigationDestination(item: $selectedArticleIndex) { index in
                if index >= 0 && index < viewModel.articles.count {
                    ArticleDetailView(
                        article: viewModel.articles[index],
                        articleIndex: index,
                        viewModel: viewModel
                    )
                }
            }
        }
        .accentColor(.blue)
        .task {
            await viewModel.fetchTopHeadlines()
        }
        .onChange(of: viewModel.articles) { _, _ in
            // Ensure selectedArticleIndex is valid after articles list changes
            if let index = selectedArticleIndex, index >= viewModel.articles.count {
                selectedArticleIndex = nil
            }
        }
        .alert(
            viewModel.permissionAlertType == .notification ? "Enable Notifications" : "Enable Location",
            isPresented: $viewModel.showPermissionAlert
        ) {
            Button("Not Now", role: .cancel) {}
            Button("Enable") {
                if viewModel.permissionAlertType == .notification {
                    viewModel.requestNotificationPermission()
                } else {
                    viewModel.requestLocationPermission()
                }
            }
        } message: {
            if viewModel.permissionAlertType == .notification {
                Text("Get breaking news alerts and updates for important stories.")
            } else {
                Text("Get news and alerts relevant to your location.")
            }
        }
        .onAppear {
            // Check for permissions after a delay to not disturb initial user experience
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                viewModel.checkAndRequestPermissions()
            }
        }
    }
}

extension Int: Identifiable {
    public var id: Int {
        self
    }
}

#Preview {
    ContentView()
}
