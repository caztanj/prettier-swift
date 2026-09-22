import Testing
@testable import PrettierMarkdown
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

@Suite("MarkdownPrinter Tests")
struct MarkdownPrinterTests {

    @Test("Formats headings and paragraphs")
    func testHeadingsAndParagraphs() throws {
        let input = """
        #    Hello World    

        This is a paragraph with **bold** text and *italic* text and `code`.
        """
        let formatted = try formatMarkdown(input)
        let expected = """
        # Hello World

        This is a paragraph with **bold** text and *italic* text and `code`.

        """
        #expect(formatted == expected)
    }

    @Test("Formats fenced code blocks")
    func testCodeBlocks() throws {
        let input = """
        ```swift
        let x = 10
        print(x)
        ```
        """
        let formatted = try formatMarkdown(input)
        let expected = """
        ```swift
        let x = 10
        print(x)
        ```

        """
        #expect(formatted == expected)
    }

    @Test("Formats lists")
    func testLists() throws {
        let input = """
        - item 1
        * item 2
        + item 3

        1. first
        1. second
        """
        let formatted = try formatMarkdown(input)
        let expected = """
        - item 1
        - item 2
        - item 3

        1. first
        2. second

        """
        #expect(formatted == expected)
    }

    @Test("Formats tables with column alignment")
    func testTables() throws {
        let input = """
        | Name | Age | Country |
        |---|:---:|---:|
        | Alice | 25 | Sweden |
        | Bob | 30 | USA |
        """
        let formatted = try formatMarkdown(input)
        let expected = """
        | Name  | Age | Country |
        | ----- | :-: | ------: |
        | Alice | 25  | Sweden  |
        | Bob   | 30  | USA     |

        """
        #expect(formatted == expected)
    }

    @Test("Formats links and images")
    func testLinksAndImages() throws {
        let input = """
        Check out [Prettier](https://prettier.io "Prettier Home") and ![Logo](https://prettier.io/logo.png).
        """
        let formatted = try formatMarkdown(input)
        let expected = """
        Check out [Prettier](https://prettier.io "Prettier Home") and ![Logo](https://prettier.io/logo.png).

        """
        #expect(formatted == expected)
    }

    @Test("Plugin can format markdown by extension and parser name")
    func testPluginRegistration() throws {
        let plugin = MarkdownPlugin()
        #expect(plugin.canFormat(filePath: "README.md", parserName: nil))
        #expect(plugin.canFormat(filePath: "doc.markdown", parserName: nil))
        #expect(plugin.canFormat(filePath: nil, parserName: "markdown"))
        #expect(plugin.canFormat(filePath: nil, parserName: "md"))
        #expect(!plugin.canFormat(filePath: "data.json", parserName: nil))
    }
}
