import Foundation

public enum SKCTMode: String, CaseIterable, Identifiable, Sendable {
    case notepad = "메모장"
    case whiteboard = "화이트보드"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .notepad: return "note.text"
        case .whiteboard: return "pencil.tip"
        }
    }
}
