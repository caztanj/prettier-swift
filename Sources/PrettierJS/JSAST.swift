import Foundation
import PrettierCore

open class JSNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class JSProgram: JSNode, @unchecked Sendable {
    public var body: [JSNode]

    public init(body: [JSNode], range: Range<Int> = 0..<0) {
        self.body = body
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        body
    }
}

public final class JSVariableDeclaration: JSNode, @unchecked Sendable {
    public var kind: String
    public var declarations: [JSVariableDeclarator]

    public init(kind: String, declarations: [JSVariableDeclarator], range: Range<Int> = 0..<0) {
        self.kind = kind
        self.declarations = declarations
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        declarations
    }
}

public final class JSVariableDeclarator: JSNode, @unchecked Sendable {
    public var id: JSNode
    public var initValue: JSNode?

    public init(id: JSNode, initValue: JSNode?, range: Range<Int> = 0..<0) {
        self.id = id
        self.initValue = initValue
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let initValue { return [id, initValue] }
        return [id]
    }
}

public final class JSFunctionDeclaration: JSNode, @unchecked Sendable {
    public var id: JSIdentifier?
    public var params: [JSNode]
    public var body: JSBlockStatement
    public var isAsync: Bool

    public init(id: JSIdentifier?, params: [JSNode], body: JSBlockStatement, isAsync: Bool = false, range: Range<Int> = 0..<0) {
        self.id = id
        self.params = params
        self.body = body
        self.isAsync = isAsync
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        var list: [JSNode] = []
        if let id { list.append(id) }
        list.append(contentsOf: params)
        list.append(body)
        return list
    }
}

public final class JSArrowFunctionExpression: JSNode, @unchecked Sendable {
    public var params: [JSNode]
    public var body: JSNode
    public var isAsync: Bool

    public init(params: [JSNode], body: JSNode, isAsync: Bool = false, range: Range<Int> = 0..<0) {
        self.params = params
        self.body = body
        self.isAsync = isAsync
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        params + [body]
    }
}

public final class JSBlockStatement: JSNode, @unchecked Sendable {
    public var body: [JSNode]

    public init(body: [JSNode], range: Range<Int> = 0..<0) {
        self.body = body
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        body
    }
}

public final class JSExpressionStatement: JSNode, @unchecked Sendable {
    public var expression: JSNode

    public init(expression: JSNode, range: Range<Int> = 0..<0) {
        self.expression = expression
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [expression]
    }
}

public final class JSReturnStatement: JSNode, @unchecked Sendable {
    public var argument: JSNode?

    public init(argument: JSNode?, range: Range<Int> = 0..<0) {
        self.argument = argument
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let argument { return [argument] }
        return []
    }
}

public final class JSIfStatement: JSNode, @unchecked Sendable {
    public var test: JSNode
    public var consequent: JSNode
    public var alternate: JSNode?

    public init(test: JSNode, consequent: JSNode, alternate: JSNode?, range: Range<Int> = 0..<0) {
        self.test = test
        self.consequent = consequent
        self.alternate = alternate
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let alternate { return [test, consequent, alternate] }
        return [test, consequent]
    }
}

public final class JSBinaryExpression: JSNode, @unchecked Sendable {
    public var operatorStr: String
    public var left: JSNode
    public var right: JSNode

    public init(operatorStr: String, left: JSNode, right: JSNode, range: Range<Int> = 0..<0) {
        self.operatorStr = operatorStr
        self.left = left
        self.right = right
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [left, right]
    }
}

public final class JSUnaryExpression: JSNode, @unchecked Sendable {
    public var operatorStr: String
    public var prefix: Bool
    public var argument: JSNode

    public init(operatorStr: String, prefix: Bool = true, argument: JSNode, range: Range<Int> = 0..<0) {
        self.operatorStr = operatorStr
        self.prefix = prefix
        self.argument = argument
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [argument]
    }
}

public final class JSCallExpression: JSNode, @unchecked Sendable {
    public var callee: JSNode
    public var arguments: [JSNode]

    public init(callee: JSNode, arguments: [JSNode], range: Range<Int> = 0..<0) {
        self.callee = callee
        self.arguments = arguments
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [callee] + arguments
    }
}

