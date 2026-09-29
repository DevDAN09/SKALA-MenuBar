import SwiftUI
import AppKit

public struct SKCTCalculatorView: View {
    @State private var engine = SKCTCalculatorEngine()
    @State private var isFolded = false
    @State private var keyMonitor: Any? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "candybarphone")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("CBT 계산기")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFolded.toggle()
                    }
                } label: {
                    Image(systemName: isFolded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, isFolded ? 8 : 0)

            if !isFolded {
                // LCD Display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(engine.expressionText.isEmpty ? " " : engine.expressionText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(engine.displayText)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

                // Keypad Buttons
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        calcButton("C", color: .orange, action: { engine.clear() })
                        calcButton("⌫", color: .secondary, action: { engine.backspace() })
                        calcButton("%", color: .secondary, action: { engine.applyPercent() })
                        calcButton("÷", isOp: true, action: { engine.inputOperation(.divide) })
                    }
                    HStack(spacing: 4) {
                        calcButton("7", action: { engine.inputDigit("7") })
                        calcButton("8", action: { engine.inputDigit("8") })
                        calcButton("9", action: { engine.inputDigit("9") })
                        calcButton("×", isOp: true, action: { engine.inputOperation(.multiply) })
                    }
                    HStack(spacing: 4) {
                        calcButton("4", action: { engine.inputDigit("4") })
                        calcButton("5", action: { engine.inputDigit("5") })
                        calcButton("6", action: { engine.inputDigit("6") })
                        calcButton("-", isOp: true, action: { engine.inputOperation(.subtract) })
                    }
                    HStack(spacing: 4) {
                        calcButton("1", action: { engine.inputDigit("1") })
                        calcButton("2", action: { engine.inputDigit("2") })
                        calcButton("3", action: { engine.inputDigit("3") })
                        calcButton("+", isOp: true, action: { engine.inputOperation(.add) })
                    }
                    HStack(spacing: 4) {
                        calcButton("0", action: { engine.inputDigit("0") })
                        calcButton("00", action: { engine.inputDigit("00") })
                        calcButton(".", action: { engine.inputDecimal() })
                        calcButton("=", isEquals: true, action: { engine.calculateEquals() })
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    @ViewBuilder
    private func calcButton(_ label: String, color: Color? = nil, isOp: Bool = false, isEquals: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isEquals || isOp ? .bold : .medium, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(buttonBackground(isOp: isOp, isEquals: isEquals, color: color))
                .foregroundColor(buttonForeground(isOp: isOp, isEquals: isEquals, color: color))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private func buttonBackground(isOp: Bool, isEquals: Bool, color: Color?) -> Color {
        if isEquals {
            return Color.accentColor
        } else if isOp {
            return Color.accentColor.opacity(0.18)
        } else if let c = color {
            return c.opacity(0.15)
        } else {
            return Color.secondary.opacity(0.1)
        }
    }

    private func buttonForeground(isOp: Bool, isEquals: Bool, color: Color?) -> Color {
        if isEquals {
            return .white
        } else if isOp {
            return .accentColor
        } else if let c = color {
            return c
        } else {
            return .primary
        }
    }

    private func setupKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode

            // Check if key is from the dedicated numeric keypad (Numpad)
            let isNumpadKey: Bool
            switch keyCode {
            case 65, 67, 69, 71, 75, 76, 78, 81, 82...89, 91, 92:
                isNumpadKey = true
            default:
                isNumpadKey = false
            }

            // If an editable text responder currently has focus (e.g. SKCTNotepadView):
            // - Numpad keys are routed directly to the CBT Calculator
            // - Normal keyboard keys pass through to the text editor
            if let responder = NSApplication.shared.keyWindow?.firstResponder as? NSTextView, responder.isEditable {
                if !isNumpadKey {
                    return event
                }
            }

            // Direct KeyCode handling (guarantees numpad input regardless of input source/IME)
            switch keyCode {
            case 51: // Delete/Backspace
                engine.backspace()
                return nil
            case 53, 71: // Escape or Keypad Clear
                engine.clear()
                return nil
            case 36, 76, 81: // Return, Keypad Enter, or Keypad Equals
                engine.calculateEquals()
                return nil
            case 65: // Keypad Decimal (.)
                engine.inputDecimal()
                return nil
            case 67: // Keypad Multiply (*)
                engine.inputOperation(.multiply)
                return nil
            case 69: // Keypad Plus (+)
                engine.inputOperation(.add)
                return nil
            case 75: // Keypad Divide (/)
                engine.inputOperation(.divide)
                return nil
            case 78: // Keypad Minus (-)
                engine.inputOperation(.subtract)
                return nil
            case 82: // Keypad 0
                engine.inputDigit("0")
                return nil
            case 83: // Keypad 1
                engine.inputDigit("1")
                return nil
            case 84: // Keypad 2
                engine.inputDigit("2")
                return nil
            case 85: // Keypad 3
                engine.inputDigit("3")
                return nil
            case 86: // Keypad 4
                engine.inputDigit("4")
                return nil
            case 87: // Keypad 5
                engine.inputDigit("5")
                return nil
            case 88: // Keypad 6
                engine.inputDigit("6")
                return nil
            case 89: // Keypad 7
                engine.inputDigit("7")
                return nil
            case 91: // Keypad 8
                engine.inputDigit("8")
                return nil
            case 92: // Keypad 9
                engine.inputDigit("9")
                return nil
            default:
                break
            }

            guard let chars = event.characters else { return event }

            for char in chars {
                switch char {
                case "0"..."9":
                    engine.inputDigit(String(char))
                    return nil
                case "+":
                    engine.inputOperation(.add)
                    return nil
                case "-":
                    engine.inputOperation(.subtract)
                    return nil
                case "*":
                    engine.inputOperation(.multiply)
                    return nil
                case "/":
                    engine.inputOperation(.divide)
                    return nil
                case ".":
                    engine.inputDecimal()
                    return nil
                case "=":
                    engine.calculateEquals()
                    return nil
                case "c", "C":
                    engine.clear()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
