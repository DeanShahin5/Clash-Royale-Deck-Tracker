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
                .foregroundColor(isFocused ? accentColor : Color(hex: "7F8C8D"))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(hex: "95A5A6")))
                .foregroundColor(Color(hex: "2C3E50"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "F5F7FA"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isFocused ? accentColor : Color(hex: "E0E6ED"),
                    lineWidth: isFocused ? 2 : 1
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        )
    }
}
