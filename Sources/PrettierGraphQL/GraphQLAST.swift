import Foundation
import PrettierCore

open class GraphQLNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class GraphQLDocument: GraphQLNode, @unchecked Sendable {
    public var definitions: [GraphQLNode]

    public init(definitions: [GraphQLNode], range: Range<Int> = 0..<0) {
        self.definitions = definitions
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        definitions
    }
}

public final class GraphQLArgument: GraphQLNode, @unchecked Sendable {
    public var name: String
    public var value: String

    public init(name: String, value: String, range: Range<Int> = 0..<0) {
        self.name = name
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class GraphQLDirective: GraphQLNode, @unchecked Sendable {
    public var name: String
    public var arguments: [GraphQLArgument]

    public init(name: String, arguments: [GraphQLArgument], range: Range<Int> = 0..<0) {
        self.name = name
        self.arguments = arguments
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        arguments
    }
}

public final class GraphQLVariableDefinition: GraphQLNode, @unchecked Sendable {
    public var variable: String
    public var type: String
    public var defaultValue: String?

    public init(variable: String, type: String, defaultValue: String?, range: Range<Int> = 0..<0) {
        self.variable = variable
        self.type = type
        self.defaultValue = defaultValue
        super.init(sourceRange: range)
    }
}

public final class GraphQLSelectionSet: GraphQLNode, @unchecked Sendable {
    public var selections: [GraphQLNode]

    public init(selections: [GraphQLNode], range: Range<Int> = 0..<0) {
        self.selections = selections
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        selections
    }
}

public final class GraphQLField: GraphQLNode, @unchecked Sendable {
    public var alias: String?
    public var name: String
    public var arguments: [GraphQLArgument]
    public var directives: [GraphQLDirective]
    public var selectionSet: GraphQLSelectionSet?

    public init(
        alias: String? = nil,
        name: String,
        arguments: [GraphQLArgument] = [],
        directives: [GraphQLDirective] = [],
        selectionSet: GraphQLSelectionSet? = nil,
        range: Range<Int> = 0..<0
    ) {
        self.alias = alias
        self.name = name
        self.arguments = arguments
        self.directives = directives
        self.selectionSet = selectionSet
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        var list: [GraphQLNode] = []
        list.append(contentsOf: arguments)
        list.append(contentsOf: directives)
        if let selectionSet { list.append(selectionSet) }
        return list
    }
}

public final class GraphQLFragmentSpread: GraphQLNode, @unchecked Sendable {
    public var name: String
    public var directives: [GraphQLDirective]

    public init(name: String, directives: [GraphQLDirective] = [], range: Range<Int> = 0..<0) {
        self.name = name
        self.directives = directives
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        directives
    }
}

public final class GraphQLInlineFragment: GraphQLNode, @unchecked Sendable {
    public var typeCondition: String?
    public var directives: [GraphQLDirective]
    public var selectionSet: GraphQLSelectionSet

    public init(typeCondition: String?, directives: [GraphQLDirective] = [], selectionSet: GraphQLSelectionSet, range: Range<Int> = 0..<0) {
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        directives + [selectionSet]
    }
}

public final class GraphQLOperation: GraphQLNode, @unchecked Sendable {
    public var operationType: String
    public var name: String?
    public var variables: [GraphQLVariableDefinition]
    public var directives: [GraphQLDirective]
    public var selectionSet: GraphQLSelectionSet

    public init(
        operationType: String,
        name: String?,
        variables: [GraphQLVariableDefinition] = [],
        directives: [GraphQLDirective] = [],
        selectionSet: GraphQLSelectionSet,
        range: Range<Int> = 0..<0
    ) {
        self.operationType = operationType
        self.name = name
        self.variables = variables
        self.directives = directives
        self.selectionSet = selectionSet
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        var list: [GraphQLNode] = []
        list.append(contentsOf: variables)
        list.append(contentsOf: directives)
        list.append(selectionSet)
        return list
    }
}

public final class GraphQLFragment: GraphQLNode, @unchecked Sendable {
    public var name: String
    public var typeCondition: String
    public var directives: [GraphQLDirective]
    public var selectionSet: GraphQLSelectionSet

    public init(
        name: String,
        typeCondition: String,
        directives: [GraphQLDirective] = [],
        selectionSet: GraphQLSelectionSet,
        range: Range<Int> = 0..<0
    ) {
        self.name = name
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        directives + [selectionSet]
    }
}

public final class GraphQLFieldDefinition: GraphQLNode, @unchecked Sendable {
    public var name: String
    public var arguments: [GraphQLArgument]
    public var type: String

    public init(name: String, arguments: [GraphQLArgument] = [], type: String, range: Range<Int> = 0..<0) {
        self.name = name
        self.arguments = arguments
        self.type = type
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        arguments
    }
}

public final class GraphQLTypeDefinition: GraphQLNode, @unchecked Sendable {
    public var kind: String
    public var name: String
    public var fields: [GraphQLFieldDefinition]

    public init(kind: String, name: String, fields: [GraphQLFieldDefinition] = [], range: Range<Int> = 0..<0) {
        self.kind = kind
        self.name = name
        self.fields = fields
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        fields
    }
}
