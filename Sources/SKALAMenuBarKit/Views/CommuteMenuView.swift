import SwiftUI

public struct CommuteMenuView: View {
    @ObservedObject var viewModel: CommuteViewModel

    public init(viewModel: CommuteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Network Status Card
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isInternalNetwork ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                if viewModel.isCheckingNetwork {
                    Text("네트워크 확인 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if viewModel.isInternalNetwork {
                    Text("skaxedu 사내망 연결됨")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text("사내 Wi-Fi(skaxedu) 연결 권장")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)

            // 2. KST Clock & Check-out Status Card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("한국 표준시 (KST)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentTimeString)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Text("퇴실(퇴근) 가능 기준")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.isCheckOutAllowed {
                        Text("지금 퇴실 가능 🟢")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else if let countdown = viewModel.countdownString {
                        Text("17:50 (\(countdown))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)

            // 3. Action Buttons
            HStack(spacing: 8) {
                // Check-in Button
                Button {
                    viewModel.triggerCheckIn()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                        Text("입실하기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Check-out Button
                Button {
                    viewModel.triggerCheckOut()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk.departure")
                        Text("퇴실하기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.isCheckOutAllowed ? Color.accentColor : Color.secondary.opacity(0.18))
                    .foregroundColor(viewModel.isCheckOutAllowed ? .white : .secondary.opacity(0.6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isCheckOutAllowed)
            }

            // 4. Notification Footer Info
            HStack(spacing: 6) {
                if viewModel.isNotificationAuthorized {
                    Image(systemName: "bell.badge.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("평일 08:50 / 17:50 알림 활성화됨")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "bell.slash")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("평일 알림 미등록")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    } label: {
                        Text("알림 켜기")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 320)
        .task {
            await viewModel.refresh()
        }
    }
}
