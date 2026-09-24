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

    @Test("Format default, combined, namespace, and type imports")
    func testDefaultAndCombinedImports() throws {
        let input = """
        import React from "react";
        import Component, { useState } from "react";
        import * as Path from "path";
        import type { FC } from "react";
        import "./styles.css";
        """
        let formatted = try formatJS(input)
        let expected = """
        import React from "react";
        import Component, { useState } from "react";
        import * as Path from "path";
        import type { FC } from "react";
        import "./styles.css";

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

    @Test("Format functions with TypeScript annotations")
    func testFunctionTypeAnnotations() throws {
        let input = """
        function calculate(total: number, factor: number = 1, ...extra: any[]): number {
            return total * factor;
        }
        """
        let formatted = try formatJS(input)
        #expect(formatted.contains("calculate"))
        #expect(formatted.contains("total: number"))
        #expect(formatted.contains(": number {"))
    }

    @Test("Format arrow functions with TypeScript type annotations")
    func testArrowFunctionTypeAnnotations() throws {
        let input = """
        const validateInput = (value: string | null) => {
            return true;
        };
        """
        let formatted = try formatJS(input)
        #expect(formatted.contains("(value: string | null) => {"))

        let asyncInput = """
        const checkVersion = async (version: string): Promise<boolean> => {
            return true;
        };
        """
        let asyncFormatted = try formatJS(asyncInput)
        #expect(asyncFormatted.contains("async (version: string): Promise<boolean> => {"))
    }

    @Test("Preserve blank lines between statements and inside function blocks")
    func testPreserveBlankLines() throws {
        let input = """
        import React from "react";

        const a = 1;
        const b = 2;

        function demo() {
            const x = 10;

            return x;
        }

        export default demo;
        """
        let formatted = try formatJS(input)
        #expect(formatted == """
        import React from "react";

        const a = 1;
        const b = 2;

        function demo() {
          const x = 10;

          return x;
        }

        export default demo;

        """)
    }

    @Test("Format export statements")
    func testExportStatements() throws {
        let input = """
        export default function App() {
          return 42;
        }

        export { a, b, c as d };
        export { x, y } from "./module";
        export * from "./module";
        export type { User } from "./types";
        """
        let formatted = try formatJS(input)
        let expected = """
        export default function App() {
          return 42;
        }

        export { a, b, c as d };
        export { x, y } from "./module";
        export * from "./module";
        export type { User } from "./types";

        """
        #expect(formatted == expected)
    }

    @Test("Format TypeScript type alias and interface declarations")
    func testTypeScriptDeclarations() throws {
        let input = """
        type ID = string | number;

        interface User {
          id: ID;
          name: string;
        }
        """
        let formatted = try formatJS(input)
        let expected = """
        type ID = string | number;

        interface User {
          id: ID;
          name: string;
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format variable declarations with type annotations and destructuring")
    func testVariableTypesAndDestructuring() throws {
        let input = """
        const count: number = 0;
        let user: User | null = null;
        const { id, name } = user;
        const [first, second] = items;
        """
        let formatted = try formatJS(input)
        let expected = """
        const count: number = 0;
        let user: User | null = null;
        const { id, name } = user;
        const [first, second] = items;

        """
        #expect(formatted == expected)
    }

    @Test("Format control flow statements: while, for, try-catch-finally, throw")
    func testControlFlowStatements() throws {
        let input = """
        while (active) {
          doWork();
        }

        for (let i = 0; i < 10; i++) {
          total += i;
        }

        try {
          risky();
        } catch (err) {
          handle(err);
        } finally {
          cleanup();
        }

        throw new Error("Failed");
        """
        let formatted = try formatJS(input)
        let expected = """
        while (active) {
          doWork();
        }

        for (let i = 0; i < 10; i++) {
          total += i;
        }

        try {
          risky();
        } catch (err) {
          handle(err);
        } finally {
          cleanup();
        }

        throw new Error("Failed");

        """
        #expect(formatted == expected)
    }

    @Test("Format await, new, and typeof expressions")
    func testUnaryAndAwaitNewExpressions() throws {
        let input = """
        const res = await fetchData();
        const client = new Client("url");
        const isString = typeof val === "string";
        """
        let formatted = try formatJS(input)
        let expected = """
        const res = await fetchData();
        const client = new Client("url");
        const isString = typeof val === "string";

        """
        #expect(formatted == expected)
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
