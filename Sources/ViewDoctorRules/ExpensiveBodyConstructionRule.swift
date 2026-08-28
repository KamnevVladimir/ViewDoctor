import ViewDoctorCore
import ViewDoctorSyntax

public struct ExpensiveBodyConstructionRule: Sendable {
    public static let id = "VD001"

    private let expensiveTypes: Set<String> = [
        "CIContext", "DateFormatter", "ISO8601DateFormatter", "JSONDecoder",
        "JSONEncoder", "NumberFormatter", "PersonNameComponentsFormatter",
    ]

    public init() {}

    public func evaluate(facts: SwiftUIBodyFacts, file: SourceFile) -> [Finding] {
        facts.calls.compactMap { call in
            let firstLabel = call.argumentLabels.first.flatMap { $0 }
            let isImageDecode = call.name == "UIImage" && ["data", "contentsOfFile"].contains(firstLabel ?? "")
            guard expensiveTypes.contains(call.name) || isImageDecode else { return nil }
            return Finding(
                ruleID: Self.id,
                severity: .warning,
                file: file.relativePath,
                location: call.location,
                module: file.module,
                message: "\(call.name) is constructed inside a body property.",
                explanation: "SwiftUI may evaluate body repeatedly; constructing reusable Foundation or Core Image helpers there adds avoidable work.",
                remediation: "Move the instance to stable storage, inject it, or cache it outside body."
            )
        }
    }
}

public struct CollectionWorkInBodyRule: Sendable {
    public static let id = "VD002"
    private let transforms: Set<String> = ["compactMap", "filter", "flatMap", "map", "reduce", "sorted"]

    public init() {}

    public func evaluate(facts: SwiftUIBodyFacts, file: SourceFile) -> [Finding] {
        facts.calls.compactMap { call in
            guard transforms.contains(call.name) else { return nil }
            return Finding(
                ruleID: Self.id,
                severity: .note,
                file: file.relativePath,
                location: call.location,
                module: file.module,
                message: "Collection transformation '\(call.name)' runs inside a body property.",
                explanation: "SwiftUI can evaluate body repeatedly. A non-trivial collection transformation may repeat work even when its inputs did not change.",
                remediation: "Precompute the value in the state owner or verify with Instruments before suppressing this finding."
            )
        }
    }
}

public struct DetachedTaskInBodyRule: Sendable {
    public static let id = "VD003"

    public init() {}

    public func evaluate(facts: SwiftUIBodyFacts, file: SourceFile) -> [Finding] {
        facts.calls.compactMap { call in
            guard call.name == "detached" else { return nil }
            return Finding(
                ruleID: Self.id,
                severity: .warning,
                file: file.relativePath,
                location: call.location,
                module: file.module,
                message: "Detached task is created inside a body property.",
                explanation: "Body evaluation is not a task lifetime boundary. Detached work also drops actor context and structured cancellation.",
                remediation: "Move work to an explicit state owner or use SwiftUI's task modifier with cancellation-aware async code."
            )
        }
    }
}
