import Foundation
import PrettierDoc

public enum FormatError: Error, CustomStringConvertible {
    case unsupportedLanguage(filePath: String?, parser: String?)

    public var description: String {
        switch self {
        case .unsupportedLanguage(let filePath, let parser):
            if let parser {
                return "No parser could be inferred or found for '\(parser)'."
            }
            if let filePath {
                return "No parser could be inferred for file: \(filePath)."
            }
            return "No parser specified and could not infer parser."
        }
    }
}

public protocol LanguagePlugin: Sendable {
    var name: String { get }
    var fileExtensions: [String] { get }
    func canFormat(filePath: String?, parserName: String?) -> Bool
    func format(source: String, options: PrintOptions) throws -> String
}

public final class PluginRegistry: @unchecked Sendable {
    public static let shared = PluginRegistry()

    private var plugins: [any LanguagePlugin] = []

    public init() {}

    public func register(_ plugin: any LanguagePlugin) {
        plugins.append(plugin)
    }

    public func findPlugin(filePath: String?, parserName: String?) -> (any LanguagePlugin)? {
        for plugin in plugins {
            if plugin.canFormat(filePath: filePath, parserName: parserName) {
                return plugin
            }
        }
        return nil
    }

    public func format(
        source: String,
        filePath: String? = nil,
        parserName: String? = nil,
        options: PrintOptions = PrintOptions()
    ) throws -> String {
        guard let plugin = findPlugin(filePath: filePath, parserName: parserName) else {
            throw FormatError.unsupportedLanguage(filePath: filePath, parser: parserName)
        }
        return try plugin.format(source: source, options: options)
    }
}
