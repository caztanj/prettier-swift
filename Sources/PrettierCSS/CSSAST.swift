import Foundation
import PrettierCore

open class CSSNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class CSSStyleSheet: CSSNode, @unchecked Sendable {
    public var children: [CSSNode]

    public init(children: [CSSNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class CSSRule: CSSNode, @unchecked Sendable {
    public var selectors: [String]
    public var body: [CSSNode]

    public init(selectors: [String], body: [CSSNode], range: Range<Int> = 0..<0) {
        self.selectors = selectors
        self.body = body
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        body
    }
}

public final class CSSDeclaration: CSSNode, @unchecked Sendable {
    public var property: String
    public var value: String
    public var important: Bool

    public init(property: String, value: String, important: Bool = false, range: Range<Int> = 0..<0) {
        self.property = property
        self.value = value
        self.important = important
        super.init(sourceRange: range)
    }
}

public final class CSSAtRule: CSSNode, @unchecked Sendable {
    public var name: String
    public var params: String
    public var block: [CSSNode]?

    public init(name: String, params: String, block: [CSSNode]?, range: Range<Int> = 0..<0) {
        self.name = name
        self.params = params
        self.block = block
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        block ?? []
    }
}
