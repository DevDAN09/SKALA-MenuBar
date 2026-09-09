import SwiftUI

public enum MainMenuTab: CaseIterable {
    case bus, cafeteria, commute

    public var title: String {
        switch self {
        case .bus: return "버스"
        case .cafeteria: return "식당"
        case .commute: return "출퇴근"
        }
    }
}

@MainActor
public struct MainContainerView: View {
    @ObservedObject var busViewModel: BusViewModel
    @ObservedObject var cafeteriaViewModel: CafeteriaViewModel
    @ObservedObject var commuteViewModel: CommuteViewModel
    @State private var selectedTab: MainMenuTab = .bus

    public init(
        busViewModel: BusViewModel,
        cafeteriaViewModel: CafeteriaViewModel,
        commuteViewModel: CommuteViewModel
    ) {
        self.busViewModel = busViewModel
        self.cafeteriaViewModel = cafeteriaViewModel
        self.commuteViewModel = commuteViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(MainMenuTab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        selectedTab = tab
                        if tab == .commute {
                            commuteViewModel.registerDeveloperModeClick()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            switch tab {
                            case .bus:
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 13))
                            case .cafeteria:
                                Text("🍱")
                                    .font(.system(size: 13))
                            case .commute:
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 13))
                            }
                            Text(tab.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                switch selectedTab {
                case .bus:
                    BusStatusMenuView(viewModel: busViewModel)
                case .cafeteria:
                    CafeteriaMenuView(viewModel: cafeteriaViewModel)
                case .commute:
                    CommuteMenuView(viewModel: commuteViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 320, height: 560)
        .background(WindowAnchorHelper())
        .task {
            async let busTask: () = busViewModel.refresh()
            async let cafeTask: () = cafeteriaViewModel.refresh()
            async let commuteTask: () = commuteViewModel.refresh()
            _ = await (busTask, cafeTask, commuteTask)
        }
    }
}

public struct WindowAnchorHelper: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        WindowAnchorNSView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowAnchorNSView: NSView {
    private var anchorTopY: CGFloat?
    private var isRepositioning = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window else { return }
        updateAnchor(for: window)

        NotificationCenter.default.removeObserver(self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }

    private func updateAnchor(for window: NSWindow) {
        anchorTopY = window.frame.maxY
    }

    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard let window = self.window else { return }
        updateAnchor(for: window)
    }

    @objc private func handleWindowDidResize(_ notification: Notification) {
        guard !isRepositioning, let window = self.window, let topY = anchorTopY else { return }
        let currentFrame = window.frame
        if abs(currentFrame.maxY - topY) > 1.0 {
            isRepositioning = true
            var newFrame = currentFrame
            newFrame.origin.y = topY - currentFrame.height
            window.setFrame(newFrame, display: true, animate: false)
            isRepositioning = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