public final class JSMemberExpression: JSNode, @unchecked Sendable {
    public var object: JSNode
    public var property: JSNode
    public var computed: Bool

    public init(object: JSNode, property: JSNode, computed: Bool = false, range: Range<Int> = 0..<0) {
        self.object = object
        self.property = property
        self.computed = computed
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [object, property]
    }
}

public final class JSObjectExpression: JSNode, @unchecked Sendable {
    public var properties: [JSProperty]

    public init(properties: [JSProperty], range: Range<Int> = 0..<0) {
        self.properties = properties
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        properties
    }
}

public final class JSProperty: JSNode, @unchecked Sendable {
    public var key: JSNode
    public var value: JSNode
    public var shorthand: Bool

    public init(key: JSNode, value: JSNode, shorthand: Bool = false, range: Range<Int> = 0..<0) {
        self.key = key
        self.value = value
        self.shorthand = shorthand
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        shorthand ? [key] : [key, value]
    }
}

public final class JSArrayExpression: JSNode, @unchecked Sendable {
    public var elements: [JSNode]

    public init(elements: [JSNode], range: Range<Int> = 0..<0) {
        self.elements = elements
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        elements
    }
}

public final class JSIdentifier: JSNode, @unchecked Sendable {
    public var name: String

    public init(name: String, range: Range<Int> = 0..<0) {
        self.name = name
        super.init(sourceRange: range)
    }
}

public final class JSLiteral: JSNode, @unchecked Sendable {
    public var value: String
    public var raw: String
    public var isString: Bool

    public init(value: String, raw: String? = nil, isString: Bool = false, range: Range<Int> = 0..<0) {
        self.value = value
        self.raw = raw ?? value
        self.isString = isString
        super.init(sourceRange: range)
    }
}

public final class JSTemplateLiteral: JSNode, @unchecked Sendable {
    public var quasis: [String]
    public var expressions: [JSNode]

    public init(quasis: [String], expressions: [JSNode], range: Range<Int> = 0..<0) {
        self.quasis = quasis
        self.expressions = expressions
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        expressions
    }
}

public final class JSImportDeclaration: JSNode, @unchecked Sendable {
    public var defaultSpecifier: JSIdentifier?
    public var namespaceSpecifier: JSIdentifier?
    public var specifiers: [JSImportSpecifier]
    public var source: JSLiteral
    public var isTypeOnly: Bool

    public init(
        defaultSpecifier: JSIdentifier? = nil,
        namespaceSpecifier: JSIdentifier? = nil,
        specifiers: [JSImportSpecifier] = [],
        source: JSLiteral,
        isTypeOnly: Bool = false,
        range: Range<Int> = 0..<0
    ) {
        self.defaultSpecifier = defaultSpecifier
        self.namespaceSpecifier = namespaceSpecifier
        self.specifiers = specifiers
        self.source = source
        self.isTypeOnly = isTypeOnly
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        var list: [any CommentAttachable] = []
        if let def = defaultSpecifier { list.append(def) }
        if let ns = namespaceSpecifier { list.append(ns) }
        list.append(contentsOf: specifiers)
        list.append(source)
        return list
    }
}

public final class JSImportSpecifier: JSNode, @unchecked Sendable {
    public var imported: JSIdentifier
    public var local: JSIdentifier
    public var isType: Bool

    public init(imported: JSIdentifier, local: JSIdentifier, isType: Bool = false, range: Range<Int> = 0..<0) {
        self.imported = imported
        self.local = local
        self.isType = isType
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [imported, local]
    }
}

public final class JSExportNamedDeclaration: JSNode, @unchecked Sendable {
    public var declaration: JSNode?

    public init(declaration: JSNode?, range: Range<Int> = 0..<0) {
        self.declaration = declaration
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let declaration { return [declaration] }
        return []
    }
}

public final class JSExportDefaultDeclaration: JSNode, @unchecked Sendable {
    public var declaration: JSNode

    public init(declaration: JSNode, range: Range<Int> = 0..<0) {
        self.declaration = declaration
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [declaration]
    }
}
