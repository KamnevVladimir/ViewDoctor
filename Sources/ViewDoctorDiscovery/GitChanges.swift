import Foundation

public enum GitChanges {
    public static func changedSwiftFiles(root: URL, base: String?) throws -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = base.map { ["diff", "--name-only", "--diff-filter=ACMR", $0, "--", "*.swift"] }
            ?? ["diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "*.swift"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw GitChangesError.diffFailed }
        return Set(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init))
    }
}

public enum GitChangesError: Error {
    case diffFailed
}
