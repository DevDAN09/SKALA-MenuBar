import SwiftUI

public enum MainMenuTab: CaseIterable {
    case bus, cafeteria

    var title: String {
        switch self {
        case .bus: return "버스"
        case .cafeteria: return "식당"
        }
    }
}

@MainActor
public struct MainContainerView: View {
    @ObservedObject var busViewModel: BusViewModel
    @ObservedObject var cafeteriaViewModel: CafeteriaViewModel
    @State private var selectedTab: MainMenuTab = .bus

    public init(
        busViewModel: BusViewModel,
        cafeteriaViewModel: CafeteriaViewModel
    ) {
        self.busViewModel = busViewModel
        self.cafeteriaViewModel = cafeteriaViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(MainMenuTab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            if tab == .bus {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 13))
                            } else {
                                Text("🍱")
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

            switch selectedTab {
            case .bus:
                BusStatusMenuView(viewModel: busViewModel)
            case .cafeteria:
                CafeteriaMenuView(viewModel: cafeteriaViewModel)
                    .frame(width: 320)
            }
        }
        .frame(width: 320)
        .task {
            async let busTask: () = busViewModel.refresh()
            async let cafeTask: () = cafeteriaViewModel.refresh()
            _ = await (busTask, cafeTask)
        }
    }
}
