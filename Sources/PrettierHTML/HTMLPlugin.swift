import Foundation
import PrettierCore
import PrettierDoc

public struct HTMLPlugin: LanguagePlugin {
    public let name = "html"
    public let fileExtensions = ["html", "htm", "xhtml"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["html", "htm"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatHTML(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(HTMLPlugin())
    }
}
