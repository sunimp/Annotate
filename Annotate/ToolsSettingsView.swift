import SwiftUI

struct ToolsSettingsView: View {
    @AppStorage(.arrowStyle)
    private var arrowStyle: ArrowStyle
    @AppStorage(.textFontSize)
    private var defaultTextSize: Double
    @AppStorage(.textBackground)
    private var textBackgroundEnabled: Bool
    @AppStorage(.counterFontSize)
    private var defaultCounterSize: Double
    @AppStorage(.counterStyle)
    private var counterStyle: CounterStyle
    @AppStorage(.redactionStyle)
    private var redactionStyle: RectangleStyle
    /// Switches the settings window to the Capture pane, which shows Screen Recording status.
    var showCapturePane: (() -> Void)?

    /// The Redact tool's fills. `.outline` is the plain Rectangle tool, not a redaction.
    static let redactionStyles = RectangleStyle.redactionStyles
    /// Size of the preview tiles' pictures.
    static let previewSize = NSSize(width: 320, height: 56)

    var body: some View {
        let minTextSize = Double(textAnnotationFontSizeRange.lowerBound)
        let maxTextSize = Double(textAnnotationFontSizeRange.upperBound)
        let minCounterSize = Double(counterFontSizeRange.lowerBound)
        let maxCounterSize = Double(counterFontSizeRange.upperBound)
        Form {
            Section {
                SettingsPreviewTile(image: SettingsPreview.arrow(arrowStyle, lineWidth: 6, size: Self.previewSize))
                Picker("Style", selection: $arrowStyle) {
                    ForEach(ArrowStyle.allCases, id: \.self) { style in
                        Label {
                            Text(style.displayName)
                        } icon: {
                            Image(nsImage: SettingsPreview.arrow(style, lineWidth: 2, size: SettingsPreview.menuIconSize))
                        }
                        .tag(style)
                    }
                }
            } header: {
                Text("Arrow Tool")
            }

            Section {
                SettingsSliderRow(
                    title: L10n.string("Default Text Size"),
                    value: $defaultTextSize,
                    range: minTextSize...maxTextSize,
                    step: 1,
                    valueText: { L10n.string("\(Int($0)) pt") },
                    boundsText: { L10n.string("\(Int($0)) pt") }
                )
                Toggle("Label background", isOn: $textBackgroundEnabled)
                SettingsPreviewTile(
                    image: SettingsPreview.text(
                        fontSize: defaultTextSize, hasBackground: textBackgroundEnabled, width: Self.previewSize.width))
            } header: {
                Text("Text Tool")
            }

            Section {
                SettingsSliderRow(
                    title: L10n.string("Default Counter Size"),
                    value: $defaultCounterSize,
                    range: minCounterSize...maxCounterSize,
                    step: 1,
                    valueText: { L10n.string("\(Int($0)) pt") },
                    boundsText: { L10n.string("\(Int($0)) pt") }
                )
                Picker("Style", selection: $counterStyle) {
                    ForEach(CounterStyle.allCases, id: \.self) { style in
                        Label {
                            Text(style.displayName)
                        } icon: {
                            Image(nsImage: SettingsPreview.counter(style, fontSize: 9, size: SettingsPreview.menuIconSize))
                        }
                        .tag(style)
                    }
                }
                SettingsPreviewTile(
                    image: SettingsPreview.counter(
                        counterStyle, fontSize: defaultCounterSize,
                        size: NSSize(width: Self.previewSize.width, height: max(Self.previewSize.height, defaultCounterSize * 2.4))))
                Text(counterStyle == .bordered
                    ? "A circle outlined in the selected color with the number in that color."
                    : "A circle filled with the selected color with a white number, or a black one on light colors.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Counter Tool")
            }

            Section {
                SettingsPreviewTile(image: SettingsPreview.redaction(redactionStyle, size: Self.previewSize))
                Picker("Style", selection: $redactionStyle) {
                    ForEach(Self.redactionStyles, id: \.self) { style in
                        Label {
                            Text(style.displayName)
                        } icon: {
                            Image(nsImage: SettingsPreview.redaction(style, size: SettingsPreview.menuIconSize, text: "Aa12", fontSize: 10))
                        }
                        .tag(style)
                    }
                }
                Text("Use Solid for passwords and other secrets. Pixelate and Blur keep the rough shape of the content, which can sometimes be partly recovered.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if redactionStyle != .solid {
                    screenRecordingPointer
                }
            } header: {
                Text("Redact Tool")
            }
        }
        .formStyle(.grouped)
        .onChange(of: redactionStyle) { _, style in
            // Ask here, never from the overlay: the system prompt sits below the fullscreen
            // overlay window, so from there the user would never see it.
            guard style != .solid, !ScreenSampler.shared.refreshScreenCaptureAccess() else { return }
            ScreenSampler.shared.requestScreenCaptureAccess()
        }
    }

    /// Pixelate and Blur read the screen under the rectangle, which macOS gates behind
    /// Screen Recording. Its status lives in the Capture pane, which Capture Screen shares.
    private var screenRecordingPointer: some View {
        HStack(spacing: 6) {
            Text("Pixelate and Blur need Screen Recording access and use a solid fill until it is granted. Check its status in Capture.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let showCapturePane {
                Button("Show Capture Settings", action: showCapturePane)
            }
        }
        .accessibilityIdentifier("tools.redact.screenRecording")
    }
}
