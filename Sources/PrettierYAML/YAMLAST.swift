import PrettierCore

public class YAMLNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int> = 0..<0) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class YAMLDocument: YAMLNode {
    public let hasDirectivesEnd: Bool
    public let body: YAMLNode?

    public init(body: YAMLNode?, hasDirectivesEnd: Bool = false, range: Range<Int> = 0..<0) {
        self.body = body
        self.hasDirectivesEnd = hasDirectivesEnd
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let body { return [body] }
        return []
    }
}

public final class YAMLMapping: YAMLNode {
    public let items: [YAMLMappingItem]

    public init(items: [YAMLMappingItem], range: Range<Int> = 0..<0) {
        self.items = items
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        items
    }
}

public final class YAMLMappingItem: YAMLNode {
    public let key: YAMLNode
    public let value: YAMLNode?

    public init(key: YAMLNode, value: YAMLNode?, range: Range<Int> = 0..<0) {
        self.key = key
        self.value = value
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        if let value { return [key, value] }
        return [key]
    }
}

public final class YAMLSequence: YAMLNode {
    public let items: [YAMLNode]

    public init(items: [YAMLNode], range: Range<Int> = 0..<0) {
        self.items = items
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        items
    }
}

public enum YAMLScalarStyle: Sendable, Equatable {
    case plain
    case singleQuote
    case doubleQuote
    case literal
    case folded
}

public final class YAMLScalar: YAMLNode {
    public let value: String
    public let style: YAMLScalarStyle
    public let raw: String

    public init(value: String, style: YAMLScalarStyle = .plain, raw: String = "", range: Range<Int> = 0..<0) {
        self.value = value
        self.style = style
        self.raw = raw.isEmpty ? value : raw
        super.init(sourceRange: range)
    }
}
