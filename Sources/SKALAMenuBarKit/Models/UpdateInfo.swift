import Foundation

public struct GitHubAsset: Codable, Sendable, Equatable {
    public let name: String
    public let browser_download_url: String

    public init(name: String, browser_download_url: String) {
        self.name = name
        self.browser_download_url = browser_download_url
    }
}

public struct GitHubReleaseResponse: Codable, Sendable, Equatable {
    public let tag_name: String
    public let name: String?
    public let body: String?
    public let html_url: String
    public let assets: [GitHubAsset]

    public init(
        tag_name: String,
        name: String?,
        body: String?,
        html_url: String,
        assets: [GitHubAsset]
    ) {
        self.tag_name = tag_name
        self.name = name
        self.body = body
        self.html_url = html_url
        self.assets = assets
    }
}

public struct UpdateInfo: Identifiable, Equatable, Sendable, Codable {
    public var id: String { version }
    public let version: String
    public let title: String
    public let releaseNotes: String
    public let pkgDownloadUrl: String
    public let releaseWebUrl: String

    public init(
        version: String,
        title: String,
        releaseNotes: String,
        pkgDownloadUrl: String,
        releaseWebUrl: String
    ) {
        self.version = version
        self.title = title
        self.releaseNotes = releaseNotes
        self.pkgDownloadUrl = pkgDownloadUrl
        self.releaseWebUrl = releaseWebUrl
    }
}

public enum VersionComparator {
    public static func clean(_ version: String) -> String {
        var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.lowercased().hasPrefix("v") {
            v.removeFirst()
        }
        return v
    }

    /// Returns true if `remote` is strictly newer than `current`.
    public static func isNewer(remote: String, current: String) -> Bool {
        let remoteParts = clean(remote).split(separator: ".").compactMap { Int($0) }
        let currentParts = clean(current).split(separator: ".").compactMap { Int($0) }

        let maxCount = max(remoteParts.count, currentParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}
