import Testing
import Foundation
@testable import Prettier

@Suite("Prettier Umbrella Library Tests")
struct PrettierTests {

    @Test("Prettier.format with explicit parser")
    func testFormatWithExplicitParser() throws {
        let input = "{\"hello\":   \"world\"}"
        let formatted = try Prettier.format(input, parser: "json")
        let expected = "{ \"hello\": \"world\" }\n"
        #expect(formatted == expected)
    }

    @Test("Prettier.format inferred from filepath")
    func testFormatWithFilepath() throws {
        let input = "query   { user { id   name } }"
        let formatted = try Prettier.format(input, filepath: "query.graphql")
        let expected = """
        {
          user {
            id
            name
          }
        }

        """
        #expect(formatted == expected)
    }

    @Test("Prettier.check returns true for formatted and false for unformatted")
    func testCheck() throws {
        let unformatted = "let a=1;"
        let isFormattedBefore = try Prettier.check(unformatted, parser: "javascript")
        #expect(!isFormattedBefore)

        let formatted = try Prettier.format(unformatted, parser: "javascript")
        let isFormattedAfter = try Prettier.check(formatted, parser: "javascript")
        #expect(isFormattedAfter)
    }

    @Test("Prettier.format throws on unknown parser")
    func testThrowsOnUnknownParser() {
        #expect(throws: FormatError.self) {
            _ = try Prettier.format("content", parser: "nonexistent_parser")
        }
    }
}
