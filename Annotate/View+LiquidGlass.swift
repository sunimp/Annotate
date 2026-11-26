import SwiftUI

/// The segment supplies the refractive glass. This lens adds relief within that
/// surface without nesting another glass effect, which can obscure chip content.
struct ToolbarSelectionLens: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)

    var body: some View {
        shape
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(colorScheme == .dark ? 0.25 : 0.6), location: 0),
                        .init(color: .white.opacity(0.10), location: 0.48),
                        .init(color: .black.opacity(0.06), location: 0.75),
                        .init(color: .white.opacity(0.16), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .controlBackgroundColor))
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.6 : 0.16), lineWidth: 1)
            }
            .overlay {
                shape.inset(by: 0.5).strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.65), location: 0),
                            .init(color: .white.opacity(0.08), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            }
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// The Liquid Glass button style.
    func glassButtonStyle() -> some View {
        buttonStyle(.glass)
    }

    /// Gives an overlay toolbar segment a Liquid Glass background.
    func toolbarGlassSegment(cornerRadius: CGFloat = 18) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
