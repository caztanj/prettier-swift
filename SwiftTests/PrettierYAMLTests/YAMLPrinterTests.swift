import Testing
@testable import PrettierYAML
@testable import PrettierDoc
@testable import PrettierCore

@Suite("PrettierYAML Formatting Tests")
struct YAMLPrinterTests {
    @Test("Format simple YAML mapping")
    func simpleMapping() throws {
        let input = """
        name: prettier
        version: 1.0.0
        fast: true
        """
        let expected = """
        name: prettier
        version: 1.0.0
        fast: true

        """
        let output = try formatYAML(input)
        #expect(output == expected)
    }

    @Test("Format nested mapping with 2 spaces indent")
    func nestedMapping() throws {
        let input = """
        server:
          port: 8080
          host: localhost
        """
        let expected = """
        server:
          port: 8080
          host: localhost

        """
        let output = try formatYAML(input)
        #expect(output == expected)
    }

    @Test("Format sequence of items")
    func sequenceItems() throws {
        let input = """
        - apple
        - banana
        - cherry
        """
        let expected = """
        - apple
        - banana
        - cherry

        """
        let output = try formatYAML(input)
        #expect(output == expected)
    }

    @Test("Format document with header")
    func documentWithHeader() throws {
        let input = """
        ---
        title: document
        """
        let expected = """
        ---
        title: document

        """
        let output = try formatYAML(input)
        #expect(output == expected)
    }

    @Test("Format through PluginRegistry by file extension")
    func pluginRegistryFormatting() throws {
        YAMLPlugin.register()
        let input = "key: value"
        let output = try PluginRegistry.shared.format(source: input, filePath: "config.yaml")
        #expect(output == "key: value\n")
    }
}
