import Foundation
import PrettierCore
import PrettierDoc

public struct JSONPlugin: LanguagePlugin {
    public let name = "json"
    public let fileExtensions = ["json", "jsonc", "json5"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["json", "jsonc", "json5", "json-stringify"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatJSON(source, options: options)
    }

    public func format(source: String, filePath: String?, parserName: String?, options: PrintOptions) throws -> String {
        let isStringify: Bool = {
            if let parserName, parserName.lowercased() == "json-stringify" {
                return true
            }
            if let filePath {
                let filename = URL(fileURLWithPath: filePath).lastPathComponent.lowercased()
                if ["package.json", "package-lock.json", "composer.json"].contains(filename) {
                    return true
                }
            }
            return false
        }()
        return try formatJSON(source, options: options, isJSONStringify: isStringify)
    }

    public static func register() {
        PluginRegistry.shared.register(JSONPlugin())
    }
}
