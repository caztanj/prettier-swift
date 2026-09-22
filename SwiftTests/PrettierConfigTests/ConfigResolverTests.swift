import Foundation
import Testing
@testable import PrettierConfig
@testable import PrettierDoc

@Suite("PrettierConfig Resolver Tests")
struct ConfigResolverTests {

    @Test("Parse JSON dictionary config")
    func testParseJSONConfig() {
        let dict: [String: Any] = [
            "printWidth": 100,
            "tabWidth": 4,
            "useTabs": true,
            "semi": false,
            "singleQuote": true,
            "bracketSpacing": false
        ]
        let options = ConfigResolver.parseConfigDictionary(dict)
        #expect(options.printWidth == 100)
        #expect(options.tabWidth == 4)
        #expect(options.useTabs == true)
        #expect(options.semi == false)
        #expect(options.singleQuote == true)
        #expect(options.bracketSpacing == false)
    }

    @Test("Parse JSON .prettierrc file")
    func testLoadJSONConfigFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent(".prettierrc")
        let jsonContent = """
        {
          "tabWidth": 4,
          "semi": false,
          "singleQuote": true
        }
        """
        try jsonContent.write(to: configFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigResolver.loadConfig(from: configFile.path)
        #expect(loaded.tabWidth == 4)
        #expect(loaded.semi == false)
        #expect(loaded.singleQuote == true)
    }

    @Test("Parse YAML .prettierrc.yml file")
    func testLoadYAMLConfigFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent(".prettierrc.yml")
        let yamlContent = """
        printWidth: 120
        tabWidth: 2
        singleQuote: true
        semi: false
        """
        try yamlContent.write(to: configFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigResolver.loadConfig(from: configFile.path)
        #expect(loaded.printWidth == 120)
        #expect(loaded.tabWidth == 2)
        #expect(loaded.singleQuote == true)
        #expect(loaded.semi == false)
    }

    @Test("Parse package.json with prettier key")
    func testLoadPackageJsonConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pkgFile = tempDir.appendingPathComponent("package.json")
        let pkgContent = """
        {
          "name": "my-app",
          "prettier": {
            "semi": false,
            "tabWidth": 4
          }
        }
        """
        try pkgContent.write(to: pkgFile, atomically: true, encoding: .utf8)

        let loaded = try ConfigResolver.loadConfig(from: pkgFile.path)
        #expect(loaded.semi == false)
        #expect(loaded.tabWidth == 4)
    }

    @Test("Find config file upward traversal")
    func testFindConfigFile() throws {
        let rootTemp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let subDir = rootTemp.appendingPathComponent("src").appendingPathComponent("components")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootTemp) }

        let configFile = rootTemp.appendingPathComponent(".prettierrc.json")
        try "{}".write(to: configFile, atomically: true, encoding: .utf8)

        let found = ConfigResolver.findConfigFile(startingFrom: subDir.path)
        #expect(found == configFile.path)
    }
}
