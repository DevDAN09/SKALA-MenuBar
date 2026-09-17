import SwiftUI

public struct SKCTWhiteboardView: View {
    @ObservedObject var viewModel: SKCTDrawingViewModel
    @State private var isDragging = false

    public init(viewModel: SKCTDrawingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            toolbarView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Divider(), alignment: .bottom
                )

            // Drawing Canvas
            GeometryReader { geometry in
                ZStack {
                    // Whiteboard background (Clean white / dark mode aware canvas with subtle dot grid)
                    Color(nsColor: .textBackgroundColor)
                        .edgesIgnoringSafeArea(.all)

                    GridBackgroundPattern()
                        .opacity(0.12)

                    Canvas { context, size in
                        // 1. Render all committed strokes
                        for stroke in viewModel.strokes {
                            var path = Path()
                            guard let first = stroke.points.first else { continue }
                            path.move(to: first)
                            for pt in stroke.points.dropFirst() {
                                path.addLine(to: pt)
                            }
                            context.stroke(
                                path,
                                with: .color(stroke.color),
                                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }

                        // 2. Render current dragging stroke
                        if let active = viewModel.currentStroke {
                            var path = Path()
                            if let first = active.points.first {
                                path.move(to: first)
                                for pt in active.points.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                context.stroke(
                                    path,
                                    with: .color(active.color),
                                    style: StrokeStyle(lineWidth: active.lineWidth, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }

                        // 3. Eraser cursor ring guide
                        if viewModel.activeTool == .eraser, let mouseLoc = viewModel.currentMouseLocation {
                            let r = viewModel.eraserRadius
                            let rect = CGRect(x: mouseLoc.x - r, y: mouseLoc.y - r, width: r * 2, height: r * 2)
                            let ringPath = Path(ellipseIn: rect)
                            context.stroke(
                                ringPath,
                                with: .color(.secondary),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    viewModel.startStroke(at: value.location)
                                } else {
                                    viewModel.continueStroke(to: value.location)
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                viewModel.finishStroke()
                            }
                    )
                }
            }
        }
    }

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 1. Tool Selection (Pen / Eraser)
            HStack(spacing: 2) {
                toolButton(title: "펜", icon: "pencil.tip", tool: .pen)
                toolButton(title: "지우개", icon: "eraser.fill", tool: .eraser)
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(2)

            Divider()
                .frame(height: 20)

            // 2. Colors (only for pen)
            HStack(spacing: 6) {
                colorCircle(.primary, name: "기본")
                colorCircle(.blue, name: "파랑")
                colorCircle(.red, name: "빨강")
            }
            .opacity(viewModel.activeTool == .pen ? 1.0 : 0.4)
            .disabled(viewModel.activeTool != .pen)

            Divider()
                .frame(height: 20)

            // 3. Line Widths
            HStack(spacing: 6) {
                widthButton(width: 1.5, label: "얇게")
                widthButton(width: 2.5, label: "보통")
                widthButton(width: 4.5, label: "굵게")
            }
            .opacity(viewModel.activeTool == .pen ? 1.0 : 0.4)
            .disabled(viewModel.activeTool != .pen)

            Spacer()

            // 4. History (Undo / Redo)
            HStack(spacing: 4) {
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1.0 : 0.4)
                .help("실행 취소 (⌘Z)")

                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRedo)
                .opacity(viewModel.canRedo ? 1.0 : 0.4)
                .help("다시 실행 (⇧⌘Z)")
            }

            Divider()
                .frame(height: 20)

            // 5. Clear All Button (메모장 전체 지우기)
            Button {
                viewModel.clearAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                    Text("전체 지우기")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.strokes.isEmpty)
            .opacity(viewModel.strokes.isEmpty ? 0.4 : 1.0)
            .help("화이트보드 모든 메모 초기화")
        }
    }

    private func toolButton(title: String, icon: String, tool: WhiteboardTool) -> some View {
        let isSelected = viewModel.activeTool == tool
        return Button {
            viewModel.activeTool = tool
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func colorCircle(_ color: Color, name: String) -> some View {
        let isSelected = viewModel.selectedColor == color
        return Button {
            viewModel.selectedColor = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 2 : 0)
                )
                .padding(2)
        }
        .buttonStyle(.plain)
        .help("\(name) 색상")
    }

    private func widthButton(width: CGFloat, label: String) -> some View {
        let isSelected = viewModel.selectedLineWidth == width
        return Button {
            viewModel.selectedLineWidth = width
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// Background grid pattern to emulate paper/memo board
struct GridBackgroundPattern: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24.0
            var x: CGFloat = step
            while x < size.width {
                var y: CGFloat = step
                while y < size.height {
                    let rect = CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(.primary))
                    y += step
                }
                x += step
            }
        }
    }
}
