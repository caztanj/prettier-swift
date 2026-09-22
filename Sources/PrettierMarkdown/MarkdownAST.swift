import Foundation
import PrettierCore

public enum MarkdownTableAlignment: Sendable {
    case none
    case left
    case center
    case right
}

open class MarkdownNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class MarkdownDocument: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownHeading: MarkdownNode, @unchecked Sendable {
    public var level: Int
    public var children: [MarkdownNode]

    public init(level: Int, children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.level = level
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownParagraph: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownCodeBlock: MarkdownNode, @unchecked Sendable {
    public var language: String
    public var value: String

    public init(language: String, value: String, range: Range<Int> = 0..<0) {
        self.language = language
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class MarkdownBlockQuote: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownList: MarkdownNode, @unchecked Sendable {
    public var isOrdered: Bool
    public var items: [MarkdownListItem]

    public init(isOrdered: Bool, items: [MarkdownListItem], range: Range<Int> = 0..<0) {
        self.isOrdered = isOrdered
        self.items = items
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        items
    }
}

public final class MarkdownListItem: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownThematicBreak: MarkdownNode, @unchecked Sendable {}

public final class MarkdownTable: MarkdownNode, @unchecked Sendable {
    public var headers: [String]
    public var alignments: [MarkdownTableAlignment]
    public var rows: [[String]]

    public init(
        headers: [String],
        alignments: [MarkdownTableAlignment],
        rows: [[String]],
        range: Range<Int> = 0..<0
    ) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
        super.init(sourceRange: range)
    }
}

public final class MarkdownHTMLBlock: MarkdownNode, @unchecked Sendable {
    public var value: String

    public init(value: String, range: Range<Int> = 0..<0) {
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class MarkdownText: MarkdownNode, @unchecked Sendable {
    public var value: String

    public init(value: String, range: Range<Int> = 0..<0) {
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class MarkdownEmphasis: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownStrong: MarkdownNode, @unchecked Sendable {
    public var children: [MarkdownNode]

    public init(children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownInlineCode: MarkdownNode, @unchecked Sendable {
    public var value: String

    public init(value: String, range: Range<Int> = 0..<0) {
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class MarkdownLink: MarkdownNode, @unchecked Sendable {
    public var url: String
    public var title: String?
    public var children: [MarkdownNode]

    public init(url: String, title: String?, children: [MarkdownNode], range: Range<Int> = 0..<0) {
        self.url = url
        self.title = title
        self.children = children
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        children
    }
}

public final class MarkdownImage: MarkdownNode, @unchecked Sendable {
    public var url: String
    public var title: String?
    public var alt: String

    public init(url: String, title: String?, alt: String, range: Range<Int> = 0..<0) {
        self.url = url
        self.title = title
        self.alt = alt
        super.init(sourceRange: range)
    }
}

public final class MarkdownBreak: MarkdownNode, @unchecked Sendable {}
