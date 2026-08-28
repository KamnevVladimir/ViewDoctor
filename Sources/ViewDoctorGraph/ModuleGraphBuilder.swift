import Foundation
import SwiftParser
import SwiftSyntax

public struct ModuleGraphBuilder: Sendable {
    public init() {}

    public func build(root: URL) throws -> ModuleGraph {
        let root = root.standardizedFileURL
        let manifests = try findManifests(root: root)
        var modules: [Module] = []
        var diagnostics: [ModuleGraphDiagnostic] = []
        for manifest in manifests {
            switch manifest.lastPathComponent {
            case "Package.swift":
                let result = parseManifest(manifest, root: root, provider: .swiftPackage)
                modules += result.modules
                diagnostics += result.diagnostics
            case "Project.swift":
                let result = parseManifest(manifest, root: root, provider: .tuist)
                modules += result.modules
                diagnostics += result.diagnostics
            case "project.pbxproj":
                modules += parsePBXProject(manifest, root: root)
            default:
                break
            }
        }
        return ModuleGraph(modules: modules, diagnostics: diagnostics)
    }

    private func findManifests(root: URL) throws -> [URL] {
        if let gitManifests = gitManifestFiles(root: root) {
            return gitManifests.map { root.appending(path: $0) }
        }
        let excluded: Set<String> = [".build", ".git", "build", "Derived", "DerivedData", "Pods", "Carthage", "Vendor", "vendor"]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true, excluded.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
            } else if values.isRegularFile == true,
                      ["Package.swift", "Project.swift", "project.pbxproj"].contains(url.lastPathComponent) {
                result.append(url)
            }
        }
        return result
    }

    private func gitManifestFiles(root: URL) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = [
            "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--",
            ":(glob)**/Package.swift", ":(glob)**/Project.swift", ":(glob)**/project.pbxproj",
            ":(glob)Package.swift", ":(glob)Project.swift",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
        } catch {
            return nil
        }
    }

    private func parseManifest(_ manifest: URL, root: URL, provider: ModuleProvider) -> ManifestParseResult {
        guard let source = try? String(contentsOf: manifest, encoding: .utf8) else {
            return ManifestParseResult(modules: [], diagnostics: [])
        }
        let baseURL = manifest.deletingLastPathComponent()
        let base = relative(baseURL, to: root)
        let declarations = ManifestTargetParser.extract(source: source, provider: provider)
        var diagnostics: [ModuleGraphDiagnostic] = []
        if provider == .tuist, source.contains("ProjectDescriptionHelpers") {
            diagnostics.append(ModuleGraphDiagnostic(
                code: "VDG001",
                provider: .tuist,
                manifest: relative(manifest, to: root),
                message: "This manifest imports ProjectDescriptionHelpers; helper-generated targets cannot be expanded by static discovery."
            ))
        }

        let modules = declarations.map { declaration in
            let id = "\(provider.rawValue):\(join(base, declaration.name))"
            let explicitRoots = declaration.sourcePaths.compactMap {
                sourceRoot(pattern: $0, base: base)
            }
            let conventionalRoot: String
            if provider == .swiftPackage {
                conventionalRoot = join(base, "Sources/\(declaration.name)")
            } else {
                conventionalRoot = inferredTuistSourceRoot(base: base, name: declaration.name)
            }
            let dependencies = unique(declaration.dependencies.compactMap {
                dependencyID($0, provider: provider, manifest: manifest, root: root)
            }).filter { $0 != id }
            return Module(
                id: id,
                name: declaration.name,
                provider: provider,
                root: base,
                sourceRoots: explicitRoots.isEmpty ? [conventionalRoot] : explicitRoots,
                dependencies: dependencies
            )
        }
        return ManifestParseResult(modules: modules, diagnostics: diagnostics)
    }

    private func dependencyID(
        _ dependency: ManifestDependency,
        provider: ModuleProvider,
        manifest: URL,
        root: URL
    ) -> String? {
        let manifestBase = relative(manifest.deletingLastPathComponent(), to: root)
        let dependencyBase: String
        if let projectPath = dependency.projectPath {
            dependencyBase = normalizedRelativePath(
                projectPath.relativeToRoot ? projectPath.value : join(manifestBase, projectPath.value)
            )
        } else {
            dependencyBase = manifestBase
        }
        return "\(provider.rawValue):\(join(dependencyBase, dependency.name))"
    }

    private func sourceRoot(pattern: String, base: String) -> String? {
        let wildcardIndex = pattern.firstIndex { $0 == "*" || $0 == "?" || $0 == "[" }
        let literalPrefix = wildcardIndex.map { String(pattern[..<$0]) } ?? pattern
        let trimmed = literalPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        var path = normalizedRelativePath(join(base, trimmed))
        if !literalPrefix.hasSuffix("/"), URL(fileURLWithPath: path).pathExtension == "swift" {
            path = String(path.split(separator: "/").dropLast().joined(separator: "/"))
        }
        return path
    }

    private func parsePBXProject(_ manifest: URL, root: URL) -> [Module] {
        guard let source = try? String(contentsOf: manifest, encoding: .utf8) else { return [] }
        let baseURL = manifest.deletingLastPathComponent().deletingLastPathComponent()
        let base = relative(baseURL, to: root)
        let names = captures(pattern: #"isa = PBXNativeTarget;[\s\S]{0,600}?name = \"?([^;\"\n]+)\"?;"#, source: source)
        return names.map { name in
            Module(
                id: "xcode:\(join(base, name))",
                name: name,
                provider: .xcode,
                root: base,
                sourceRoots: [join(base, name), join(base, "Sources/\(name)")]
            )
        }
    }

    private func captures(pattern: String, source: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: source) else { return nil }
            return source[range].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func inferredTuistSourceRoot(base: String, name: String) -> String {
        if base.split(separator: "/").last.map(String.init) == name { return join(base, "Sources") }
        return join(base, "\(name)/Sources")
    }

    private func relative(_ url: URL, to root: URL) -> String {
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        return String(resolvedURL.path.dropFirst(resolvedRoot.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func join(_ lhs: String, _ rhs: String) -> String {
        lhs.isEmpty ? rhs : "\(lhs)/\(rhs)"
    }

    private func normalizedRelativePath(_ path: String) -> String {
        URL(fileURLWithPath: "/" + path).standardizedFileURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}

private struct ManifestParseResult {
    let modules: [Module]
    let diagnostics: [ModuleGraphDiagnostic]
}

private struct ManifestTarget {
    let name: String
    let sourcePaths: [String]
    let dependencies: [ManifestDependency]
}

private struct ManifestDependency {
    let name: String
    let projectPath: ManifestProjectPath?
}

private struct ManifestProjectPath {
    let value: String
    let relativeToRoot: Bool
}

private enum ManifestTargetParser {
    static func extract(source: String, provider: ModuleProvider) -> [ManifestTarget] {
        let tree = Parser.parse(source: source)
        let visitor = TargetVisitor(provider: provider)
        visitor.walk(tree)
        return visitor.targets
    }
}

private final class TargetVisitor: SyntaxVisitor {
    private let provider: ModuleProvider
    fileprivate var targets: [ManifestTarget] = []

    init(provider: ModuleProvider) {
        self.provider = provider
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isTargetFactory(callName(node)),
              let nameArgument = argument(named: "name", in: node),
              let name = literal(nameArgument.expression) else {
            return .visitChildren
        }

        let sourcePaths: [String]
        if provider == .swiftPackage, let path = argument(named: "path", in: node).flatMap({ literal($0.expression) }) {
            sourcePaths = [path]
        } else if provider == .tuist, let sources = argument(named: "sources", in: node) {
            sourcePaths = literals(in: sources.expression)
        } else {
            sourcePaths = []
        }

        let parsedDependencies = argument(named: "dependencies", in: node)
            .map { dependencies(in: $0.expression) } ?? []
        targets.append(ManifestTarget(name: name, sourcePaths: sourcePaths, dependencies: parsedDependencies))
        return .skipChildren
    }

    private func isTargetFactory(_ name: String?) -> Bool {
        guard let name else { return false }
        if provider == .swiftPackage {
            return ["target", "executableTarget", "testTarget"].contains(name)
        }
        return name == "target"
    }

    private func dependencies(in expression: ExprSyntax) -> [ManifestDependency] {
        guard let array = expression.as(ArrayExprSyntax.self) else { return [] }
        return array.elements.compactMap { element in
            if provider == .swiftPackage, let name = literal(element.expression) {
                return ManifestDependency(name: name, projectPath: nil)
            }
            guard let call = element.expression.as(FunctionCallExprSyntax.self),
                  let dependencyType = callName(call) else { return nil }
            if dependencyType == "target",
               let name = argument(named: "name", in: call).flatMap({ literal($0.expression) }) {
                return ManifestDependency(name: name, projectPath: nil)
            }
            if provider == .tuist,
               dependencyType == "project",
               let name = argument(named: "target", in: call).flatMap({ literal($0.expression) }),
               let pathExpression = argument(named: "path", in: call)?.expression,
               let path = projectPath(pathExpression) {
                return ManifestDependency(name: name, projectPath: path)
            }
            return nil
        }
    }

    private func projectPath(_ expression: ExprSyntax) -> ManifestProjectPath? {
        if let value = literal(expression) {
            return ManifestProjectPath(value: value, relativeToRoot: false)
        }
        guard let call = expression.as(FunctionCallExprSyntax.self),
              let kind = callName(call),
              let first = call.arguments.first,
              let value = literal(first.expression) else { return nil }
        switch kind {
        case "relativeToRoot":
            return ManifestProjectPath(value: value, relativeToRoot: true)
        case "relativeToManifest":
            return ManifestProjectPath(value: value, relativeToRoot: false)
        default:
            return nil
        }
    }

    private func argument(named name: String, in call: FunctionCallExprSyntax) -> LabeledExprSyntax? {
        call.arguments.first { $0.label?.text == name }
    }

    private func callName(_ call: FunctionCallExprSyntax) -> String? {
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        return call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }

    private func literal(_ expression: ExprSyntax) -> String? {
        expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
    }

    private func literals(in expression: ExprSyntax) -> [String] {
        if let value = literal(expression) { return [value] }
        let visitor = StringLiteralVisitor()
        visitor.walk(expression)
        return visitor.values
    }
}

private final class StringLiteralVisitor: SyntaxVisitor {
    fileprivate var values: [String] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        if let value = node.representedLiteralValue {
            values.append(value)
        }
        return .skipChildren
    }
}
