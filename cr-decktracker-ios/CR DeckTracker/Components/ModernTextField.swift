import SwiftUI

struct ModernTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let accentColor: Color

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? accentColor : .white.opacity(0.5))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isFocused ? accentColor : Color.white.opacity(0.15),
                    lineWidth: isFocused ? 2 : 1
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        )
    }
}
