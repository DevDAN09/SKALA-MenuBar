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
                    Text("SK플래닛·판교디지털센터")
                        .font(.headline)
                    Text("서울역/고속터미널 방면 · 9007번")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Divider()

            // 1st Bus Card
            VStack(alignment: .leading, spacing: 4) {
                Label("첫 번째 버스", systemImage: "bus.fill")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Text(viewModel.firstBusText)
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
                Text(viewModel.secondBusText)
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
