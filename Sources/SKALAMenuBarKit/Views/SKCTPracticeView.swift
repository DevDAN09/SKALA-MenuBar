import SwiftUI

public struct SKCTPracticeView: View {
    @StateObject private var drawingViewModel = SKCTDrawingViewModel()
    @StateObject private var notepadViewModel = SKCTNotepadViewModel()
    @StateObject private var timerViewModel = SKCTTimerViewModel()
    @State private var activeMode: SKCTMode = .notepad

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // 2-Tier Header Structure
                twoTierHeaderView

                // Workspace Content Area (Notepad or Whiteboard Canvas)
                Group {
                    if activeMode == .notepad {
                        SKCTNotepadView(viewModel: notepadViewModel)
                    } else {
                        SKCTWhiteboardCanvasView(viewModel: drawingViewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Top-Right Floating Calculator Panel (Adjusted top padding for 2-tier toolbar)
            SKCTCalculatorView()
                .padding(.top, 88)
                .padding(.trailing, 16)
        }
        .frame(minWidth: 800, minHeight: 550)
        .onChange(of: activeMode) { newMode in
            if newMode == .whiteboard {
                NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    // MARK: - 2-Tier Header
    private var twoTierHeaderView: some View {
        VStack(spacing: 0) {
            // Tier 1: Mode Tabs (Left) & Timer Widget (Right)
            HStack(spacing: 12) {
                modeTabsView

                Spacer()

                timerWidgetView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tier 2: Sub-toolbar for current active mode
            HStack(spacing: 12) {
                if activeMode == .notepad {
                    notepadToolsView
                    Spacer()
                    notepadActionView
                } else {
                    whiteboardToolsView
                    Spacer()
                    whiteboardActionView
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()
        }
    }

    // MARK: - Tier 1: Mode Tabs
    private var modeTabsView: some View {
        HStack(spacing: 2) {
            modeTabButton(mode: .notepad, title: "메모장", icon: "note.text")
            modeTabButton(mode: .whiteboard, title: "화이트보드", icon: "pencil.tip")
        }
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(8)
        .padding(2)
    }

    private func modeTabButton(mode: SKCTMode, title: String, icon: String) -> some View {
        let isSelected = activeMode == mode
        return Button {
            activeMode = mode
            if mode == .whiteboard {
                NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help("\(title) 모드로 전환")
    }

    // MARK: - Tier 2: Notepad Controls
    private var notepadToolsView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("글자 크기")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 2)
                fontSizeButton(size: 13, label: "작게")
                fontSizeButton(size: 15, label: "보통")
                fontSizeButton(size: 18, label: "크게")
            }

            Divider()
                .frame(height: 16)

            HStack(spacing: 4) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(notepadViewModel.charCount)자")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var notepadActionView: some View {
        Button {
            notepadViewModel.clear()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                Text("메모 비우기")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.12))
            .foregroundColor(.red)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(notepadViewModel.text.isEmpty)
        .opacity(notepadViewModel.text.isEmpty ? 0.4 : 1.0)
        .help("작성 중인 메모 텍스트 초기화")
    }

    private func fontSizeButton(size: CGFloat, label: String) -> some View {
        let isSelected = notepadViewModel.fontSize == size
        return Button {
            notepadViewModel.setFontSize(size)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier 2: Whiteboard Controls
    private var whiteboardToolsView: some View {
        HStack(spacing: 12) {
            // Pen / Eraser
            HStack(spacing: 2) {
                wbToolButton(title: "펜", icon: "pencil.tip", tool: .pen)
                wbToolButton(title: "지우개", icon: "eraser.fill", tool: .eraser)
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(7)
            .padding(2)

            Divider()
                .frame(height: 18)

            // Colors
            HStack(spacing: 6) {
                wbColorCircle(.primary, name: "기본")
                wbColorCircle(.blue, name: "파랑")
                wbColorCircle(.red, name: "빨강")
            }
            .opacity(drawingViewModel.activeTool == .pen ? 1.0 : 0.4)
            .disabled(drawingViewModel.activeTool != .pen)

            Divider()
                .frame(height: 18)

            // Line Widths
            HStack(spacing: 6) {
                wbWidthButton(width: 1.5, label: "얇게")
                wbWidthButton(width: 2.5, label: "보통")
                wbWidthButton(width: 4.5, label: "굵게")
            }
            .opacity(drawingViewModel.activeTool == .pen ? 1.0 : 0.4)
            .disabled(drawingViewModel.activeTool != .pen)
        }
    }

    private var whiteboardActionView: some View {
        HStack(spacing: 8) {
            // History (Undo / Redo)
            HStack(spacing: 4) {
                Button {
                    drawingViewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(5)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!drawingViewModel.canUndo)
                .opacity(drawingViewModel.canUndo ? 1.0 : 0.4)
                .help("실행 취소 (⌘Z)")

                Button {
                    drawingViewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(5)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!drawingViewModel.canRedo)
                .opacity(drawingViewModel.canRedo ? 1.0 : 0.4)
                .help("다시 실행 (⇧⌘Z)")
            }

            Divider()
                .frame(height: 18)

            // Whiteboard Clear All Button
            Button {
                drawingViewModel.clearAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                    Text("전체 지우기")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(drawingViewModel.strokes.isEmpty)
            .opacity(drawingViewModel.strokes.isEmpty ? 0.4 : 1.0)
            .help("화이트보드 모든 필기 초기화")
        }
    }

    private func wbToolButton(title: String, icon: String, tool: WhiteboardTool) -> some View {
        let isSelected = drawingViewModel.activeTool == tool
        return Button {
            drawingViewModel.activeTool = tool
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func wbColorCircle(_ color: Color, name: String) -> some View {
        let isSelected = drawingViewModel.selectedColor == color
        return Button {
            drawingViewModel.selectedColor = color
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

    private func wbWidthButton(width: CGFloat, label: String) -> some View {
        let isSelected = drawingViewModel.selectedLineWidth == width
        return Button {
            drawingViewModel.selectedLineWidth = width
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

    // MARK: - Timer Widget
    private var timerWidgetView: some View {
        HStack(spacing: 6) {
            Image(systemName: timerViewModel.isCountdown ? "timer" : "stopwatch")
                .font(.system(size: 11))
                .foregroundColor(timerViewModel.isFinished ? .red : (timerViewModel.isRunning ? .green : .accentColor))

            Text(timerViewModel.timeString)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(timerViewModel.isFinished ? .red : .primary)

            // Start / Pause button
            Button {
                timerViewModel.toggle()
            } label: {
                Image(systemName: timerViewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(timerViewModel.isRunning ? Color.orange : Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(timerViewModel.isRunning ? "일시정지" : "시작")

            // Reset button
            Button {
                timerViewModel.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("타이머 초기화")

            // Preset and Adjustment buttons (when not running)
            if !timerViewModel.isRunning {
                HStack(spacing: 3) {
                    Button("45초") {
                        timerViewModel.setPreset(seconds: 45)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                    .help("문항당 45초 카운트다운 프리셋")

                    Button("+15분") {
                        timerViewModel.addMinutes(15)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                    Button("+1분") {
                        timerViewModel.addMinutes(1)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                    Button("+10초") {
                        timerViewModel.addSeconds(10)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                    if timerViewModel.totalSeconds > 0 {
                        Button("-1분") {
                            timerViewModel.addMinutes(-1)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }

            if timerViewModel.isFinished {
                Text("종료!")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(timerViewModel.isFinished ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }
}
