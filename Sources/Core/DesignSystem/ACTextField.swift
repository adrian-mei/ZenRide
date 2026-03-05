import SwiftUI
import UIKit

// MARK: - ACTextField

/// Labelled text field with AC card styling.
public struct ACTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    public init(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                        .font(.body.bold())
                        .foregroundColor(Theme.Colors.acWood)
                    }
                }
        }
    }
}


