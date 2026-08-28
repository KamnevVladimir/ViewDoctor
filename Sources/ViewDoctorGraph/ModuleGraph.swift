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

public struct ModuleGraph: Codable, Equatable, Sendable {
    public let modules: [Module]

    public init(modules: [Module]) {
        var seen: Set<String> = []
        self.modules = modules.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    public var summary: ModuleGraphSummary {
        ModuleGraphSummary(
            moduleCount: modules.count,
            dependencyCount: modules.reduce(0) { $0 + $1.dependencies.count },
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

