import Foundation
import SwiftUI

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - LocalizedStringKey Extension
extension LocalizedStringKey {
    static func from(_ key: String) -> LocalizedStringKey {
        return LocalizedStringKey(key)
    }
}

// MARK: - Localization View Modifier
struct LocalizedTextModifier: ViewModifier {
    let key: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(key)
    }
}

extension View {
    func localizedKey(_ key: String) -> some View {
        modifier(LocalizedTextModifier(key: key))
    }
} 