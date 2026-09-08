import SwiftUI
import AppKit

public struct BusStatusMenuView: View {
    @ObservedObject var viewModel: BusViewModel

    public init(viewModel: BusViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedBus.stopName)
                        .font(.headline)
                    Text(viewModel.selectedBus.directionHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Bus Selector Buttons
            HStack(spacing: 6) {
                ForEach(TargetBus.allCases) { bus in
                    let isSelected = viewModel.selectedBus == bus
                    Button {
                        viewModel.selectedBus = bus
                    } label: {
                        VStack(spacing: 2) {
                            Text(bus.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            if let arrival = viewModel.allArrivals[bus], let seconds = arrival.arrivalTime, seconds > 0 {
                                let mins = max(1, Int(ceil(Double(seconds) / 60.0)))
                                Text("\(mins)분")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(mins <= 3 ? .red : (isSelected ? .white : .primary))
                            } else {
                                Text("정보없음")
                                    .font(.system(size: 9))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Selected Bus Heading
            HStack {
                Text(viewModel.selectedBus.displayName)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Text("메뉴바 표시 중")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }

            // 1st Bus Card
            VStack(alignment: .leading, spacing: 4) {
                Label("첫 번째 버스", systemImage: "bus.fill")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Text(viewModel.firstBusText(for: viewModel.selectedBus))
                    .font(.system(.body, design: .rounded))
                    .bold()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // 2nd Bus Card
            VStack(alignment: .leading, spacing: 4) {
                Label("두 번째 버스", systemImage: "bus")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(viewModel.secondBusText(for: viewModel.selectedBus))
                    .font(.system(.body, design: .rounded))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)

            if let error = viewModel.errorMessage {
                Text("오류: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            // Controls & Footer
            HStack {
                Text("마지막 갱신: \(viewModel.lastUpdatedString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("지금 갱신") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // Interval selector & Quit
            HStack {
                Picker("갱신 주기", selection: $viewModel.refreshIntervalSeconds) {
                    Text("15초").tag(15)
                    Text("30초").tag(30)
                    Text("60초").tag(60)
                }
                .pickerStyle(.menu)

                Spacer()

                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
