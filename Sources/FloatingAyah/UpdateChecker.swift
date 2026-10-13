import AppKit
import Foundation

/// Compares the running version with the latest GitHub release. It only reports; installing
/// stays with the user, through the release page or the command-line installer.
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/utsmannn/floating-ayah/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/utsmannn/floating-ayah/releases/latest")!
    static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var state: State = .idle
    /// Nil for unbundled builds such as `swift run` and tests, which never check automatically.
    let currentVersion: String?
    private let fetch: () async throws -> Data
    private var timer: Timer?

    init(currentVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
         fetch: (() async throws -> Data)? = nil) {
        self.currentVersion = currentVersion
        self.fetch = fetch ?? {
            var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return data
        }
    }

    /// Checks shortly after launch, then once a day while the app keeps running.
    func startAutomaticChecks() {
        guard currentVersion != nil, timer == nil else { return }
        Task { await check() }
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func check() async {
        guard let currentVersion, state != .checking else { return }
        state = .checking
        do {
            let release = try JSONDecoder().decode(Release.self, from: try await fetch())
            let latest = Self.normalized(release.tagName)
            state = Self.isNewer(latest, than: currentVersion)
                ? .available(version: latest, url: release.htmlURL) : .upToDate
        } catch {
            state = .failed
        }
    }

    func openReleasePage() {
        if case .available(_, let url) = state {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(Self.releasesPage)
        }
    }

    nonisolated static func normalized(_ tag: String) -> String {
        tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
    }

    /// Numeric, component-wise comparison: 0.1.10 is newer than 0.1.9, and 0.2 equals 0.2.0.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = components(candidate), rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    nonisolated private static func components(_ version: String) -> [Int] {
        normalized(version).split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}

extension UpdateChecker {
    var hasUpdate: Bool {
        if case .available = state { return true }
        return false
    }
}
