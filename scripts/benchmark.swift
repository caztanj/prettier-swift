#!/usr/bin/env swift
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let repoRoot: URL
if fileManager.fileExists(atPath: currentDir.appendingPathComponent("Package.swift").path) {
    repoRoot = currentDir
} else {
    repoRoot = currentDir.deletingLastPathComponent()
}

func findSwiftBin() -> String? {
    let possiblePaths = [
        repoRoot.appendingPathComponent(".build/out/Products/Release-linux-x86_64/prettier-swift").path,
        repoRoot.appendingPathComponent(".build/out/Products/Release/prettier-swift").path,
        repoRoot.appendingPathComponent(".build/release/prettier-swift").path,
        repoRoot.appendingPathComponent(".build/arm64-apple-macosx/release/prettier-swift").path,
        repoRoot.appendingPathComponent(".build/x86_64-apple-macosx/release/prettier-swift").path,
        repoRoot.appendingPathComponent(".build/x86_64-unknown-linux-gnu/release/prettier-swift").path
    ]
    if let found = possiblePaths.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
        return found
    }
    let buildDir = repoRoot.appendingPathComponent(".build")
    if let enumerator = fileManager.enumerator(at: buildDir, includingPropertiesForKeys: [.isExecutableKey]) {
        for case let url as URL in enumerator {
            if url.lastPathComponent == "prettier-swift" &&
               url.path.lowercased().contains("release") &&
               fileManager.isExecutableFile(atPath: url.path) {
                return url.path
            }
        }
    }
    return nil
}

var swiftBin = findSwiftBin()

if swiftBin == nil {
    print("Building prettier-swift release binary...")
    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    buildProcess.arguments = ["swift", "build", "-c", "release"]
    buildProcess.currentDirectoryURL = repoRoot
    try buildProcess.run()
    buildProcess.waitUntilExit()

    swiftBin = findSwiftBin()
}

guard let swiftBinPath = swiftBin else {
    print("Error: Could not find or build prettier-swift release binary.")
    exit(1)
}

let nodeDir = fileManager.temporaryDirectory.appendingPathComponent("prettier_node_benchmark")
try? fileManager.createDirectory(at: nodeDir, withIntermediateDirectories: true)
let nodePrettierCjs = nodeDir.appendingPathComponent("node_modules/prettier/bin/prettier.cjs")

if !fileManager.fileExists(atPath: nodePrettierCjs.path) {
    print("Downloading official Prettier package from npm...")
    let npmProcess = Process()
    npmProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    npmProcess.arguments = ["npm", "install", "--no-package-lock", "--no-audit", "--no-fund", "prettier@latest"]
    npmProcess.currentDirectoryURL = nodeDir
    try npmProcess.run()
    npmProcess.waitUntilExit()
}

guard fileManager.fileExists(atPath: nodePrettierCjs.path) else {
    print("Error: Could not find downloaded Prettier binary at \(nodePrettierCjs.path)")
    exit(1)
}

var nodePath = "/usr/local/bin/node"
if !fileManager.isExecutableFile(atPath: nodePath) {
    nodePath = "/opt/homebrew/bin/node"
}
if !fileManager.isExecutableFile(atPath: nodePath) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    p.arguments = ["node"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    nodePath = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
}

guard fileManager.isExecutableFile(atPath: nodePath) else {
    print("Error: Could not find node executable.")
    exit(1)
}

func runCommand(executable: String, arguments: [String], currentDirectoryURL: URL? = nil) -> (exitCode: Int32, stdout: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let currentDirectoryURL {
        process.currentDirectoryURL = currentDirectoryURL
    }

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (-1, "")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (process.terminationStatus, output)
}

func measureBenchmark(prog: String, args: [String], iterations: Int) -> Double {
    let clock = ContinuousClock()
    let start = clock.now

    for _ in 0..<iterations {
        var pid: pid_t = 0
        var cArgs = ([prog] + args).map { strdup($0) } + [nil]
        #if canImport(Darwin)
        var fileActions: posix_spawn_file_actions_t?
        #else
        var fileActions = posix_spawn_file_actions_t()
        #endif
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addopen(&fileActions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, 2, "/dev/null", O_WRONLY, 0)

        posix_spawnp(&pid, prog, &fileActions, nil, &cArgs, environ)
        posix_spawn_file_actions_destroy(&fileActions)
        cArgs.compactMap { $0 }.forEach { free($0) }

        var status: Int32 = 0
        waitpid(pid, &status, 0)
    }

    let elapsed = clock.now - start
    let totalMs = Double(elapsed.components.seconds) * 1000.0 + Double(elapsed.components.attoseconds) / 1e15
    return totalMs / Double(iterations)
}

