import Foundation
import PrettierCore
import PrettierDoc

public struct YAMLPlugin: LanguagePlugin {
    public let name = "yaml"
    public let fileExtensions = ["yml", "yaml"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["yaml", "yml"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatYAML(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(YAMLPlugin())
    }
}
