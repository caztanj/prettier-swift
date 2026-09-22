import PrettierCore

public class JSONNode: CommentAttachable {
    public let sourceRange: Range<Int>
    public var comments: [Comment] = []

    public init(sourceRange: Range<Int>) {
        self.sourceRange = sourceRange
    }

    public var childNodes: [any CommentAttachable] {
        []
    }
}

public final class JSONRoot: JSONNode {
    public let value: JSONNode

    public init(value: JSONNode, range: Range<Int>) {
        self.value = value
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [value]
    }
}

public final class JSONObject: JSONNode {
    public let properties: [JSONProperty]

    public init(properties: [JSONProperty], range: Range<Int>) {
        self.properties = properties
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        properties
    }
}

public final class JSONProperty: JSONNode {
    public let key: JSONNode
    public let value: JSONNode

    public init(key: JSONNode, value: JSONNode, range: Range<Int>) {
        self.key = key
        self.value = value
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        [key, value]
    }
}

public final class JSONArray: JSONNode {
    public let elements: [JSONNode]

    public init(elements: [JSONNode], range: Range<Int>) {
        self.elements = elements
        super.init(sourceRange: range)
    }

    public override var childNodes: [any CommentAttachable] {
        elements
    }
}

public final class JSONString: JSONNode {
    public let value: String
    public let raw: String

    public init(value: String, raw: String, range: Range<Int>) {
        self.value = value
        self.raw = raw
        super.init(sourceRange: range)
    }
}

public final class JSONNumber: JSONNode {
    public let raw: String

    public init(raw: String, range: Range<Int>) {
        self.raw = raw
        super.init(sourceRange: range)
    }
}

public final class JSONBoolean: JSONNode {
    public let value: Bool

    public init(value: Bool, range: Range<Int>) {
        self.value = value
        super.init(sourceRange: range)
    }
}

public final class JSONNull: JSONNode {
    public override init(sourceRange: Range<Int>) {
        super.init(sourceRange: sourceRange)
    }
}

public final class JSONIdentifier: JSONNode {
    public let name: String

    public init(name: String, range: Range<Int>) {
        self.name = name
        super.init(sourceRange: range)
    }
}
