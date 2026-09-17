import SwiftUI

public struct SKCTPracticeView: View {
    @StateObject private var drawingViewModel = SKCTDrawingViewModel()

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1. Whiteboard Drawing Canvas (fills entire background)
            SKCTWhiteboardView(viewModel: drawingViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. Top-Right Floating Calculator Panel
            SKCTCalculatorView()
                .padding(.top, 48) // Below toolbar
                .padding(.trailing, 16)
        }
        .frame(minWidth: 800, minHeight: 550)
    }
}
