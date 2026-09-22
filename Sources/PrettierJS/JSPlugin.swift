import Foundation
import PrettierCore
import PrettierDoc

public struct JSPlugin: LanguagePlugin {
    public let name = "javascript"
    public let fileExtensions = ["js", "jsx", "mjs", "cjs", "ts", "tsx", "mts", "cts"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["javascript", "js", "typescript", "ts", "babel"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatJS(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(JSPlugin())
    }
}