struct TestCase {
    let name: String
    let filename: String
    let content: String
}

let testCases: [TestCase] = [
    TestCase(
        name: "JSON",
        filename: "test.json",
        content: "{\"name\":\"prettier-swift\",\"version\":\"0.1.0\",\"private\":true,\"scripts\":{\"test\":\"swift test\",\"build\":\"swift build\"},\"dependencies\":{},\"devDependencies\":{\"prettier\":\"latest\"}}\n"
    ),
    TestCase(
        name: "YAML",
        filename: "test.yml",
        content: "name: CI\non:\n  push:\n    branches:\n      - main\njobs:\n  build:\n    runs-on: macos-latest\n"
    ),
    TestCase(
        name: "Markdown",
        filename: "test.md",
        content: "# Prettier Swift\n\nA blazing fast Prettier port written in Swift.\n\n- High performance\n- Zero runtime dependencies\n- Exact behavioral parity\n"
    ),
    TestCase(
        name: "CSS",
        filename: "test.css",
        content: "h1, h2, .title {\n  color: #333333;\n  margin: 0px 10px;\n}\n"
    ),
    TestCase(
        name: "HTML",
        filename: "test.html",
        content: "<!DOCTYPE html>\n<html>\n  <head>\n    <title>Benchmark</title>\n  </head>\n  <body>\n    <h1>Hello World</h1>\n  </body>\n</html>\n"
    ),
    TestCase(
        name: "JavaScript",
        filename: "test.js",
        content: "const calculateTotal = (items, taxRate) => {\n  return items.reduce((acc, item) => acc + item.price, 0) * (1 + taxRate);\n};\n"
    ),
    TestCase(
        name: "GraphQL",
        filename: "test.graphql",
        content: "query GetUser($id: ID!) {\n  user(id: $id) {\n    id\n    name\n    email\n  }\n}\n"
    )
]

let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer {
    try? fileManager.removeItem(at: tempDir)
}

func pad(_ string: String, to width: Int) -> String {
    if string.count >= width { return string }
    return string + String(repeating: " ", count: width - string.count)
}

print("==========================================================")
print("    prettier-swift vs Node.js prettier benchmark & parity ")
print("==========================================================")
print("")

let iterations = 5

print("| Language   | Filesize | prettier-swift | node prettier | Speedup | Parity  |")
print("|:-----------|:---------|:---------------|:--------------|:--------|:--------|")

for test in testCases {
    let fileURL = tempDir.appendingPathComponent(test.filename)
    try test.content.write(to: fileURL, atomically: true, encoding: .utf8)

    let size = "\(test.content.utf8.count)B"

    let swiftRes = runCommand(executable: swiftBinPath, arguments: [fileURL.path])
    let nodeRes = runCommand(executable: nodePath, arguments: [nodePrettierCjs.path, fileURL.path])
    let parity = (swiftRes.exitCode == 0 && nodeRes.exitCode == 0 && swiftRes.stdout == nodeRes.stdout) ? "✅ MATCH" : "⚠️ DIFF"

    let swiftMs = measureBenchmark(prog: swiftBinPath, args: [fileURL.path], iterations: iterations)
    let nodeMs = measureBenchmark(prog: nodePath, args: [nodePrettierCjs.path, fileURL.path], iterations: iterations)

    let speedup = String(format: "%.1fx", nodeMs / max(swiftMs, 0.001))
    let swiftTimeStr = String(format: "%.1fms", swiftMs)
    let nodeTimeStr = String(format: "%.1fms", nodeMs)

    let col1 = pad(test.name, to: 10)
    let col2 = pad(size, to: 8)
    let col3 = pad(swiftTimeStr, to: 14)
    let col4 = pad(nodeTimeStr, to: 13)
    let col5 = pad(speedup, to: 7)
    let col6 = pad(parity, to: 7)

    print("| \(col1) | \(col2) | \(col3) | \(col4) | \(col5) | \(col6) |")
}

print("")
print("Benchmark completed successfully.")
