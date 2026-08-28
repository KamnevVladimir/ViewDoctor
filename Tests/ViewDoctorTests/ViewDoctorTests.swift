import Foundation
import Testing
import ViewDoctorCore
import ViewDoctorDiscovery
import ViewDoctorRules
import ViewDoctorSyntax
import ViewDoctorGraph

@Test func attributesModulesInCommonMultiModuleLayouts() {
    let discovery = SourceDiscovery()
    #expect(discovery.moduleName(for: "Modules/CheckoutFeature/Sources/View.swift") == "CheckoutFeature")
    #expect(discovery.moduleName(for: "Sources/Networking/Client.swift") == "Networking")
    #expect(discovery.moduleName(for: "Apps/DemoApp/Sources/App.swift") == "DemoApp")
    #expect(discovery.moduleName(for: "Features/Profile/Sources/ProfileView.swift") == "Profile")
}

@Test func detectsExpensiveConstructionInsideBodyOnly() {
    let source = """
    import SwiftUI
    struct DemoView: View {
        let cached = DateFormatter()
        var body: some View {
            let formatter = DateFormatter()
            Text(formatter.string(from: .now))
        }
    }
    """
    let file = SourceFile(
        absoluteURL: URL(fileURLWithPath: "/tmp/DemoView.swift"),
        relativePath: "Modules/Demo/Sources/DemoView.swift",
        module: "Demo"
    )
    let findings = ExpensiveBodyConstructionRule().evaluate(
        facts: SyntaxFactExtractor.swiftUIBodyFacts(source: source),
        file: file
    )
    #expect(findings.count == 1)
    #expect(findings.first?.ruleID == "VD001")
    #expect(findings.first?.module == "Demo")
}

@Test func jsonReporterPublishesVersionedAgentContract() throws {
    let report = ScanReport(scannedFileCount: 2, modules: ["FeatureB", "FeatureA"], findings: [])
    let json = try Reporter.render(report, format: .json)
    #expect(json.contains("\"schemaVersion\" : 1"))
    #expect(json.contains("\"FeatureA\""))
}

@Test func graphUsesLongestSourceRootAndBuildsReverseDependencyCone() {
    let graph = ModuleGraph(modules: [
        Module(id: "core", name: "Core", provider: .swiftPackage, root: "", sourceRoots: ["Sources/Core"]),
        Module(id: "feature", name: "Feature", provider: .tuist, root: "Modules/Feature", sourceRoots: ["Modules/Feature/Sources"], dependencies: ["core"]),
    ])
    #expect(graph.module(containing: "Modules/Feature/Sources/View.swift")?.id == "feature")
    #expect(graph.dependencyCone(startingAt: ["core"]) == ["core", "feature"])
}

@Test func sarifReporterUsesRelativeArtifactURI() throws {
    let finding = Finding(
        ruleID: "VD001", severity: .warning, file: "Sources/Demo.swift",
        location: SourceLocation(line: 3, column: 5), module: "Demo",
        message: "Risk", explanation: "Why", remediation: "Fix"
    )
    let output = try Reporter.render(ScanReport(scannedFileCount: 1, modules: ["Demo"], findings: [finding]), format: .sarif)
    #expect(output.contains("\"version\" : \"2.1.0\""))
    #expect(output.contains("Sources/Demo.swift"))
}

@Test func detectsAgentRelevantBodyWork() {
    let source = """
    import SwiftUI
    struct DemoView: View {
        var body: some View {
            let rows = values.sorted()
            Task.detached { await load() }
            return Text("\\(rows.count)")
        }
    }
    """
    let file = SourceFile(absoluteURL: URL(fileURLWithPath: "/tmp/Demo.swift"), relativePath: "Sources/Demo.swift", module: "Demo")
    let facts = SyntaxFactExtractor.swiftUIBodyFacts(source: source)
    #expect(CollectionWorkInBodyRule().evaluate(facts: facts, file: file).count == 1)
    #expect(DetachedTaskInBodyRule().evaluate(facts: facts, file: file).count == 1)
}

@Test func discoversSwiftPMAndTuistManifestModules() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let package = root.appending(path: "Package.swift")
    let tuistDirectory = root.appending(path: "Modules/Profile")
    try FileManager.default.createDirectory(at: tuistDirectory, withIntermediateDirectories: true)
    try """
    let package = Package(targets: [
      .target(name: "Core"),
      .target(name: "Feature", dependencies: ["Core"])
    ])
    """.write(to: package, atomically: true, encoding: .utf8)
    try """
    let project = Project(name: "Profile", targets: [
      .target(name: "Profile", dependencies: [.project(target: "Core", path: "../Core")])
    ])
    """.write(to: tuistDirectory.appending(path: "Project.swift"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let graph = try ModuleGraphBuilder().build(root: root)
    #expect(graph.modules.contains { $0.provider == .swiftPackage && $0.name == "Core" })
    #expect(graph.modules.contains { $0.provider == .tuist && $0.name == "Profile" })
    #expect(graph.summary.providers == ["swiftpm", "tuist"])
}

@Test func configurationBoundsAgentOutputAndExcludesTrees() {
    let configuration = ScanConfiguration(
        excludedPaths: ["Generated", "Modules/Legacy"],
        disabledRules: ["VD002"],
        minimumSeverity: .warning,
        maxFindings: 0
    )
    #expect(!configuration.includes(path: "Generated/API.swift"))
    #expect(!configuration.includes(path: "Modules/Legacy/Old.swift"))
    #expect(configuration.includes(path: "Modules/New/View.swift"))
    #expect(configuration.maxFindings == 1)
}

@Test func ignoresCheapUIImageConstructionAndFindsDecode() {
    let source = """
    import SwiftUI
    struct IconView: View {
        var body: some View {
            let icon = UIImage(systemName: "star")
            let decoded = UIImage(data: bytes)
            Text("\\(icon == decoded)")
        }
    }
    """
    let file = SourceFile(absoluteURL: URL(fileURLWithPath: "/tmp/Icon.swift"), relativePath: "Icon.swift", module: nil)
    let findings = ExpensiveBodyConstructionRule().evaluate(facts: SyntaxFactExtractor.swiftUIBodyFacts(source: source), file: file)
    #expect(findings.count == 1)
}
