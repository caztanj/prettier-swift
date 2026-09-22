import Foundation
import PrettierCore
import PrettierDoc

public struct CSSPlugin: LanguagePlugin {
    public let name = "css"
    public let fileExtensions = ["css", "scss", "less"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["css", "scss", "less"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatCSS(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(CSSPlugin())
    }
}
