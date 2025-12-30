import SwiftUI

struct ArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundStyle(.quaternary)
                            .overlay {
                                ProgressView()
                            }
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
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(article.source.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.1))
                        }
                    
                    Spacer()
                    
                    Text(article.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(article.headline)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .lineSpacing(4)
                
                if let subheading = article.subheading {
                    Text(subheading)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                else if let description = article.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
    }
} 