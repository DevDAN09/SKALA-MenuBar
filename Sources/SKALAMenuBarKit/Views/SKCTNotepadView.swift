import SwiftUI

public struct SKCTNotepadView: View {
    @ObservedObject var viewModel: SKCTNotepadViewModel

    public init(viewModel: SKCTNotepadViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Background matching whiteboard canvas
            Color(nsColor: .textBackgroundColor)
                .edgesIgnoringSafeArea(.all)

            GridBackgroundPattern()
                .opacity(0.08)

            // TextEditor for keyboard typing
            TextEditor(text: $viewModel.text)
                .font(.system(size: viewModel.fontSize, weight: .regular, design: .monospaced))
                .lineSpacing(6)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .scrollContentBackground(.hidden)

            // Subtle placeholder guide when empty
            if viewModel.text.isEmpty {
                Text("이곳에 키보드로 자유롭게 식이나 풀이 메모를 입력하세요...\n(예: 1번 문항 350 * 1.15 = 402.5)")
                    .font(.system(size: viewModel.fontSize, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .lineSpacing(6)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 17)
                    .allowsHitTesting(false)
            }
        }
    }
}
