import Foundation
import Dispatch
import Darwin
import Prettier

Prettier.initializeDefaultPlugins()

struct CLIConfig {
    var write: Bool = false
    var check: Bool = false
    var printWidth: Int? = nil
    var tabWidth: Int? = nil
    var useTabs: Bool? = nil
    var semi: Bool? = nil
    var singleQuote: Bool? = nil
    var parser: String? = nil
    var stdinFilePath: String? = nil
    var configFile: String? = nil
    var ignorePath: String? = nil
    var files: [String] = []
}

func printUsage() {
    print("""
    Usage: prettier-swift [options] [file/dir/glob ...]

    Output options:
      -c, --check              Check if files are formatted.
      -w, --write              Edit files in-place.

    Format options:
      --config <path>          Path to a configuration file (.prettierrc, package.json).
      --ignore-path <path>     Path to an ignore file (default: .prettierignore).
      --print-width <int>      The line length that the printer will wrap on. (default: 80)
      --tab-width <int>        Number of spaces per indentation level. (default: 2)
      --use-tabs               Indent lines with tabs instead of spaces. (default: false)
      --no-semi                Do not print semicolons, except at the beginning of lines.
      --single-quote           Use single quotes instead of double quotes.
      --parser <name>          Which parser to use. (e.g. json, jsonc, javascript, html)
      --stdin-filepath <path>  Path to the file to pretend that stdin comes from.

    Other options:
      -h, --help               Show CLI usage, or details about the given flag.
      -v, --version            Print prettier-swift version.
    """)
}

