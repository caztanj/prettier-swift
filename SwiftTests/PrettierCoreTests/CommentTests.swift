import Testing
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

final class MockNode: CommentAttachable {
    let sourceRange: Range<Int>
    var comments: [Comment] = []
    var childNodes: [any CommentAttachable]

    init(range: Range<Int>, children: [any CommentAttachable] = []) {
        self.sourceRange = range
        self.childNodes = children
    }
}

@Suite("PrettierCore Comments Tests")
struct CommentTests {
    @Test("Attach leading comment on its own line")
    func leadingCommentAttachment() {
        let source = "// comment\nvar a = 1;"
        let root = MockNode(range: 0..<source.count)
        let child = MockNode(range: 11..<21)
        root.childNodes = [child]

        let comment = Comment(text: "// comment", range: 0..<10, isBlock: false)
        attachComments(root: root, comments: [comment], sourceText: source)

        #expect(comment.leading == true)
        #expect(comment.trailing == false)
        #expect(child.comments.count == 1)
        #expect(child.comments[0] === comment)
    }

    @Test("Attach trailing comment at end of line")
    func trailingCommentAttachment() {
        let source = "var a = 1; // comment\n"
        let root = MockNode(range: 0..<source.count)
        let child = MockNode(range: 0..<10)
        root.childNodes = [child]

        let comment = Comment(text: "// comment", range: 11..<21, isBlock: false)
        attachComments(root: root, comments: [comment], sourceText: source)

        #expect(comment.leading == false)
        #expect(comment.trailing == true)
        #expect(child.comments.count == 1)
        #expect(child.comments[0] === comment)
    }

    @Test("Attach dangling comment when no children surround it")
    func danglingCommentAttachment() {
        let source = "{\n  // empty block comment\n}"
        let block = MockNode(range: 0..<source.count)

        let comment = Comment(text: "// empty block comment", range: 4..<26, isBlock: false)
        attachComments(root: block, comments: [comment], sourceText: source)

        #expect(comment.leading == false)
        #expect(comment.trailing == false)
        #expect(block.comments.count == 1)
        #expect(block.comments[0] === comment)
    }

    @Test("Print leading and trailing comments end to end with DocPrinter")
    func printCommentsIntegration() throws {
        let source = "// header\nvar a = 1; // inline\n"
        let node = MockNode(range: 10..<20)
        let leading = Comment(text: "// header", range: 0..<9, isBlock: false)
        let trailing = Comment(text: "// inline", range: 21..<30, isBlock: false)

        leading.leading = true
        trailing.trailing = true
        node.comments = [leading, trailing]

        let doc = CommentPrinter.wrapWithComments(
            doc: "var a = 1;",
            node: node,
            sourceText: source
        )

        let output = try printDocToString(doc)
        #expect(output.formatted == "// header\nvar a = 1; // inline")
    }
}
