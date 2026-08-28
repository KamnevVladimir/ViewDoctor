import Foundation

public struct ScanConfiguration: Codable, Equatable, Sendable {
    public var excludedPaths: [String]
    public var disabledRules: Set<String>
    public var minimumSeverity: Severity
    public var maxFindings: Int

    public static let `default` = ScanConfiguration(
        excludedPaths: [],
        disabledRules: [],
        minimumSeverity: .note,
        maxFindings: 200
    )

    public init(
        excludedPaths: [String],
        disabledRules: Set<String>,
        minimumSeverity: Severity,
        maxFindings: Int
    ) {
        self.excludedPaths = excludedPaths
        self.disabledRules = disabledRules
        self.minimumSeverity = minimumSeverity
        self.maxFindings = max(1, maxFindings)
    }

    public static func load(root: URL) throws -> ScanConfiguration {
        let url = root.appending(path: ".viewdoctor.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return .default }
        return try JSONDecoder().decode(ScanConfiguration.self, from: Data(contentsOf: url))
    }

    public func includes(path: String) -> Bool {
        !excludedPaths.contains { excluded in
            let normalized = excluded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path == normalized || path.hasPrefix(normalized + "/")
        }
    }
}

