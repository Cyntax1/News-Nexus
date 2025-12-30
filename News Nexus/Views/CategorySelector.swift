import SwiftUI

struct CategorySelector: View {
    @Binding var selectedCategory: NewsViewModel.Category
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NewsViewModel.Category.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .imageScale(.small)
                            
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selectedCategory == category {
                                Capsule()
                                    .fill(Color.accentColor)
                            } else {
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    .background {
                                        Capsule()
                                            .fill(Color(.systemBackground))
                                    }
                            }
                        }
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
} 