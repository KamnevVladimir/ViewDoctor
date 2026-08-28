import Foundation

public enum Severity: String, Codable, Sendable, Comparable {
    case note
    case warning
    case error

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        let rank: [Severity: Int] = [.note: 0, .warning: 1, .error: 2]
        return rank[lhs, default: 0] < rank[rhs, default: 0]
    }
}

public struct SourceLocation: Codable, Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct Finding: Codable, Equatable, Sendable {
    public let ruleID: String
    public let severity: Severity
    public let file: String
    public let location: SourceLocation
    public let module: String?
    public let message: String
    public let explanation: String
    public let remediation: String

    public init(
        ruleID: String,
        severity: Severity,
        file: String,
        location: SourceLocation,
        module: String?,
        message: String,
        explanation: String,
        remediation: String
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.file = file
        self.location = location
        self.module = module
        self.message = message
        self.explanation = explanation
        self.remediation = remediation
    }
}

public struct ScanReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let scannedFileCount: Int
    public let modules: [String]
    public let moduleGraph: ModuleGraphSummary
    public let findings: [Finding]

    public init(
        scannedFileCount: Int,
        modules: [String],
        moduleGraph: ModuleGraphSummary = .empty,
        findings: [Finding]
    ) {
        self.schemaVersion = 1
        self.scannedFileCount = scannedFileCount
        self.modules = modules.sorted()
        self.moduleGraph = moduleGraph
        self.findings = findings
    }
}

public struct ModuleGraphSummary: Codable, Equatable, Sendable {
    public let moduleCount: Int
    public let dependencyCount: Int
    public let providers: [String]

    public static let empty = ModuleGraphSummary(moduleCount: 0, dependencyCount: 0, providers: [])

    public init(moduleCount: Int, dependencyCount: Int, providers: [String]) {
        self.moduleCount = moduleCount
        self.dependencyCount = dependencyCount
        self.providers = providers.sorted()
    }
}

public struct SourceFile: Equatable, Sendable {
    public let absoluteURL: URL
    public let relativePath: String
    public let module: String?

    public init(absoluteURL: URL, relativePath: String, module: String?) {
        self.absoluteURL = absoluteURL
        self.relativePath = relativePath
        self.module = module
    }
}
