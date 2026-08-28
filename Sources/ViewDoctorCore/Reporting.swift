import Foundation

public enum ReportFormat: String, Sendable {
    case text
    case json
    case agent
    case sarif
}

public enum Reporter {
    public static func render(_ report: ScanReport, format: ReportFormat) throws -> String {
        switch format {
        case .sarif:
            return try renderSARIF(report)
        case .agent:
            return try renderAgent(report)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(report), as: UTF8.self)
        case .text:
            var lines = report.findings.map { finding in
                let module = finding.module.map { " [\($0)]" } ?? ""
                return "\(finding.file):\(finding.location.line):\(finding.location.column): \(finding.severity.rawValue): \(finding.ruleID)\(module): \(finding.message)"
            }
            lines.append("ViewDoctor: \(report.findings.count) finding(s) in \(report.scannedFileCount) file(s), \(report.modules.count) module(s).")
            return lines.joined(separator: "\n")
        }
    }

    private static func renderAgent(_ report: ScanReport) throws -> String {
        let payload = AgentScanReport(
            schemaVersion: 1,
            filesScanned: report.scannedFileCount,
            modulesScanned: report.modules.count,
            graph: report.moduleGraph,
            findings: report.findings.map(AgentFinding.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    private static func renderSARIF(_ report: ScanReport) throws -> String {
        let rules = Dictionary(grouping: report.findings, by: \.ruleID).keys.sorted().map { id in
            ["id": id, "name": id, "shortDescription": ["text": "ViewDoctor \(id) finding"]] as [String: Any]
        }
        let results = report.findings.map { finding in
            [
                "ruleId": finding.ruleID,
                "level": finding.severity == .error ? "error" : finding.severity == .warning ? "warning" : "note",
                "message": ["text": "\(finding.message) \(finding.remediation)"],
                "locations": [["physicalLocation": [
                    "artifactLocation": ["uri": finding.file],
                    "region": ["startLine": finding.location.line, "startColumn": finding.location.column],
                ]]],
                "properties": finding.module.map { ["module": $0] } ?? [:],
            ] as [String: Any]
        }
        let payload: [String: Any] = [
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "version": "2.1.0",
            "runs": [[
                "tool": ["driver": ["name": "ViewDoctor", "informationUri": "https://github.com/KamnevVladimir/ViewDoctor", "rules": rules]],
                "results": results,
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}

private struct AgentScanReport: Encodable {
    let schemaVersion: Int
    let filesScanned: Int
    let modulesScanned: Int
    let graph: ModuleGraphSummary
    let findings: [AgentFinding]
}

private struct AgentFinding: Encodable {
    let rule: String
    let severity: Severity
    let path: String
    let line: Int
    let column: Int
    let module: String?
    let message: String
    let fix: String

    init(_ finding: Finding) {
        rule = finding.ruleID
        severity = finding.severity
        path = finding.file
        line = finding.location.line
        column = finding.location.column
        module = finding.module
        message = finding.message
        fix = finding.remediation
    }
}
