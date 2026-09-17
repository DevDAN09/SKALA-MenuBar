import SwiftUI
import Combine

public enum WhiteboardTool: Equatable, Sendable {
    case pen
    case eraser
}

public struct DrawingStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var points: [CGPoint]
    public var color: Color
    public var lineWidth: CGFloat

    public init(id: UUID = UUID(), points: [CGPoint] = [], color: Color = .primary, lineWidth: CGFloat = 2.5) {
        self.id = id
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
}

@MainActor
public final class SKCTDrawingViewModel: ObservableObject {
    @Published public var strokes: [DrawingStroke] = []
    @Published public var currentStroke: DrawingStroke? = nil
    @Published public var activeTool: WhiteboardTool = .pen
    @Published public var selectedColor: Color = .primary
    @Published public var selectedLineWidth: CGFloat = 2.5
    @Published public var eraserRadius: CGFloat = 16.0
    @Published public var currentMouseLocation: CGPoint? = nil

    private var undoStack: [[DrawingStroke]] = []
    private var redoStack: [[DrawingStroke]] = []
    private var isErasingGestureActive: Bool = false

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init() {}

    public func startStroke(at point: CGPoint) {
        currentMouseLocation = point
        if activeTool == .pen {
            currentStroke = DrawingStroke(points: [point], color: selectedColor, lineWidth: selectedLineWidth)
        } else {
            // Eraser mode
            if !isErasingGestureActive {
                saveUndoState()
                isErasingGestureActive = true
            }
            eraseStrokes(near: point)
        }
    }

    public func continueStroke(to point: CGPoint) {
        currentMouseLocation = point
        if activeTool == .pen {
            currentStroke?.points.append(point)
        } else {
            eraseStrokes(near: point)
        }
    }

    public func finishStroke() {
        if activeTool == .pen {
            if let stroke = currentStroke, !stroke.points.isEmpty {
                saveUndoState()
                strokes.append(stroke)
            }
            currentStroke = nil
        } else {
            isErasingGestureActive = false
        }
    }

    public func eraseStrokes(near point: CGPoint) {
        let radius = eraserRadius
        let initialCount = strokes.count
        strokes.removeAll { stroke in
            strokeIntersects(stroke: stroke, point: point, radius: radius)
        }
        if strokes.count != initialCount && !isErasingGestureActive {
            // If called standalone (e.g. unit tests)
            redoStack.removeAll()
        }
    }

    public func clearAll() {
        guard !strokes.isEmpty else { return }
        saveUndoState()
        strokes.removeAll()
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(strokes)
        strokes = previous
        currentStroke = nil
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(strokes)
        strokes = next
        currentStroke = nil
    }

    private func saveUndoState() {
        undoStack.append(strokes)
        redoStack.removeAll()
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    private func strokeIntersects(stroke: DrawingStroke, point: CGPoint, radius: CGFloat) -> Bool {
        let threshold = radius + (stroke.lineWidth / 2.0)
        let pts = stroke.points
        if pts.isEmpty { return false }
        if pts.count == 1 {
            let dx = pts[0].x - point.x
            let dy = pts[0].y - point.y
            return sqrt(dx * dx + dy * dy) <= threshold
        }

        for i in 0..<(pts.count - 1) {
            let p1 = pts[i]
            let p2 = pts[i + 1]
            if distanceToSegment(p: point, a: p1, b: p2) <= threshold {
                return true
            }
        }
        return false
    }

    private func distanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 {
            let px = p.x - a.x
            let py = p.y - a.y
            return sqrt(px * px + py * py)
        }

        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        let distDx = p.x - projX
        let distDy = p.y - projY
        return sqrt(distDx * distDx + distDy * distDy)
    }
}
