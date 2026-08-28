import Foundation
import ViewDoctorCore

public enum ModuleProvider: String, Codable, Sendable {
    case swiftPackage = "swiftpm"
    case tuist
    case xcode
    case folder
}

public struct Module: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let provider: ModuleProvider
    public let root: String
    public let sourceRoots: [String]
    public let dependencies: [String]

    public init(
        id: String,
        name: String,
        provider: ModuleProvider,
        root: String,
        sourceRoots: [String],
        dependencies: [String] = []
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.root = root
        self.sourceRoots = sourceRoots
        self.dependencies = dependencies
    }
}

public struct ModuleGraphDiagnostic: Codable, Equatable, Sendable {
    public let code: String
    public let provider: ModuleProvider
    public let manifest: String
    public let message: String

    public init(code: String, provider: ModuleProvider, manifest: String, message: String) {
        self.code = code
        self.provider = provider
        self.manifest = manifest
        self.message = message
    }
}

public struct ModuleGraph: Codable, Equatable, Sendable {
    public let modules: [Module]
    public let diagnostics: [ModuleGraphDiagnostic]

    public init(modules: [Module], diagnostics: [ModuleGraphDiagnostic] = []) {
        var seen: Set<String> = []
        self.modules = modules.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
        self.diagnostics = diagnostics.sorted {
            ($0.manifest, $0.code, $0.message) < ($1.manifest, $1.code, $1.message)
        }
    }

    public var summary: ModuleGraphSummary {
        let moduleIDs = Set(modules.map(\.id))
        let dependencies = modules.flatMap(\.dependencies)
        return ModuleGraphSummary(
            moduleCount: modules.count,
            dependencyCount: dependencies.count,
            unresolvedDependencyCount: dependencies.filter { !moduleIDs.contains($0) }.count,
            diagnosticCount: diagnostics.count,
            providers: Array(Set(modules.map(\.provider.rawValue)))
        )
    }

    public func module(containing relativePath: String) -> Module? {
        let normalized = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return modules
            .flatMap { module in module.sourceRoots.map { ($0, module) } }
            .filter { root, _ in normalized == root || normalized.hasPrefix(root + "/") }
            .max { $0.0.count < $1.0.count }?.1
    }

    public func dependencyCone(startingAt moduleIDs: Set<String>) -> Set<String> {
        var result = moduleIDs
        var changed = true
        while changed {
            changed = false
            for module in modules where !result.contains(module.id) {
                if !Set(module.dependencies).isDisjoint(with: result) {
                    result.insert(module.id)
                    changed = true
                }
            }
        }
        return result
    }
}
