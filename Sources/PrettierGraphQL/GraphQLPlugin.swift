import Foundation
import PrettierCore
import PrettierDoc

public struct GraphQLPlugin: LanguagePlugin {
    public let name = "graphql"
    public let fileExtensions = ["graphql", "gql"]

    public init() {}

    public func canFormat(filePath: String?, parserName: String?) -> Bool {
        if let parserName, ["graphql", "gql"].contains(parserName.lowercased()) {
            return true
        }
        if let filePath {
            let ext = (filePath as NSString).pathExtension.lowercased()
            return fileExtensions.contains(ext)
        }
        return false
    }

    public func format(source: String, options: PrintOptions) throws -> String {
        try formatGraphQL(source, options: options)
    }

    public static func register() {
        PluginRegistry.shared.register(GraphQLPlugin())
    }
}
