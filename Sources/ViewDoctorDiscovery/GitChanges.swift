import Foundation

public enum GitChangeScope: Equatable, Sendable {
    case changed(base: String?)
    case staged
}

public enum GitChanges {
    public static func swiftFiles(root: URL, scope: GitChangeScope) throws -> Set<String> {
        switch scope {
        case let .changed(base):
            let changed: Set<String>
            if base != nil || hasHead(root: root) {
                changed = try runGit(root: root, arguments: diffArguments(base: base))
            } else {
                let staged = try runGit(root: root, arguments: stagedDiffArguments)
                let unstaged = try runGit(root: root, arguments: workingTreeDiffArguments)
                changed = staged.union(unstaged)
            }
            let untracked = try runGit(
                root: root,
                arguments: [
                    "ls-files", "--others", "--exclude-standard", "-z", "--",
                    ":(glob)**/*.swift", ":(glob)*.swift",
                ]
            )
            return changed.union(untracked)
        case .staged:
            return try runGit(root: root, arguments: stagedDiffArguments)
        }
    }

    private static let stagedDiffArguments = [
        "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR", "--",
        ":(glob)**/*.swift", ":(glob)*.swift",
    ]

    private static let workingTreeDiffArguments = [
        "diff", "--name-only", "-z", "--diff-filter=ACMR", "--",
        ":(glob)**/*.swift", ":(glob)*.swift",
    ]

    private static func diffArguments(base: String?) -> [String] {
        var arguments = ["diff", "--name-only", "-z", "--diff-filter=ACMR"]
        arguments.append(base ?? "HEAD")
        arguments += ["--", ":(glob)**/*.swift", ":(glob)*.swift"]
        return arguments
    }

    private static func runGit(root: URL, arguments: [String]) throws -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw GitChangesError.diffFailed }
        return Set(String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init))
    }

    private static func hasHead(root: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = ["rev-parse", "--verify", "HEAD"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

public enum GitChangesError: Error {
    case diffFailed
}
