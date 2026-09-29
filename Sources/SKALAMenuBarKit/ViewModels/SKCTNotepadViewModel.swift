import SwiftUI
import Combine

@MainActor
public final class SKCTNotepadViewModel: ObservableObject {
    @Published public var text: String = ""
    @Published public var fontSize: CGFloat = 15.0

    public init(text: String = "", fontSize: CGFloat = 15.0) {
        self.text = text
        self.fontSize = fontSize
    }

    public var charCount: Int {
        text.count
    }

    public func clear() {
        text = ""
    }

    public func setFontSize(_ size: CGFloat) {
        fontSize = size
    }
}
