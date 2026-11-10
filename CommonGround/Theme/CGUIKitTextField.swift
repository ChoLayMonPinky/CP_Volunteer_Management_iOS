import SwiftUI
import UIKit

/// UIKit-backed field — SwiftUI `TextField`/`SecureField` lose first-responder and
/// produce “Conversion error!” / zero-size prediction cells on Duo cover.
struct CGUIKitTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var returnKeyType: UIReturnKeyType = .next
    var submitLabel: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.clearButtonMode = .whileEditing
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        apply(to: field)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        apply(to: field)
    }

    private func apply(to field: UITextField) {
        field.placeholder = placeholder
        field.isSecureTextEntry = isSecure
        field.keyboardType = keyboardType
        field.textContentType = textContentType
        field.returnKeyType = returnKeyType
        field.font = UIFont(name: "Manrope-Regular", size: 15) ?? .systemFont(ofSize: 15)
        field.textColor = UIColor.label
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CGUIKitTextField

        init(_ parent: CGUIKitTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let submit = parent.submitLabel {
                submit()
            } else {
                textField.resignFirstResponder()
            }
            return true
        }
    }
}

extension View {
    /// Chrome matching `cgField()` for UIKit-backed inputs.
    func cgUIKitFieldChrome() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: 1.5)
            )
    }
}
