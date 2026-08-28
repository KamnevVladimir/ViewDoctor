import Foundation
import ViewDoctorCore
import ViewDoctorDiscovery
import ViewDoctorGraph
import ViewDoctorRules
import ViewDoctorSyntax

@main
struct ViewDoctorCommand {
    static func main() async {
        do {
            let rawArguments = Array(CommandLine.arguments.dropFirst())
            if rawArguments.contains("--help") || rawArguments.first == "help" {
                print(Self.help)
                Foundation.exit(0)
            }
            if rawArguments.contains("--version") || rawArguments.first == "version" {
                print("ViewDoctor \(ViewDoctorVersion.current)")
                Foundation.exit(0)
            }
            let arguments = try Arguments.parse(CommandLine.arguments)
            let root = URL(fileURLWithPath: arguments.path, isDirectory: true)
            let configuration = try ScanConfiguration.load(root: root)
            let graph = try ModuleGraphBuilder().build(root: root)
            if arguments.command == .graph {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                print(String(decoding: try encoder.encode(graph), as: UTF8.self))
                Foundation.exit(0)
            }
            var files = try SourceDiscovery().discover(root: root, graph: graph)
            files = files.filter { configuration.includes(path: $0.relativePath) }
            if let gitScope = arguments.gitScope {
                let changed = try GitChanges.swiftFiles(root: root, scope: gitScope)
                files = files.filter { changed.contains($0.relativePath) }
            }
            let rule = ExpensiveBodyConstructionRule()
            var findings = await withTaskGroup(of: [Finding].self) { group in
                for file in files {
                    group.addTask {
                        guard let source = try? String(contentsOf: file.absoluteURL, encoding: .utf8) else {
                            return []
                        }
                        let facts = SyntaxFactExtractor.swiftUIBodyFacts(source: source)
                        var result: [Finding] = []
                        if !configuration.disabledRules.contains(ExpensiveBodyConstructionRule.id) {
                            result += rule.evaluate(facts: facts, file: file)
                        }
                        if !configuration.disabledRules.contains(CollectionWorkInBodyRule.id) {
                            result += CollectionWorkInBodyRule().evaluate(facts: facts, file: file)
                        }
                        if !configuration.disabledRules.contains(DetachedTaskInBodyRule.id) {
                            result += DetachedTaskInBodyRule().evaluate(facts: facts, file: file)
                        }
                        return result.filter { $0.severity >= configuration.minimumSeverity }
                    }
                }
                var collected: [Finding] = []
                for await result in group {
                    collected.append(contentsOf: result)
                }
                return collected
            }

            findings.sort {
                ($0.file, $0.location.line, $0.location.column, $0.ruleID) <
                ($1.file, $1.location.line, $1.location.column, $1.ruleID)
            }
            findings = Array(findings.prefix(configuration.maxFindings))
            let modules = Set(files.compactMap(\.module))
            let report = ScanReport(
                scannedFileCount: files.count,
                modules: Array(modules),
                moduleGraph: graph.summary,
                findings: findings
            )
            print(try Reporter.render(report, format: arguments.format))
            Foundation.exit(findings.contains { $0.severity >= arguments.failOn } ? 1 : 0)
        } catch {
            FileHandle.standardError.write(Data("ViewDoctor: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static let help = """
    ViewDoctor \(ViewDoctorVersion.current) — local SwiftUI checks with module ownership

    USAGE
      viewdoctor scan [path] [options]
      viewdoctor graph [path]
      viewdoctor --help
      viewdoctor --version

    SCAN OPTIONS
      --git-diff              Scan tracked changes plus untracked Swift files
      --base <revision>       Scan changes since a Git revision plus untracked files
      --staged                Scan only Swift files staged for commit
      --format <format>       text, json, agent, or sarif (default: text)
      --fail-on <severity>    note, warning, or error (default: error)

    EXAMPLES
      viewdoctor scan . --git-diff --format agent
      viewdoctor scan . --staged --fail-on warning
      viewdoctor scan . --base origin/main --format sarif
      viewdoctor graph .

    EXIT CODES
      0  Scan completed below the configured failure threshold
      1  At least one finding met the configured failure threshold
      2  Invalid arguments or scan startup failure
    """
}

private struct Arguments {
    enum Command { case scan, graph }
    let command: Command
    let path: String
    let format: ReportFormat
    let gitScope: GitChangeScope?
    let failOn: Severity

    static func parse(_ raw: [String]) throws -> Arguments {
        var values = Array(raw.dropFirst())
        let command: Command
        if values.first == "graph" {
            command = .graph
            values.removeFirst()
        } else {
            command = .scan
            if values.first == "scan" { values.removeFirst() }
        }
        var path = "."
        var hasPath = false
        var format = ReportFormat.text
        var changed = false
        var staged = false
        var base: String?
        var failOn = Severity.error
        var index = 0
        while index < values.count {
            switch values[index] {
            case "--format":
                guard values.indices.contains(index + 1), let parsed = ReportFormat(rawValue: values[index + 1]) else {
                    throw ArgumentError.invalidFormat
                }
                format = parsed
                index += 2
            case "--git-diff":
                changed = true
                index += 1
            case "--staged":
                staged = true
                index += 1
            case "--base":
                guard values.indices.contains(index + 1) else { throw ArgumentError.missingValue("--base") }
                base = values[index + 1]
                changed = true
                index += 2
            case "--fail-on":
                guard values.indices.contains(index + 1), let severity = Severity(rawValue: values[index + 1]) else {
                    throw ArgumentError.invalidSeverity
                }
                failOn = severity
                index += 2
            case let value where value.hasPrefix("-"):
                throw ArgumentError.unknownOption(value)
            case let value:
                guard !hasPath else { throw ArgumentError.unexpectedArgument(value) }
                path = value
                hasPath = true
                index += 1
            }
        }
        if staged && changed { throw ArgumentError.conflictingGitScopes }
        let gitScope: GitChangeScope?
        if staged {
            gitScope = .staged
        } else if changed {
            gitScope = .changed(base: base)
        } else {
            gitScope = nil
        }
        return Arguments(command: command, path: path, format: format, gitScope: gitScope, failOn: failOn)
    }
}

private enum ArgumentError: Error, CustomStringConvertible {
    case invalidFormat
    case invalidSeverity
    case unknownOption(String)
    case missingValue(String)
    case unexpectedArgument(String)
    case conflictingGitScopes

    var description: String {
        switch self {
        case .invalidFormat: "--format must be 'text', 'json', 'agent', or 'sarif'."
        case .invalidSeverity: "--fail-on must be 'note', 'warning', or 'error'."
        case let .unknownOption(option): "Unknown option: \(option)"
        case let .missingValue(option): "Missing value for \(option)."
        case let .unexpectedArgument(argument): "Unexpected argument: \(argument)"
        case .conflictingGitScopes: "--staged cannot be combined with --git-diff or --base."
        }
    }
}
