import PrettierDoc

public enum CommentPlacement: Sendable, Equatable {
    case ownLine
    case endOfLine
    case remaining
}

public final class Comment: @unchecked Sendable, Equatable {
    public let text: String
    public let range: Range<Int>
    public let isBlock: Bool
    public var leading: Bool = false
    public var trailing: Bool = false
    public var printed: Bool = false
    public var marker: String?
    public var placement: CommentPlacement?

    public init(
        text: String,
        range: Range<Int>,
        isBlock: Bool,
        marker: String? = nil
    ) {
        self.text = text
        self.range = range
        self.isBlock = isBlock
        self.marker = marker
    }

    public static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs === rhs
    }
}

public protocol CommentAttachable: AnyObject {
    var sourceRange: Range<Int> { get }
    var comments: [Comment] { get set }
    var childNodes: [any CommentAttachable] { get }
}
