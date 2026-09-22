import Testing
@testable import PrettierGraphQL
@testable import PrettierCore
@testable import PrettierDoc

typealias Comment = PrettierCore.Comment

@Suite("PrettierGraphQL Formatting Tests")
struct GraphQLPrinterTests {

    @Test("Format operation with variables and arguments")
    func testOperationWithVariables() throws {
        let input = """
        query GetUser ( $id: ID! ) {
        user ( id: $id ) {
        id
        name
        email
        }
        }
        """
        let formatted = try formatGraphQL(input)
        let expected = """
        query GetUser($id: ID!) {
          user(id: $id) {
            id
            name
            email
          }
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format shorthand query")
    func testShorthandQuery() throws {
        let input = """
        {
        hero {
        name
        }
        }
        """
        let formatted = try formatGraphQL(input)
        let expected = """
        {
          hero {
            name
          }
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format fragments and spreads")
    func testFragments() throws {
        let input = """
        fragment UserFields on User {
        id
        name
        }
        """
        let formatted = try formatGraphQL(input)
        let expected = """
        fragment UserFields on User {
          id
          name
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format type definition")
    func testTypeDefinition() throws {
        let input = """
        type User {
        id: ID!
        name: String
        }
        """
        let formatted = try formatGraphQL(input)
        let expected = """
        type User {
          id: ID!
          name: String
        }

        """
        #expect(formatted == expected)
    }

    @Test("Format GraphQL comments")
    func testGraphQLComments() throws {
        let input = """
        # Get active user
        query GetUser {
          user {
            id
          }
        }
        """
        let formatted = try formatGraphQL(input)
        let expected = """
        # Get active user
        query GetUser {
          user {
            id
          }
        }

        """
        #expect(formatted == expected)
    }

    @Test("Plugin can format GraphQL by extension and parser name")
    func testPluginRegistration() throws {
        let plugin = GraphQLPlugin()
        #expect(plugin.canFormat(filePath: "query.graphql", parserName: nil))
        #expect(plugin.canFormat(filePath: "schema.gql", parserName: nil))
        #expect(plugin.canFormat(filePath: nil, parserName: "graphql"))
        #expect(plugin.canFormat(filePath: nil, parserName: "gql"))
        #expect(!plugin.canFormat(filePath: "script.js", parserName: nil))
    }
}
