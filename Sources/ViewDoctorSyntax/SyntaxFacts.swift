import Foundation
import SwiftParser
import SwiftSyntax
import ViewDoctorCore

public struct CallFact: Equatable, Sendable {
    public let name: String
    public let argumentLabels: [String?]
    public let location: ViewDoctorCore.SourceLocation

    public init(name: String, argumentLabels: [String?] = [], location: ViewDoctorCore.SourceLocation) {
        self.name = name
        self.argumentLabels = argumentLabels
        self.location = location
    }
}

public struct SwiftUIBodyFacts: Equatable, Sendable {
    public let calls: [CallFact]

    public init(calls: [CallFact]) {
        self.calls = calls
    }
}

public enum SyntaxFactExtractor {
    public static func swiftUIBodyFacts(source: String) -> SwiftUIBodyFacts {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "", tree: tree)
        let visitor = BodyVisitor(converter: converter)
        visitor.walk(tree)
        return SwiftUIBodyFacts(calls: visitor.calls)
    }
}

private final class BodyVisitor: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private var viewTypeDepth = 0
    private var bodyDepth = 0
    fileprivate var calls: [CallFact] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let isView = node.inheritanceClause?.inheritedTypes.contains { inherited in
            inherited.type.trimmedDescription == "View"
        } == true
        if isView { viewTypeDepth += 1 }
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        let isView = node.inheritanceClause?.inheritedTypes.contains { inherited in
            inherited.type.trimmedDescription == "View"
        } == true
        if isView { viewTypeDepth -= 1 }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isBody = viewTypeDepth > 0 && node.bindings.contains { binding in
            binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
        }
        if isBody { bodyDepth += 1 }
        return .visitChildren
    }

    override func visitPost(_ node: VariableDeclSyntax) {
        let isBody = viewTypeDepth > 0 && node.bindings.contains { binding in
            binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
        }
        if isBody { bodyDepth -= 1 }
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard bodyDepth > 0 else { return .visitChildren }
        let name: String?
        if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            name = reference.baseName.text
        } else if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
            name = member.declName.baseName.text
        } else {
            name = nil
        }
        if let name {
            let position = converter.location(for: node.positionAfterSkippingLeadingTrivia)
            calls.append(CallFact(
                name: name,
                argumentLabels: node.arguments.map { $0.label?.text },
                location: ViewDoctorCore.SourceLocation(line: position.line, column: position.column)
            ))
        }
        return .visitChildren
    }
}
