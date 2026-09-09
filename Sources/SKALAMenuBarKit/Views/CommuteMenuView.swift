import SwiftUI

public struct CommuteMenuView: View {
    @ObservedObject var viewModel: CommuteViewModel

    public init(viewModel: CommuteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    // 1. KST Clock Card
                    HStack {
                        Label("한국 표준시 (KST)", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.currentTimeString)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.registerDeveloperModeClick()
                    }

                    // 2. Tabling Spaces Shortcut Button
                    Button {
                        if let url = URL(string: "https://tabling.skala-ai.com/spaces") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chair.lounge.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.accentColor)
                            Text("공간 예약 바로가기 (Tabling)")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 2)

                    // 3. Notification Switch (Toggle)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isReminderEnabled && viewModel.isNotificationAuthorized ? "bell.badge.fill" : "bell.slash")
                                .font(.caption)
                                .foregroundColor(viewModel.isReminderEnabled && viewModel.isNotificationAuthorized ? .green : .secondary)

                            Text("평일 출퇴근 알림 (08:50 / 17:50)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        Toggle("", isOn: $viewModel.isReminderEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                    }
                    .padding(.vertical, 2)

                    // 3-1. Notification Permission Notice Banner (토글 상태와 무관하게 권한 미허용 시 상시 표시)
                    if !viewModel.isNotificationAuthorized {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("시스템 알림 권한 필요")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("설정에서 알림을 허용해야 출퇴근 알림을 받을 수 있습니다.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("설정 열기") {
                                viewModel.openSystemNotificationSettings()
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    // 4. Developer Mode Section (Webview Commute Features)
                    if viewModel.isDeveloperModeEnabled {
                        Divider()
                            .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 10) {
                            // Dev Mode Header Banner
                            HStack {
                                Label("개발자 모드 (출퇴근 웹뷰)", systemImage: "hammer.fill")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                Spacer()
                                Button {
                                    viewModel.isDeveloperModeEnabled = false
                                } label: {
                                    Text("끄기")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(6)

                            // Network Status Card
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

                            // Check-out Status Gating Card
                            HStack {
                                Text("퇴실(퇴근) 가능 기준")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if viewModel.isCheckOutAllowed {
                                    Text("지금 퇴실 가능 🟢")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                } else if let countdown = viewModel.countdownString {
                                    Text("17:50 (\(countdown))")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 4)

                            // Action Buttons: [🏢 입실하기] & [👋 퇴실하기]
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.triggerCheckIn()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "building.2.fill")
                                        Text("입실하기")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.triggerCheckOut()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "figure.walk.departure")
                                        Text("퇴실하기")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(viewModel.isCheckOutAllowed ? Color.accentColor : Color.secondary.opacity(0.18))
                                    .foregroundColor(viewModel.isCheckOutAllowed ? .white : .secondary.opacity(0.6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.isCheckOutAllowed)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            // Footer
            HStack {
                Text("SKALA MenuBar")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .task {
            await viewModel.updateNotificationStatus()
            if viewModel.isDeveloperModeEnabled {
                await viewModel.refresh()
            }
        }
    }
}
