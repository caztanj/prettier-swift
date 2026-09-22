import Testing
@testable import PrettierJSON
@testable import PrettierDoc
@testable import PrettierCore

@Suite("PrettierJSON Formatting Tests")
struct JSONPrinterTests {
    @Test("Format simple JSON primitives")
    func simplePrimitives() throws {
        #expect(try formatJSON("true") == "true\n")
        #expect(try formatJSON("false") == "false\n")
        #expect(try formatJSON("null") == "null\n")
        #expect(try formatJSON("123.45") == "123.45\n")
        #expect(try formatJSON("\"hello world\"") == "\"hello world\"\n")
    }

    @Test("Format objects with indentation")
    func formatObject() throws {
        let input = "{\"name\":\"prettier\",\"fast\":true,\"count\":42}"
        let expected = """
        {
          "name": "prettier",
          "fast": true,
          "count": 42
        }

        """
        let actual = try formatJSON(input, options: PrintOptions(printWidth: 20, tabWidth: 2))
        #expect(actual == expected)
    }

    @Test("Format arrays with indentation")
    func formatArray() throws {
        let input = "[1,2,3,4]"
        let expected = """
        [
          1,
          2,
          3,
          4
        ]

        """
        let actual = try formatJSON(input, options: PrintOptions(printWidth: 5, tabWidth: 2))
        #expect(actual == expected)
    }

    @Test("Format nested structures")
    func formatNested() throws {
        let input = "{\"items\":[{\"id\":1},{\"id\":2}]}"
        let expected = """
        {
          "items": [
            {
              "id": 1
            },
            { "id": 2 }
          ]
        }

        """
        let actual = try formatJSON(input, options: PrintOptions(printWidth: 15, tabWidth: 2))
        #expect(actual == expected)
    }

    @Test("Format JSONC with comments matching Prettier")
    func formatWithComments() throws {
        let input = """
        {
          // leading comment
          "key": "value" // trailing comment
        }
        """

        let formatted = try formatJSON(input, options: PrintOptions(tabWidth: 2))
        #expect(formatted.contains("// leading comment"))
        #expect(formatted.contains("// trailing comment"))
        #expect(formatted.contains("\"key\": \"value\""))
    }

    @Test("Format empty object and empty array")
    func formatEmpty() throws {
        #expect(try formatJSON("{}") == "{}\n")
        #expect(try formatJSON("[]") == "[]\n")
    }
}
