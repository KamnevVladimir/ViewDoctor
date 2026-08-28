import Foundation
import ViewDoctorCore
import ViewDoctorGraph

public struct SourceDiscovery: Sendable {
    private let excludedDirectoryNames: Set<String> = [
        ".build", ".git", "build", "Derived", "DerivedData", "Pods", "Carthage",
        ".swiftpm", "xcuserdata", "Generated", "Vendor", "vendor",
    ]

    public init() {}

    public func discover(root: URL, graph: ModuleGraph = ModuleGraph(modules: [])) throws -> [SourceFile] {
        let root = root.standardizedFileURL
        if let gitFiles = gitSwiftFiles(root: root) {
            return gitFiles.map { relativePath in
                SourceFile(
                    absoluteURL: root.appending(path: relativePath),
                    relativePath: relativePath,
                    module: graph.module(containing: relativePath)?.id ?? moduleName(for: relativePath)
                )
            }.sorted { $0.relativePath < $1.relativePath }
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        var files: [SourceFile] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            if values.isDirectory == true, excludedDirectoryNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true, url.pathExtension == "swift" else { continue }
            let relativePath = String(url.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            files.append(SourceFile(
                absoluteURL: url,
                relativePath: relativePath,
                module: graph.module(containing: relativePath)?.id ?? moduleName(for: relativePath)
            ))
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func gitSwiftFiles(root: URL) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", ":(glob)**/*.swift"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self)
                .split(separator: "\0")
                .map(String.init)
        } catch {
            return nil
        }
    }

    public func moduleName(for relativePath: String) -> String? {
        let components = relativePath.split(separator: "/").map(String.init)
        for container in ["Modules", "Apps"] {
            guard let index = components.firstIndex(of: container), components.indices.contains(index + 1) else { continue }
            return components[index + 1]
        }
        for container in ["Sources", "Tests"] {
            guard let index = components.firstIndex(of: container), components.indices.contains(index + 1) else { continue }
            let child = components[index + 1]
            if child.hasSuffix(".swift"), index > 0 {
                return components[index - 1]
            }
            return child
        }
        return nil
    }
}
