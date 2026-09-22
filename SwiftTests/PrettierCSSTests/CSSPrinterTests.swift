import Testing
@testable import PrettierCSS
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

@Suite("PrettierCSS Formatting Tests")
struct CSSPrinterTests {

    @Test("Format single rule with declarations")
    func testSingleRule() throws {
        let input = """
        .container {
        color:red;
        background-color:   #ffffff;
        margin: 0px 10px;
        }
        """
        let formatted = try formatCSS(input)
        let expected = """
        .container {
          color: red;
          background-color: #ffffff;
          margin: 0px 10px;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format multiple selectors")
    func testMultipleSelectors() throws {
        let input = """
        h1,h2,  .title {
        font-size: 24px;
        font-weight:bold !important;
        }
        """
        let formatted = try formatCSS(input)
        let expected = """
        h1,
        h2,
        .title {
          font-size: 24px;
          font-weight: bold !important;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format multiple rules with blank line separator")
    func testMultipleRules() throws {
        let input = """
        body { margin: 0; }
        p { line-height: 1.5; }
        """
        let formatted = try formatCSS(input)
        let expected = """
        body {
          margin: 0;
        }

        p {
          line-height: 1.5;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format at-rules like @media and @import")
    func testAtRules() throws {
        let input = """
        @import "reset.css";
        @media (max-width: 600px) {
        .card {
        padding: 10px;
        }
        }
        """
        let formatted = try formatCSS(input)
        let expected = """
        @import "reset.css";

        @media (max-width: 600px) {
          .card {
            padding: 10px;
          }
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format CSS comments")
    func testCSSComments() throws {
        let input = """
        /* Main heading */
        h1 {
          color: blue;
        }
        """
        let formatted = try formatCSS(input)
        let expected = """
        /* Main heading */
        h1 {
          color: blue;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Plugin can format CSS, SCSS, LESS by extension and parser name")
    func testPluginRegistration() throws {
        let plugin = CSSPlugin()
        #expect(plugin.canFormat(filePath: "styles.css", parserName: nil))
        #expect(plugin.canFormat(filePath: "main.scss", parserName: nil))
        #expect(plugin.canFormat(filePath: "theme.less", parserName: nil))
        #expect(plugin.canFormat(filePath: nil, parserName: "css"))
        #expect(plugin.canFormat(filePath: nil, parserName: "scss"))
        #expect(!plugin.canFormat(filePath: "index.html", parserName: nil))
    }
}
