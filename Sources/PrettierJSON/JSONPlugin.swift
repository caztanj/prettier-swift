import Foundation
import PrettierCore
import PrettierDoc

public struct JSONPlugin: LanguagePlugin {
    public let name = "json"
    public let fileExtensions = ["json", "jsonc", "json5"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["json", "jsonc", "json5"].contains(parserName.lowercased()) {
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

    public static func register() {
        PluginRegistry.shared.register(JSONPlugin())
    }
}
