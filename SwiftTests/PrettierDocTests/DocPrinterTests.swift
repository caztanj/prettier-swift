import Testing
@testable import PrettierDoc

@Suite("PrettierDoc Printer Tests")
struct DocPrinterTests {
    @Test("Basic string printing")
    func basicPrinting() throws {
        let doc: Doc = ["hello", " ", "world"]
        let output = try printDocToString(doc)
        #expect(output.formatted == "hello world")
    }

    @Test("Group fits within printWidth")
    func groupFits() throws {
        let doc: Doc = group(["hello", line, "world"])
        let output = try printDocToString(doc, options: PrintOptions(printWidth: 80))
        #expect(output.formatted == "hello world")
    }

    @Test("Group breaks when exceeding printWidth")
    func groupBreaks() throws {
        let doc: Doc = group(["hello", line, "world"])
        let output = try printDocToString(doc, options: PrintOptions(printWidth: 5))
        #expect(output.formatted == "hello\nworld")
    }

    @Test("Indentation with spaces and tabs")
    func indentation() throws {
        let doc: Doc = ["parent", indent([line, "child"])]

        let spaceOutput = try printDocToString(doc, options: PrintOptions(printWidth: 80, tabWidth: 4, useTabs: false))
        #expect(spaceOutput.formatted == "parent\n    child")

        let tabOutput = try printDocToString(doc, options: PrintOptions(printWidth: 80, tabWidth: 4, useTabs: true))
        #expect(tabOutput.formatted == "parent\n\tchild")
    }

    @Test("Nested groups breaking behavior")
    func nestedGroups() throws {
        let inner = group(["[", indent([line, "1,", line, "2"]), line, "]"])
        let doc = group(["func(", indent([line, inner]), line, ")"])

        let flatOutput = try printDocToString(doc, options: PrintOptions(printWidth: 80))
        #expect(flatOutput.formatted == "func( [ 1, 2 ] )")

        let brokenOutput = try printDocToString(doc, options: PrintOptions(printWidth: 8))
        #expect(brokenOutput.formatted == "func(\n  [\n    1,\n    2\n  ]\n)")
    }

    @Test("ifBreak with group dependency")
    func ifBreakBehavior() throws {
        let gId = GroupId(name: "testGroup")
        let doc: Doc = [
            group(["const", line, "a", " = ", "1;"], id: gId),
            line,
            ifBreak("broken", "flat", groupId: gId)
        ]

        let flatOut = try printDocToString(doc, options: PrintOptions(printWidth: 80))
        #expect(flatOut.formatted == "const a = 1;\nflat")

        let breakOut = try printDocToString(doc, options: PrintOptions(printWidth: 5))
        #expect(breakOut.formatted == "const\na = 1;\nbroken")
    }

    @Test("Hardline forces break and parent break propagation")
    func hardlinePropagation() throws {
        let doc: Doc = group(["a", hardline, "b"])
        let output = try printDocToString(doc, options: PrintOptions(printWidth: 80))
        #expect(output.formatted == "a\nb")
    }

    @Test("Cursor tracking and trimming matching Prettier test suite")
    func cursorTracking() throws {
        let options = PrintOptions(printWidth: 80, tabWidth: 2)
        let doc: Doc = [
            "123",
            cursor,
            "Prettier  \t",
            cursor,
            "\t \t",
            hardline
        ]

        let output = try printDocToString(doc, options: options)
        #expect(output.formatted == "123Prettier\n")
        #expect(output.cursorNodeStart == 3)
        #expect(output.cursorNodeText == "Prettier")
    }

    @Test("Throws on too many cursors")
    func tooManyCursors() {
        let options = PrintOptions(printWidth: 80, tabWidth: 2)
        let doc: Doc = [cursor, cursor, cursor]
        #expect(throws: DocPrinterError.tooManyCursors) {
            try printDocToString(doc, options: options)
        }
    }

    @Test("Fill parts wrapping")
    func fillWrapping() throws {
        let words = ["apple", "banana", "cherry", "date", "elderberry", "fig", "grape"]
        var parts: [Doc] = []
        for (i, w) in words.enumerated() {
            if i > 0 { parts.append(line) }
            parts.append(Doc.text(w))
        }

        let doc = fill(parts)
        let output = try printDocToString(doc, options: PrintOptions(printWidth: 20))
        #expect(output.formatted == "apple banana cherry\ndate elderberry fig\ngrape")
    }

    @Test("Line suffix printed before newline")
    func lineSuffixPrinting() throws {
        let doc: Doc = [
            "code;",
            lineSuffix(" // comment"),
            hardline,
            "next;"
        ]

        let output = try printDocToString(doc)
        #expect(output.formatted == "code; // comment\nnext;")
    }

    @Test("Should trim blank first line")
    func trimBlankFirstLine() throws {
        let options = PrintOptions(printWidth: 80, tabWidth: 2)
        let doc: Doc = ["   ", hardline, "Prettier", hardline]
        let output = try printDocToString(doc, options: options)
        #expect(output.formatted == "\nPrettier\n")
    }

    @Test("Conditional group picks first state that fits")
    func conditionalGroupFitting() throws {
        let states: [Doc] = [
            "short",
            "medium-length-string",
            ["very", line, "long", line, "expanded", line, "string"]
        ]
        let doc = conditionalGroup(states)

        let fitShort = try printDocToString(doc, options: PrintOptions(printWidth: 10))
        #expect(fitShort.formatted == "short")

        let fitMedium = try printDocToString(conditionalGroup(Array(states.dropFirst())), options: PrintOptions(printWidth: 25))
        #expect(fitMedium.formatted == "medium-length-string")

        let breakLong = try printDocToString(conditionalGroup(Array(states.dropFirst())), options: PrintOptions(printWidth: 10))
        #expect(breakLong.formatted == "very\nlong\nexpanded\nstring")
    }

    @Test("Large document fill scaling")
    func largeDocFill() throws {
        let printOptions = PrintOptions(printWidth: 40, tabWidth: 2)
        let numbers = (1...255).map { String($0) }
        let doc = fill(join(separator: line, numbers.map { Doc.text($0) }))
        let output = try printDocToString(doc, options: printOptions)
        #expect(!output.formatted.isEmpty)
        #expect(output.formatted.contains("255"))
    }

    @Test("End of line CRLF support")
    func crlfSupport() throws {
        let doc: Doc = ["line 1", hardline, "line 2"]
        let output = try printDocToString(doc, options: PrintOptions(endOfLine: .crlf))
        #expect(output.formatted == "line 1\r\nline 2")
    }
}
