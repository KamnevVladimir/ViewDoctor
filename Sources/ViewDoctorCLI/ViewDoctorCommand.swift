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
            if arguments.gitDiff {
                let changed = try GitChanges.changedSwiftFiles(root: root, base: arguments.base)
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
            Foundation.exit(findings.contains { $0.severity == .error } ? 1 : 0)
        } catch {
            FileHandle.standardError.write(Data("ViewDoctor: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }
}

private struct Arguments {
    enum Command { case scan, graph }
    let command: Command
    let path: String
    let format: ReportFormat
    let gitDiff: Bool
    let base: String?

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
        var format = ReportFormat.text
        var gitDiff = false
        var base: String?
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
                gitDiff = true
                index += 1
            case "--base":
                guard values.indices.contains(index + 1) else { throw ArgumentError.missingValue("--base") }
                base = values[index + 1]
                gitDiff = true
                index += 2
            case let value where value.hasPrefix("-"):
                throw ArgumentError.unknownOption(value)
            case let value:
                path = value
                index += 1
            }
        }
        return Arguments(command: command, path: path, format: format, gitDiff: gitDiff, base: base)
    }
}

private enum ArgumentError: Error, CustomStringConvertible {
    case invalidFormat
    case unknownOption(String)
    case missingValue(String)

    var description: String {
        switch self {
        case .invalidFormat: "--format must be 'text', 'json', or 'sarif'."
        case let .unknownOption(option): "Unknown option: \(option)"
        case let .missingValue(option): "Missing value for \(option)."
        }
    }
}
