import Foundation
import AppKit

public final class UpdateService: @unchecked Sendable {
    public static let shared = UpdateService()

    private let session: URLSession
    public static let defaultCurrentVersion = "1.3.0"
    private let latestReleaseUrl = "https://api.github.com/repos/DevDAN09/SKALA-MenuBar/releases/latest"
    private let defaultPkgFallbackUrl = "https://github.com/DevDAN09/SKALA-MenuBar/releases/latest/download/SKALA-MenuBar.pkg"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var currentVersion: String {
        if let bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !bundleVer.isEmpty {
            return bundleVer
        }
        return Self.defaultCurrentVersion
    }

    public func checkForUpdate() async throws -> UpdateInfo? {
        guard let url = URL(string: latestReleaseUrl) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("SKALA-MenuBar-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        let remoteVersion = VersionComparator.clean(release.tag_name)

        guard VersionComparator.isNewer(remote: remoteVersion, current: currentVersion) else {
            return nil
        }

        let pkgAsset = release.assets.first(where: { $0.name.hasSuffix(".pkg") })
        let pkgUrl = pkgAsset?.browser_download_url ?? defaultPkgFallbackUrl

        return UpdateInfo(
            version: remoteVersion,
            title: release.name ?? "v\(remoteVersion)",
            releaseNotes: release.body ?? "",
            pkgDownloadUrl: pkgUrl,
            releaseWebUrl: release.html_url
        )
    }

    public func downloadInstaller(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (tempLocation, response) = try await session.download(from: url)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let destination = URL(fileURLWithPath: "/tmp/SKALA-MenuBar.pkg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempLocation, to: destination)

        // Clear quarantine attribute so Gatekeeper won't block the downloaded package
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", destination.path]
        try? process.run()
        process.waitUntilExit()

        return destination
    }

    @MainActor
    public func launchInstaller(at pkgUrl: URL) -> Bool {
        return NSWorkspace.shared.open(pkgUrl)
    }
}
