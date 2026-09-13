import SwiftUI

public struct UpdateBannerView: View {
    @ObservedObject var viewModel: UpdateViewModel

    public init(viewModel: UpdateViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if let update = viewModel.availableUpdate, !viewModel.isDismissed {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("새 버전 v\(update.version) 출시")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text("클릭하여 세부 내역 확인")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    viewModel.showUpdateModal = true
                } label: {
                    Text("업데이트")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if let resultMsg = viewModel.manualCheckResult {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(resultMsg)
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    viewModel.manualCheckResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }
}

public struct UpdateModalView: View {
    @ObservedObject var viewModel: UpdateViewModel

    public init(viewModel: UpdateViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if let update = viewModel.availableUpdate {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("새로운 업데이트 사용 가능")
                            .font(.headline)
                        Text("현재: \(viewModel.currentVersionString) ➔ 최신: v\(update.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // Release Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("📋 주요 업데이트 내역:")
                        .font(.caption)
                        .fontWeight(.bold)

                    ScrollView(.vertical, showsIndicators: true) {
                        Text(update.releaseNotes.isEmpty ? "새로운 기능 및 버그 수정이 포함되어 있습니다." : update.releaseNotes)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 110)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(6)
                }

                if let err = viewModel.downloadErrorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Divider()

                // Action Buttons
                VStack(spacing: 6) {
                    if viewModel.isDownloading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("최신 패키지 다운로드 및 준비 중...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            Task {
                                await viewModel.downloadAndInstall()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("지금 설치 (자동 다운로드)")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 8) {
                            Button {
                                viewModel.openReleaseWebPage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("웹에서 받기")
                                }
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.showUpdateModal = false
                            } label: {
                                Text("나중에")
                                    .font(.caption2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.1))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.skipThisVersion()
                            } label: {
                                Text("건너뛰기")
                                    .font(.caption2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.1))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .padding(10)
            .shadow(radius: 6)
        }
    }
}
