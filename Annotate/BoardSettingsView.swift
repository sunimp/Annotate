import Combine
import SwiftUI

struct BoardSettingsView: View {
    @AppStorage(.enableBoard)
    private var enableBoard: Bool
    @State private var boardOpacity: Double = BoardManager.shared.opacity

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableBoard) {
                    Text("Enable Board")
                    Text("Show whiteboard or blackboard background")
                }
                .onChange(of: enableBoard) { _, _ in
                    BoardManager.shared.isEnabled = enableBoard
                }

                SettingsSliderRow(
                    title: L10n.string("Board Opacity"),
                    value: $boardOpacity,
                    range: 0.1...1.0,
                    boundsText: { "\(Int($0 * 100))%" }
                )
                .onChange(of: boardOpacity) { _, newValue in
                    BoardManager.shared.opacity = newValue
                }

                boardPreview
            } header: {
                Text("Board Settings")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .onAppear {
            syncState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardStateChanged)) { _ in
            syncState()
        }
    }

    /// Both boards at the chosen opacity over a stand-in for the screen behind them.
    private var boardPreview: some View {
        HStack(spacing: 12) {
            ForEach([BoardView.BoardType.whiteboard, .blackboard], id: \.self) { type in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: type.backgroundColor(opacity: boardOpacity)))
                    .background(
                        LinearGradient(colors: [.blue, .purple, .orange], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                    .frame(width: 96, height: 56)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private func syncState() {
        enableBoard = BoardManager.shared.isEnabled
        boardOpacity = BoardManager.shared.opacity
    }
}
