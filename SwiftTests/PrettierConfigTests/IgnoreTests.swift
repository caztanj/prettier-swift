import Foundation
import Testing
@testable import PrettierConfig

@Suite("PrettierIgnore Tests")
struct IgnoreTests {

    @Test("Default ignore patterns match node_modules and .git")
    func testDefaultIgnores() {
        let manager = IgnoreManager(rootPath: "/app")
        #expect(manager.isIgnored(filePath: "/app/node_modules/package/index.js"))
        #expect(manager.isIgnored(filePath: "/app/.git/config"))
        #expect(manager.isIgnored(filePath: "/app/.build/debug/foo.o"))
        #expect(!manager.isIgnored(filePath: "/app/src/index.js"))
    }

    @Test("Custom glob patterns in ignore manager")
    func testCustomPatterns() {
        let patterns = [
            "dist/",
            "*.min.js",
            "temp/**",
            "!dist/keep.min.js"
        ]
        let manager = IgnoreManager(patterns: patterns, rootPath: "/app")

        #expect(manager.isIgnored(filePath: "/app/dist/bundle.js"))
        #expect(manager.isIgnored(filePath: "/app/src/vendor.min.js"))
        #expect(manager.isIgnored(filePath: "/app/temp/cache/file.json"))
        #expect(!manager.isIgnored(filePath: "/app/src/main.js"))
    }

    @Test("Load from .prettierignore file")
    func testLoadFromFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ignoreFile = tempDir.appendingPathComponent(".prettierignore")
        let content = """
        # Ignore generated
        coverage/
        *.log
        """
        try content.write(to: ignoreFile, atomically: true, encoding: .utf8)

        let manager = IgnoreManager.load(from: ignoreFile.path, rootPath: tempDir.path)
        #expect(manager.isIgnored(filePath: tempDir.appendingPathComponent("coverage/report.html").path))
        #expect(manager.isIgnored(filePath: tempDir.appendingPathComponent("app.log").path))
        #expect(!manager.isIgnored(filePath: tempDir.appendingPathComponent("app.js").path))
    }
}
