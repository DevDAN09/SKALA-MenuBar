import Foundation

public struct SKCTCalculatorEngine: Sendable {
    public enum Operation: String, Sendable {
        case add = "+"
        case subtract = "-"
        case multiply = "×"
        case divide = "÷"
    }

    public private(set) var displayText: String = "0"
    public private(set) var expressionText: String = ""

    private var storedValue: Decimal?
    private var pendingOperation: Operation?
    private var isTypingNewNumber: Bool = true
    private var hasError: Bool = false

    public init() {}

    public mutating func inputDigit(_ digit: String) {
        if hasError {
            clear()
        }

        if isTypingNewNumber {
            displayText = digit == "00" ? "0" : digit
            isTypingNewNumber = false
        } else {
            if displayText == "0" {
                displayText = digit == "00" ? "0" : digit
            } else {
                displayText += digit
            }
        }
    }

    public mutating func inputDecimal() {
        if hasError {
            clear()
        }

        if isTypingNewNumber {
            displayText = "0."
            isTypingNewNumber = false
        } else if !displayText.contains(".") {
            displayText += "."
        }
    }

    public mutating func inputOperation(_ op: Operation) {
        if hasError {
            clear()
            return
        }

        if let currentVal = Decimal(string: displayText) {
            if let prevVal = storedValue, let prevOp = pendingOperation, !isTypingNewNumber {
                if let result = execute(op: prevOp, a: prevVal, b: currentVal) {
                    storedValue = result
                    displayText = formatDecimal(result)
                } else {
                    hasError = true
                    displayText = "오류"
                    expressionText = ""
                    storedValue = nil
                    pendingOperation = nil
                    return
                }
            } else {
                storedValue = currentVal
            }
        }

        pendingOperation = op
        isTypingNewNumber = true
        if let stored = storedValue {
            expressionText = "\(formatDecimal(stored)) \(op.rawValue)"
        }
    }

    public mutating func calculateEquals() {
        guard !hasError, let prevVal = storedValue, let op = pendingOperation, let currentVal = Decimal(string: displayText) else {
            return
        }

        if let result = execute(op: op, a: prevVal, b: currentVal) {
            expressionText = "\(formatDecimal(prevVal)) \(op.rawValue) \(formatDecimal(currentVal)) ="
            displayText = formatDecimal(result)
            storedValue = result
            pendingOperation = nil
            isTypingNewNumber = true
        } else {
            hasError = true
            displayText = "오류"
            expressionText = ""
            storedValue = nil
            pendingOperation = nil
            isTypingNewNumber = true
        }
    }

    public mutating func clear() {
        displayText = "0"
        expressionText = ""
        storedValue = nil
        pendingOperation = nil
        isTypingNewNumber = true
        hasError = false
    }

    public mutating func backspace() {
        if hasError || isTypingNewNumber { return }
        if displayText.count > 1 {
            displayText.removeLast()
            if displayText == "-" {
                displayText = "0"
                isTypingNewNumber = true
            }
        } else {
            displayText = "0"
            isTypingNewNumber = true
        }
    }

    public mutating func toggleSign() {
        if hasError { return }
        if let val = Decimal(string: displayText) {
            let negated = -val
            displayText = formatDecimal(negated)
        }
    }

    public mutating func applyPercent() {
        if hasError { return }
        if let val = Decimal(string: displayText) {
            let percentVal = val / 100
            displayText = formatDecimal(percentVal)
        }
    }

    private func execute(op: Operation, a: Decimal, b: Decimal) -> Decimal? {
        switch op {
        case .add:
            return a + b
        case .subtract:
            return a - b
        case .multiply:
            return a * b
        case .divide:
            if b == 0 { return nil }
            return a / b
        }
    }

    private func formatDecimal(_ value: Decimal) -> String {
        // Convert to double or string without trailing fractional zeroes if integer
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
