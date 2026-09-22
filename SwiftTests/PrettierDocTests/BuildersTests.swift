import Testing
@testable import PrettierDoc

@Suite("PrettierDoc Builders Tests")
struct BuildersTests {
    @Test("Literal expressions build expected Docs")
    func literalExpressions() {
        let stringDoc: Doc = "hello"
        #expect(stringDoc == .text("hello"))

        let arrayDoc: Doc = ["a", "b"]
        #expect(arrayDoc == .concat([.text("a"), .text("b")]))
    }

    @Test("GroupId generates unique values")
    func uniqueGroupIds() {
        let id1 = GroupId(name: "first")
        let id2 = GroupId(name: "second")
        #expect(id1 != id2)
        #expect(id1 == id1)
    }

    @Test("Join inserts separator between elements")
    func joinElements() {
        let items: [Doc] = ["a", "b", "c"]
        let joined = join(separator: line, items)
        #expect(joined == [.text("a"), .line, .text("b"), .line, .text("c")])

        let single: [Doc] = ["a"]
        #expect(join(separator: line, single) == [.text("a")])

        let empty: [Doc] = []
        #expect(join(separator: line, empty) == [])
    }

    @Test("Alignment builders produce expected docs")
    func alignments() {
        let base: Doc = "code"
        #expect(dedent(base) == .align(.number(-1), base))
        #expect(dedentToRoot(base) == .align(.toRoot, base))
        #expect(markAsRoot(base) == .align(.root, base))
        #expect(align("  ", base) == .align(.string("  "), base))

        let aligned = addAlignmentToDoc(base, size: 5, tabWidth: 2)
        #expect(aligned == .align(.toRoot, .align(.number(1), .indent(.indent(base)))))
    }

    @Test("Group and conditionalGroup builders")
    func groupBuilders() {
        let g = group(["x", line, "y"], shouldBreak: true)
        #expect(g == .group(contents: .concat([.text("x"), .line, .text("y")]), shouldBreak: true))

        let cg = conditionalGroup([["x"], ["x", line, "y"]])
        #expect(cg == .group(
            contents: .concat([.text("x")]),
            shouldBreak: false,
            expandedStates: [.concat([.text("x")]), .concat([.text("x"), .line, .text("y")])]
        ))
    }

    @Test("Label builder ignores nil or empty label")
    func labelBuilder() {
        let base: Doc = "content"
        #expect(label(nil, base) == base)
        #expect(label("", base) == base)
        #expect(label("tag", base) == .label("tag", base))
    }
}
