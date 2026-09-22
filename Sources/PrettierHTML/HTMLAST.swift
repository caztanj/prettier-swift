import Foundation
import PrettierCore

open class HTMLNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class HTMLDocument: HTMLNode, @unchecked Sendable {
    public var children: [HTMLNode]

    public init(children: [HTMLNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class HTMLDoctype: HTMLNode, @unchecked Sendable {
    public var value: String

    public init(value: String, range: Range<Int> = 0..<0) {
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class HTMLAttribute: HTMLNode, @unchecked Sendable {
    public var name: String
    public var value: String?

    public init(name: String, value: String?, range: Range<Int> = 0..<0) {
        self.name = name
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class HTMLElement: HTMLNode, @unchecked Sendable {
    public var tag: String
    public var attributes: [HTMLAttribute]
    public var children: [HTMLNode]
    public var isSelfClosing: Bool

    public static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    public var isVoid: Bool {
        HTMLElement.voidTags.contains(tag.lowercased())
    }

    public init(
        tag: String,
        attributes: [HTMLAttribute],
        children: [HTMLNode],
        isSelfClosing: Bool = false,
        range: Range<Int> = 0..<0
    ) {
        self.tag = tag
        self.attributes = attributes
        self.children = children
        self.isSelfClosing = isSelfClosing
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        attributes + children
    }
}

public final class HTMLText: HTMLNode, @unchecked Sendable {
    public var value: String

    public init(value: String, range: Range<Int> = 0..<0) {
        self.value = value
        super.init(sourceRange: range)
    }
}
