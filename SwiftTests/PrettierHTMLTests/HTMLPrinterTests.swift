import Testing
@testable import PrettierHTML
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

@Suite("PrettierHTML Formatting Tests")
struct HTMLPrinterTests {

    @Test("Format simple HTML page with doctype and nested tags")
    func testSimplePage() throws {
        let input = """
        <!doctype html>
        <html>
        <head>
        <title>Test Page</title>
        </head>
        <body>
        <h1>Hello World</h1>
        </body>
        </html>
        """
        let formatted = try formatHTML(input)
        let expected = """
        <!doctype html>
        <html>
          <head>
            <title>Test Page</title>
          </head>
          <body>
            <h1>Hello World</h1>
          </body>
        </html>

        """
        #expect(formatted == expected)
    }

    @Test("Format attributes and void elements")
    func testAttributesAndVoidElements() throws {
        let input = """
        <div id="container"   class="wrapper" >
        <img   src="logo.png"  alt="Logo" >
        <input type="text" disabled >
        </div>
        """
        let formatted = try formatHTML(input)
        let expected = """
        <div id="container" class="wrapper">
          <img src="logo.png" alt="Logo">
          <input type="text" disabled>
        </div>

        """
        #expect(formatted == expected)
    }

    @Test("Format HTML comments")
    func testHTMLComments() throws {
        let input = """
        <!-- Main application root -->
        <div id="app">
          <p>Loaded</p>
        </div>
        """
        let formatted = try formatHTML(input)
        let expected = """
        <!-- Main application root -->
        <div id="app">
          <p>Loaded</p>
        </div>

        """
        #expect(formatted == expected)
    }

    @Test("Format self-closing tags")
    func testSelfClosingTags() throws {
        let input = """
        <svg>
        <circle cx="50" cy="50" r="40" />
        </svg>
        """
        let formatted = try formatHTML(input)
        let expected = """
        <svg>
          <circle cx="50" cy="50" r="40" />
        </svg>

        """
        #expect(formatted == expected)
    }

    @Test("Plugin can format HTML by extension and parser name")
    func testPluginRegistration() throws {
        let plugin = HTMLPlugin()
        #expect(plugin.canFormat(filePath: "index.html", parserName: nil))
        #expect(plugin.canFormat(filePath: "page.htm", parserName: nil))
        #expect(plugin.canFormat(filePath: "doc.xhtml", parserName: nil))
        #expect(plugin.canFormat(filePath: nil, parserName: "html"))
        #expect(!plugin.canFormat(filePath: "main.swift", parserName: nil))
    }
}
