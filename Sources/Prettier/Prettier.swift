import Foundation
@_exported import PrettierDoc
@_exported import PrettierCore
@_exported import PrettierJSON
@_exported import PrettierYAML
@_exported import PrettierMarkdown
@_exported import PrettierCSS
@_exported import PrettierHTML
@_exported import PrettierJS
@_exported import PrettierGraphQL
@_exported import PrettierConfig

public enum Prettier {
    private static let pluginInitLock = NSLock()
    nonisolated(unsafe) private static var isInitialized = false

    public static func initializeDefaultPlugins() {
        pluginInitLock.lock()
        defer { pluginInitLock.unlock() }

        guard !isInitialized else { return }
        JSONPlugin.register()
        YAMLPlugin.register()
        MarkdownPlugin.register()
        CSSPlugin.register()
        HTMLPlugin.register()
        JSPlugin.register()
        GraphQLPlugin.register()
        isInitialized = true
    }

    public static func format(
        _ text: String,
        filepath: String? = nil,
        parser: String? = nil,
        options: PrintOptions = PrintOptions()
    ) throws -> String {
        initializeDefaultPlugins()
        return try PluginRegistry.shared.format(
            source: text,
            filePath: filepath,
            parserName: parser,
            options: options
        )
    }

    public static func check(
        _ text: String,
        filepath: String? = nil,
        parser: String? = nil,
        options: PrintOptions = PrintOptions()
    ) throws -> Bool {
        let formatted = try format(text, filepath: filepath, parser: parser, options: options)
        return formatted == text
    }
}
