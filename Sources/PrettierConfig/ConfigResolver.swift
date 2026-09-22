import Foundation
import PrettierDoc
import PrettierCore
import PrettierJSON
import PrettierYAML

public struct ConfigResolver {
    public static let supportedConfigFiles = [
        ".prettierrc",
        ".prettierrc.json",
        ".prettierrc.yaml",
        ".prettierrc.yml",
        "package.json"
    ]

    public static func findConfigFile(startingFrom path: String) -> String? {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path).standardized

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: currentURL.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
            currentURL = currentURL.deletingLastPathComponent()
        }

        while true {
            for configFile in supportedConfigFiles {
                let candidateURL = currentURL.appendingPathComponent(configFile)
                if fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL.path
                }
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                break
            }
            currentURL = parentURL
        }

        return nil
    }

    public static func resolveConfig(for filePath: String) throws -> PrintOptions? {
        guard let configPath = findConfigFile(startingFrom: filePath) else {
            return nil
        }
        return try loadConfig(from: configPath)
    }

    public static func loadConfig(from configPath: String) throws -> PrintOptions {
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        let filename = (configPath as NSString).lastPathComponent

        if filename == "package.json" {
            guard let data = content.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let prettierDict = json["prettier"] as? [String: Any] else {
                return PrintOptions()
            }
            return parseConfigDictionary(prettierDict)
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            guard let data = content.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return PrintOptions()
            }
            return parseConfigDictionary(json)
        } else {
            return parseSimpleYAMLConfig(content)
        }
    }

    public static func parseConfigDictionary(_ dict: [String: Any]) -> PrintOptions {
        var options = PrintOptions()

        if let printWidth = dict["printWidth"] as? Int {
            options.printWidth = printWidth
        }
        if let tabWidth = dict["tabWidth"] as? Int {
            options.tabWidth = tabWidth
        }
        if let useTabs = dict["useTabs"] as? Bool {
            options.useTabs = useTabs
        }
        if let semi = dict["semi"] as? Bool {
            options.semi = semi
        }
        if let singleQuote = dict["singleQuote"] as? Bool {
            options.singleQuote = singleQuote
        }
        if let bracketSpacing = dict["bracketSpacing"] as? Bool {
            options.bracketSpacing = bracketSpacing
        }
        if let endOfLine = dict["endOfLine"] as? String {
            switch endOfLine.lowercased() {
            case "crlf": options.endOfLine = .crlf
            case "cr": options.endOfLine = .cr
            default: options.endOfLine = .lf
            }
        }

        return options
    }

    private static func parseSimpleYAMLConfig(_ yaml: String) -> PrintOptions {
        var dict: [String: Any] = [:]
        let lines = yaml.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let valStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if valStr == "true" {
                    dict[key] = true
                } else if valStr == "false" {
                    dict[key] = false
                } else if let intVal = Int(valStr) {
                    dict[key] = intVal
                } else {
                    var cleanStr = valStr
                    if (cleanStr.hasPrefix("\"") && cleanStr.hasSuffix("\"")) || (cleanStr.hasPrefix("'") && cleanStr.hasSuffix("'")) {
                        cleanStr.removeFirst()
                        cleanStr.removeLast()
                    }
                    dict[key] = cleanStr
                }
            }
        }
        return parseConfigDictionary(dict)
    }
}
