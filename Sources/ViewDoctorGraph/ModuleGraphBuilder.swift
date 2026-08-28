import Foundation

public struct ModuleGraphBuilder: Sendable {
    public init() {}

    public func build(root: URL) throws -> ModuleGraph {
        let manifests = try findManifests(root: root.standardizedFileURL)
        var modules: [Module] = []
        for manifest in manifests {
            switch manifest.lastPathComponent {
            case "Package.swift": modules += parseManifest(manifest, root: root, provider: .swiftPackage)
            case "Project.swift": modules += parseManifest(manifest, root: root, provider: .tuist)
            case "project.pbxproj": modules += parsePBXProject(manifest, root: root)
            default: break
            }
        }
        return ModuleGraph(modules: modules)
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

    private func parseManifest(_ manifest: URL, root: URL, provider: ModuleProvider) -> [Module] {
        guard let source = try? String(contentsOf: manifest, encoding: .utf8) else { return [] }
        let base = relative(manifest.deletingLastPathComponent(), to: root)
        let names = captureNames(source: source, provider: provider)
        return names.map { name in
            let conventionalRoot: String
            if provider == .swiftPackage {
                conventionalRoot = join(base, "Sources/\(name)")
            } else {
                conventionalRoot = inferredTuistSourceRoot(base: base, name: name)
            }
            return Module(
                id: "\(provider.rawValue):\(join(base, name))",
                name: name,
                provider: provider,
                root: base,
                sourceRoots: [conventionalRoot],
                dependencies: captureDependencies(source: source, targetName: name, provider: provider)
                    .map { "\(provider.rawValue):\(join(base, $0))" }
            )
        }
    }

    private func captureNames(source: String, provider: ModuleProvider) -> [String] {
        let pattern = provider == .swiftPackage
            ? #"\.(?:target|executableTarget|testTarget)\s*\(\s*name:\s*\"([^\"]+)\""#
            : #"\.target\s*\(\s*name:\s*\"([^\"]+)\""#
        return captures(pattern: pattern, source: source)
    }

    private func captureDependencies(source: String, targetName: String, provider: ModuleProvider) -> [String] {
        guard let targetRange = source.range(of: "name: \"\(targetName)\"") else { return [] }
        let tail = String(source[targetRange.upperBound...].prefix(12_000))
        guard let dependencyStart = tail.range(of: "dependencies:") else { return [] }
        let dependencySlice = String(tail[dependencyStart.upperBound...].prefix(4_000))
        let pattern = provider == .swiftPackage
            ? #"(?:\.target\s*\(\s*name:\s*|^)\"([^\"]+)\""#
            : #"\.(?:target|project)\s*\(\s*(?:name|target):\s*\"([^\"]+)\""#
        return captures(pattern: pattern, source: dependencySlice)
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
        String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func join(_ lhs: String, _ rhs: String) -> String {
        lhs.isEmpty ? rhs : "\(lhs)/\(rhs)"
    }
}
