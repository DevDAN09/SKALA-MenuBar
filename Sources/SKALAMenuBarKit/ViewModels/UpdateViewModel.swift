import Foundation
import Combine
import AppKit

@MainActor
public final class UpdateViewModel: ObservableObject {
    public static let skippedVersionKey = "SKALAMenuBar_SkippedUpdateVersion"
    public static let lastCheckedDateKey = "SKALAMenuBar_LastUpdateCheckDate"

    @Published public var availableUpdate: UpdateInfo?
    @Published public var isChecking: Bool = false
    @Published public var isDownloading: Bool = false
    @Published public var downloadErrorMessage: String?
    @Published public var isDismissed: Bool = false
    @Published public var showUpdateModal: Bool = false
    @Published public var manualCheckResult: String?

    private let service: UpdateService

    public init(service: UpdateService = .shared) {
        self.service = service
    }

    public var currentVersionString: String {
        "v\(service.currentVersion)"
    }

    public func checkForUpdates(manual: Bool = false) async {
        if !manual {
            // Check throttle (once every 4 hours)
            if let lastDate = UserDefaults.standard.object(forKey: Self.lastCheckedDateKey) as? Date {
                if Date().timeIntervalSince(lastDate) < 14400 {
                    return
                }
            }
        }

        isChecking = true
        downloadErrorMessage = nil
        manualCheckResult = nil

        do {
            let update = try await service.checkForUpdate()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckedDateKey)

            if let update = update {
                let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey)
                if !manual && skipped == update.version {
                    // User opted to skip this version
                    self.availableUpdate = nil
                } else {
                    self.availableUpdate = update
                    self.isDismissed = false
                    if manual {
                        self.showUpdateModal = true
                    }
                }
            } else {
                self.availableUpdate = nil
                if manual {
                    self.manualCheckResult = "현재 최신 버전(\(currentVersionString))을 사용 중입니다."
                }
            }
        } catch {
            if manual {
                self.manualCheckResult = "업데이트 확인 실패: \(error.localizedDescription)"
            }
        }

        isChecking = false
    }

    public func downloadAndInstall() async {
        guard let update = availableUpdate else { return }
        isDownloading = true
        downloadErrorMessage = nil

        do {
            let pkgUrl = try await service.downloadInstaller(from: update.pkgDownloadUrl)
            _ = service.launchInstaller(at: pkgUrl)
            self.showUpdateModal = false
            self.isDismissed = true
        } catch {
            self.downloadErrorMessage = "다운로드 실패: \(error.localizedDescription)"
        }

        isDownloading = false
    }

    public func openReleaseWebPage() {
        if let urlStr = availableUpdate?.releaseWebUrl, let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

    public func dismissBanner() {
        self.isDismissed = true
    }

    public func skipThisVersion() {
        if let update = availableUpdate {
            UserDefaults.standard.set(update.version, forKey: Self.skippedVersionKey)
        }
        self.isDismissed = true
        self.showUpdateModal = false
    }
}
