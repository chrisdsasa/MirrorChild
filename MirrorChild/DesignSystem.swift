import SwiftUI

// MARK: - Design System Constants

struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Primary accent color
        static let accent = Color.accentColor
        static let accentLight = Color.accentColor.opacity(0.5)
        static let accentDark = Color.accentColor.opacity(0.8)
        
        // Named theme colors
        static let rebeccaPurple = Color(red: 0.4, green: 0.2, blue: 0.6) // #663399
        static let thistle = Color(red: 0.847, green: 0.749, blue: 0.847) // #D8BFD8
        
        // Surface colors
        static let surface = thistle.opacity(0.2)
        static let surfaceSecondary = thistle.opacity(0.1)
        
        // Text colors
        static let textPrimary = Color.primary.opacity(0.9)
        static let textSecondary = Color.primary.opacity(0.7)
        static let textTertiary = Color.primary.opacity(0.5)
        
        // Status colors
        static let success = Color.green
        static let error = Color.red
        static let warning = Color.orange
        static let info = Color.blue
        
        // Material effects
        static let glassMaterial = Material.ultraThinMaterial
    }
    
    // MARK: - Typography
    struct Typography {
        // Title styles
        static let largeTitle = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 20, weight: .medium, design: .rounded)
        
        // Body text styles
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let caption = Font.system(size: 14, weight: .regular, design: .rounded)
        
        // Button text styles
        static let buttonPrimary = Font.system(size: 17, weight: .medium, design: .rounded)
        static let buttonSecondary = Font.system(size: 16, weight: .medium, design: .rounded)
    }
    
    // MARK: - Layout
    struct Layout {
        // Spacing
        static let spacingSmall: CGFloat = 8
        static let spacingMedium: CGFloat = 16
        static let spacingLarge: CGFloat = 24
        static let spacingExtraLarge: CGFloat = 32
        
        // Radius
        static let radiusSmall: CGFloat = 8
        static let radiusMedium: CGFloat = 16
        static let radiusLarge: CGFloat = 24
        static let radiusExtraLarge: CGFloat = 32
        
        // Shadows
        static let shadowLight = ShadowStyle(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        static let shadowMedium = ShadowStyle(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        static let shadowStrong = ShadowStyle(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Shadow Style
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Button Styles
    
    struct ButtonStyles {
        // Primary button with accent color and rounded corners
        struct PrimaryButton: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Typography.buttonPrimary)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.radiusMedium)
                            .fill(Colors.accent)
                    )
                    .scaleEffect(configuration.isPressed ? 0.98 : 1)
                    .opacity(configuration.isPressed ? 0.9 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            }
        }
        
        // Secondary button with outline
        struct SecondaryButton: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Typography.buttonSecondary)
                    .foregroundColor(Colors.accent)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.radiusMedium)
                            .stroke(Colors.accent, lineWidth: 1.5)
                    )
                    .scaleEffect(configuration.isPressed ? 0.98 : 1)
                    .opacity(configuration.isPressed ? 0.9 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            }
        }
        
        // Icon button with subtle scaling animation
        struct IconButton: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.92 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            }
        }
        
        // Circle button commonly used in the app
        struct CircleButton: ButtonStyle {
            var color: Color = Colors.accent
            
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .padding(Layout.spacingMedium)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(radius: 5, x: 0, y: 2)
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            }
        }
        
        // Scale button style for interactive elements
        struct ScaleButton: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            }
        }
    }
}

// MARK: - Custom View Modifiers

extension View {
    // Apply shadow style
    func withShadow(_ style: DesignSystem.ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    // Card style for common container views
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Layout.spacingMedium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                    .fill(DesignSystem.Colors.glassMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                    .stroke(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
            .withShadow(DesignSystem.Layout.shadowMedium)
    }
    
    // Apply standard heading style
    func headingStyle() -> some View {
        self
            .font(DesignSystem.Typography.title)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.bottom, DesignSystem.Layout.spacingSmall)
    }
    
    // Apply floating button style
    func floatingButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.buttonPrimary)
            .padding()
            .background(Circle().fill(DesignSystem.Colors.accent))
            .foregroundColor(.white)
            .withShadow(DesignSystem.Layout.shadowLight)
    }
} 