func run() -> Int32 {
    var config = CLIConfig()
    let args = Array(CommandLine.arguments.dropFirst())

    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-h", "--help":
            printUsage()
            return 0
        case "-v", "--version":
            print("prettier-swift 0.1.0")
            return 0
        case "-w", "--write":
            config.write = true
        case "-c", "--check":
            config.check = true
        case "--use-tabs":
            config.useTabs = true
        case "--semi":
            config.semi = true
        case "--no-semi":
            config.semi = false
        case "--single-quote":
            config.singleQuote = true
        case "--config":
            i += 1
            if i < args.count {
                config.configFile = args[i]
            }
        case "--ignore-path":
            i += 1
            if i < args.count {
                config.ignorePath = args[i]
            }
        case "--print-width":
            i += 1
            if i < args.count, let val = Int(args[i]) {
                config.printWidth = val
            }
        case "--tab-width":
            i += 1
            if i < args.count, let val = Int(args[i]) {
                config.tabWidth = val
            }
        case "--parser":
            i += 1
            if i < args.count {
                config.parser = args[i]
            }
        case "--stdin-filepath":
            i += 1
            if i < args.count {
                config.stdinFilePath = args[i]
            }
        default:
            if arg.hasPrefix("-") {
                fputs("Unknown option: \(arg)\n", stderr)
                printUsage()
                return 1
            }
            config.files.append(arg)
        }
        i += 1
    }

    let activeConfig = config
    let ignoreManager = IgnoreManager.load(from: activeConfig.ignorePath)

    @Sendable func resolveEffectiveOptions(for filePath: String?) -> PrintOptions {
        var opts: PrintOptions
        if let customConfig = activeConfig.configFile {
            opts = (try? ConfigResolver.loadConfig(from: customConfig)) ?? PrintOptions()
        } else if let filePath, let resolved = try? ConfigResolver.resolveConfig(for: filePath) {
            opts = resolved
        } else if let currentResolved = try? ConfigResolver.resolveConfig(for: FileManager.default.currentDirectoryPath) {
            opts = currentResolved
        } else {
            opts = PrintOptions()
        }

        if let pw = activeConfig.printWidth { opts.printWidth = pw }
        if let tw = activeConfig.tabWidth { opts.tabWidth = tw }
        if let ut = activeConfig.useTabs { opts.useTabs = ut }
        if let sm = activeConfig.semi { opts.semi = sm }
        if let sq = activeConfig.singleQuote { opts.singleQuote = sq }
        return opts
    }

    func collectFiles(from inputPaths: [String]) -> [String] {
        var result: [String] = []
        let fm = FileManager.default

        for path in inputPaths {
            if ignoreManager.isIgnored(filePath: path) {
                continue
            }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let enumerator = fm.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            let filePath = fileURL.path
                            if ignoreManager.isIgnored(filePath: filePath) {
                                enumerator.skipDescendants()
                                continue
                            }
                            if PluginRegistry.shared.findPlugin(filePath: filePath, parserName: config.parser) != nil {
                                result.append(filePath)
                            }
                        }
                    }
                } else {
                    result.append(path)
                }
            }
        }
        return result
    }

    if config.files.isEmpty {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let inputString = String(data: data, encoding: .utf8) else {
            fputs("Error: Could not decode stdin as UTF-8\n", stderr)
            return 1
        }
        let effectiveOptions = resolveEffectiveOptions(for: config.stdinFilePath)
        do {
            let formatted = try PluginRegistry.shared.format(
                source: inputString,
                filePath: config.stdinFilePath,
                parserName: config.parser,
                options: effectiveOptions
            )
            print(formatted, terminator: "")
            return 0
        } catch {
            fputs("\(error)\n", stderr)
            return 1
        }
    }

    @Sendable func readFileOptimized(at filePath: String) throws -> String {
        let fd = open(filePath, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }

        var st = stat()
        guard fstat(fd, &st) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let fileSize = Int(st.st_size)
        if fileSize == 0 { return "" }

        let memoryMapThresholdBytes = 16384
        if fileSize >= memoryMapThresholdBytes {
            if let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
                defer { munmap(mapped, fileSize) }
                let buffer = UnsafeBufferPointer(start: mapped.assumingMemoryBound(to: UInt8.self), count: fileSize)
                return String(decoding: buffer, as: UTF8.self)
            }
        }

        var bytes = [UInt8](repeating: 0, count: fileSize)
        let readBytes = bytes.withUnsafeMutableBufferPointer { ptr in
            read(fd, ptr.baseAddress!, fileSize)
        }
        guard readBytes == fileSize else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    @Sendable func writeFileOptimized(at filePath: String, content: String) throws {
        let url = URL(fileURLWithPath: filePath)
        let data = Data(content.utf8)
        try data.write(to: url, options: .atomic)
    }

    let targetFiles = collectFiles(from: activeConfig.files)
    guard !targetFiles.isEmpty else { return 0 }

    struct ProcessResult: @unchecked Sendable {
        var filePath: String
        var formatted: String?
        var changed: Bool
        var error: String?
    }

    final class ResultCollector: @unchecked Sendable {
        private let lock = NSLock()
        var results: [ProcessResult?]

        init(count: Int) {
            self.results = [ProcessResult?](repeating: nil, count: count)
        }

        func set(_ result: ProcessResult, at index: Int) {
            lock.lock()
            defer { lock.unlock() }
            results[index] = result
        }
    }

    let collector = ResultCollector(count: targetFiles.count)

    @Sendable func processSingleFile(index: Int) {
        let filePath = targetFiles[index]
        let effectiveOptions = resolveEffectiveOptions(for: filePath)
        do {
            let source = try readFileOptimized(at: filePath)
            let formatted = try PluginRegistry.shared.format(
                source: source,
                filePath: filePath,
                parserName: activeConfig.parser,
                options: effectiveOptions
            )
            let changed = formatted != source
            if activeConfig.write && changed {
                try writeFileOptimized(at: filePath, content: formatted)
            }
            collector.set(ProcessResult(filePath: filePath, formatted: formatted, changed: changed, error: nil), at: index)
        } catch {
            collector.set(ProcessResult(filePath: filePath, formatted: nil, changed: false, error: "\(error)"), at: index)
        }
    }

    if targetFiles.count == 1 {
        processSingleFile(index: 0)
    } else {
        DispatchQueue.concurrentPerform(iterations: targetFiles.count) { index in
            processSingleFile(index: index)
        }
    }

    var hasUnformatted = false
    for res in collector.results.compactMap({ $0 }) {
        if let err = res.error {
            fputs("Error processing \(res.filePath): \(err)\n", stderr)
            hasUnformatted = true
            continue
        }

        if activeConfig.check {
            if res.changed {
                print("[warn] \(res.filePath)")
                hasUnformatted = true
            }
        } else if activeConfig.write {
            if res.changed {
                print("\(res.filePath)")
            }
        } else if let formatted = res.formatted {
            print(formatted, terminator: "")
        }
    }

    if activeConfig.check {
        if hasUnformatted {
            print("[warn] Code style issues found in the above file(s). Forgot to run Prettier?")
            return 1
        } else {
            print("All matched files use Prettier code style!")
            return 0
        }
    }

    return 0
}

exit(run())
