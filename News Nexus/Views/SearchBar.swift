import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .font(.system(size: 17, weight: .medium))
                
                TextField("Search news...", text: $text)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .font(.body)
                    .onSubmit {
                        onSubmit()
                    }
                
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 17))
                            .frame(width: 44, height: 44) // Proper hit target size
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(.systemGray6))
            }
            
            if isFocused {
                Button("Cancel") {
                    isFocused = false
                    text = ""
                }
                .font(.body.weight(.medium))
                .frame(height: 44) // Ensure proper hit target
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: text)
    }
} 