import Testing
@testable import PrettierJS
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

@Suite("PrettierJS Formatting Tests")
struct JSPrinterTests {

    @Test("Format variable declarations and semicolons")
    func testVariableDeclarations() throws {
        let input = """
        const x=10;
        let   message  =  "hello"
        """
        let formatted = try formatJS(input)
        let expected = """
        const x = 10;
        let message = "hello";

        """
        #expect(formatted == expected)
    }

    @Test("Format function declarations and blocks")
    func testFunctionDeclarations() throws {
        let input = """
        function add(a,b){
        return a+b;
        }
        """
        let formatted = try formatJS(input)
        let expected = """
        function add(a, b) {
          return a + b;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format arrow functions")
    func testArrowFunctions() throws {
        let input = """
        const double = (x) => x * 2;
        """
        let formatted = try formatJS(input)
        let expected = """
        const double = (x) => x * 2;

        """
        #expect(formatted == expected)
    }

    @Test("Format objects with bracket spacing")
    func testObjectExpression() throws {
        let input = """
        const user = {name:"Alice",age:30,role};
        """
        let formatted = try formatJS(input)
        let expected = """
        const user = { name: "Alice", age: 30, role };

        """
        #expect(formatted == expected)
    }

    @Test("Format arrays")
    func testArrayExpression() throws {
        let input = """
        const items = [1,2,  3,4];
        """
        let formatted = try formatJS(input)
        let expected = """
        const items = [1, 2, 3, 4];

        """
        #expect(formatted == expected)
    }

    @Test("Format import and export statements")
    func testImportExport() throws {
        let input = """
        import { readFile, writeFile } from "fs";
        export const version = "1.0.0";
        """
        let formatted = try formatJS(input)
        let expected = """
        import { readFile, writeFile } from "fs";
        export const version = "1.0.0";

        """
        #expect(formatted == expected)
    }

    @Test("Format with singleQuote option")
    func testSingleQuoteOption() throws {
        let input = """
        const msg = "world";
        """
        var options = PrintOptions()
        options.singleQuote = true
        let formatted = try formatJS(input, options: options)
        let expected = """
        const msg = 'world';

        """
        #expect(formatted == expected)
    }

    @Test("Format with semi = false option")
    func testSemiFalseOption() throws {
        let input = """
        const x = 1;
        """
        var options = PrintOptions()
        options.semi = false
        let formatted = try formatJS(input, options: options)
        let expected = """
        const x = 1

        """
        #expect(formatted == expected)
    }

    @Test("Format JavaScript comments")
    func testComments() throws {
        let input = """
        // Leading comment
        const active = true;
        """
        let formatted = try formatJS(input)
        let expected = """
        // Leading comment
        const active = true;

        """
        #expect(formatted == expected)
    }

    @Test("Format objects with spread and string keys")
    func testObjectSpreadAndStringKeys() throws {
        let input = """
        const state = { ...prev, "status": "active" };
        """
        let formatted = try formatJS(input)
        #expect(formatted.contains("..."))
        #expect(formatted.contains("\"status\": \"active\""))
    }

    @Test("Plugin can format JS/TS by extension and parser name")
    func testPluginRegistration() throws {
        let plugin = JSPlugin()
        #expect(plugin.canFormat(filePath: "index.js", parserName: nil))
        #expect(plugin.canFormat(filePath: "app.ts", parserName: nil))
        #expect(plugin.canFormat(filePath: "component.tsx", parserName: nil))
        #expect(plugin.canFormat(filePath: "view.jsx", parserName: nil))
        #expect(plugin.canFormat(filePath: nil, parserName: "javascript"))
        #expect(plugin.canFormat(filePath: nil, parserName: "typescript"))
        #expect(!plugin.canFormat(filePath: "styles.css", parserName: nil))
    }
}
