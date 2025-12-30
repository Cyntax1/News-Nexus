import SwiftUI
import SafariServices

struct ArticleDetailView: View {
    let article: Article
    let articleIndex: Int
    @ObservedObject var viewModel: NewsViewModel
    @State private var showSafari = false
    @State private var showPermissionAlert = false
    @State private var showOllamaAlert = false
    @State private var showAIError = false
    @State private var isCheckingOllama = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // Header image
                if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .foregroundStyle(.quaternary)
                                .overlay {
                                    ProgressView()
                                }
                                .aspectRatio(16/9, contentMode: .fill)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .foregroundStyle(.quaternary)
                                .overlay {
                                    Image(systemName: "photo")
                                        .imageScale(.large)
                                        .foregroundStyle(.tertiary)
                                }
                                .aspectRatio(16/9, contentMode: .fill)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                }
                
                // Content container with consistent margins
                VStack(alignment: .leading, spacing: 20) {
                    // Headline and subheading
                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.headline)
                            .font(.title)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                        
                        if let subheading = article.subheading {
                            Text(subheading)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                    }
                    
                    // Source, author and date
                    HStack {
                        Text(article.source.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.1))
                            }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .imageScale(.small)
                            Text(article.formattedDate)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    // Author
                    if let author = article.author {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.secondary)
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // AI Summary Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            if article.isSummarizationInProgress {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.leading, 8)
                            }
                            
                            Spacer()
                            
                            if !article.isAISummaryLoaded && !article.isSummarizationInProgress {
                                Button {
                                    Task {
                                        isCheckingOllama = true
                                        let isAvailable = await viewModel.checkOllamaAvailability()
                                        isCheckingOllama = false
                                        
                                        if isAvailable {
                                            await viewModel.generateAISummary(for: articleIndex)
                                        } else {
                                            showOllamaAlert = true
                                        }
                                    }
                                } label: {
                                    Label("Generate", systemImage: "wand.and.stars")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background {
                                            Capsule()
                                                .fill(Color.accentColor)
                                        }
                                        .foregroundColor(.white)
                                }
                                .disabled(isCheckingOllama)
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if let summary = article.aiSummary {
                            Text(summary)
                                .font(.body)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                        } else if article.isSummarizationInProgress {
                            Text("Generating summary...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else if viewModel.aiSummaryError != nil {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Unable to generate summary.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                Button("Retry") {
                                    Task {
                                        await viewModel.generateAISummary(for: articleIndex)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Text("Generate an AI summary of this article using Gemma 2:2b model.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.05))
                    }
                    
                    // Description (if available, displayed as a summary)
                    if let description = article.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(description)
                                .font(.body)
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        }
                    }
                    
                    // Full Article Content
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Full Article")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            if viewModel.isLoadingFullContent {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Parse content and display in segments
                        Group {
                            if let content = article.fullArticleContent ?? article.cleanContent {
                                ForEach(parseContentSegments(content), id: \.self) { segment in
                                    Text(segment)
                                        .font(.body)
                                        .lineSpacing(8)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 4)
                                }
                            } else if article.isFullArticleLoaded == false {
                                // If no content is available and we haven't loaded it yet
                                Button {
                                    Task {
                                        await viewModel.fetchFullArticleContent(for: articleIndex)
                                    }
                                } label: {
                                    HStack {
                                        Text("Load Full Article Content")
                                        Image(systemName: "arrow.down.doc")
                                    }
                                    .foregroundColor(.accentColor)
                                    .padding(.vertical, 8)
                                }
                            } else if let description = article.description {
                                // If no content is available, use the description as fallback
                                Text(description)
                                    .font(.body)
                                    .lineSpacing(8)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Notification permission request banner
                    if !viewModel.hasNotificationPermission {
                        notificationRequestBanner
                    }
                    
                    // Location permission request banner (only if notifications are enabled)
                    if viewModel.hasNotificationPermission && !viewModel.hasLocationPermission {
                        locationRequestBanner
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Source attribution at the end
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Article source:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(article.source.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            // View original button
                            Button {
                                showSafari = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("View Original")
                                        .font(.subheadline)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: URL(string: article.url)!) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: article.url)!)
        }
        .task {
            if !article.isFullArticleLoaded {
                await viewModel.fetchFullArticleContent(for: articleIndex)
            }
        }
        .alert("Enable Notifications", isPresented: $showPermissionAlert) {
            Button("Not Now", role: .cancel) {}
            Button("Enable") {
                viewModel.requestNotificationPermission()
            }
        } message: {
            Text("Get breaking news alerts and updates for important stories.")
        }
        .alert("Ollama Not Running", isPresented: $showOllamaAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ollama server is not running at localhost:11434. Please start Ollama and make sure the Gemma2:2b model is available.")
        }
        .alert("AI Summary Error", isPresented: $showAIError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.aiSummaryError ?? "Failed to generate AI summary")
        }
        .onChange(of: viewModel.aiSummaryError) { _, newValue in
            showAIError = newValue != nil
        }
    }
    
    // Notification request banner
    private var notificationRequestBanner: some View {
        Button {
            showPermissionAlert = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.white)
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get Breaking News Alerts")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("Stay informed with important updates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }
    
    // Location request banner
    private var locationRequestBanner: some View {
        Button {
            viewModel.requestLocationPermission()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.white)
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Local News")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("Get news and alerts relevant to your area")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
    
    // Function to parse content into segments
    private func parseContentSegments(_ content: String) -> [String] {
        // Split by possible headers (all caps text followed by colon or line break)
        var segments = [String]()
        let lines = content.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        // Process the lines into paragraphs
        var currentParagraph = ""
        for line in lines {
            // Check if the line might be a header (all uppercase or mostly uppercase with punctuation)
            let uppercaseChars = line.filter { $0.isLetter && $0.isUppercase }
            let letterChars = line.filter { $0.isLetter }
            
            let isHeader = (letterChars.count > 3) && (Double(uppercaseChars.count) / Double(letterChars.count) > 0.8)
            
            if isHeader && !currentParagraph.isEmpty {
                // This is a new header, add the current paragraph first
                segments.append(currentParagraph)
                currentParagraph = line.hasSuffix(".") ? line : line + "."
            } else if currentParagraph.isEmpty {
                currentParagraph = line.hasSuffix(".") ? line : line + "."
            } else if currentParagraph.count + line.count < 350 {
                // Add to the current paragraph
                let lineToAdd = line.hasSuffix(".") ? line : line + "."
                currentParagraph += " " + lineToAdd
            } else {
                // Paragraph is getting too long, start a new one
                segments.append(currentParagraph)
                currentParagraph = line.hasSuffix(".") ? line : line + "."
            }
        }
        
        // Add the last paragraph
        if !currentParagraph.isEmpty {
            segments.append(currentParagraph)
        }
        
        return segments.isEmpty ? [content] : segments
    }
}

// Safari view for loading web content
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = UIColor(.accentColor)
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Nothing to update
    }
} 