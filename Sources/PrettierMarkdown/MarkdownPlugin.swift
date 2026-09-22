import Foundation
import PrettierCore
import PrettierDoc

public struct MarkdownPlugin: LanguagePlugin {
    public let name = "markdown"
    public let fileExtensions = ["md", "markdown", "mdown", "mkdn", "mkd"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["markdown", "md"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatMarkdown(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(MarkdownPlugin())
    }
}
