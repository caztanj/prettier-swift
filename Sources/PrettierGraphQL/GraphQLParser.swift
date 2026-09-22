import Foundation
import PrettierCore

public struct GraphQLParser {
    public static func parse(_ source: String) throws -> (GraphQLDocument, [Comment]) {
        var parser = GraphQLParserImpl(source: source)
        return try parser.parse()
    }
}

private struct GraphQLParserImpl {
    let source: String
    var comments: [Comment] = []
    var index: String.Index

    init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    mutating func parse() throws -> (GraphQLDocument, [Comment]) {
        extractComments()
        var definitions: [GraphQLNode] = []

        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }

            if let def = try parseDefinition() {
                definitions.append(def)
            } else {
                index = source.index(after: index)
            }
        }

        let doc = GraphQLDocument(definitions: definitions, range: 0..<source.utf8.count)
        return (doc, comments)
    }

    private mutating func extractComments() {
        var i = source.startIndex
        while i < source.endIndex {
            let ch = source[i]

            if ch == "\"" {
                if source[i...].hasPrefix("\"\"\"") {
                    i = source.index(i, offsetBy: 3)
                    if let endRange = source[i...].range(of: "\"\"\"") {
                        i = endRange.upperBound
                    } else {
                        i = source.endIndex
                    }
                } else {
                    i = source.index(after: i)
                    while i < source.endIndex {
                        if source[i] == "\\" {
                            i = source.index(after: i)
                            if i < source.endIndex { i = source.index(after: i) }
                        } else if source[i] == "\"" {
                            i = source.index(after: i)
                            break
                        } else {
                            i = source.index(after: i)
                        }
                    }
                }
                continue
            }

            if ch == "#" {
                let startIdx = i
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
                let endIdx = source[i...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                let fullText = String(source[startIdx..<endIdx])
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: endIdx)
                comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: false))
                i = endIdx
                continue
            }

            i = source.index(after: i)
        }
    }

    private mutating func skipWhitespaceAndComments() {
        while index < source.endIndex {
            let ch = source[index]
            if ch.isWhitespace || ch == "," {
                index = source.index(after: index)
                continue
            }
            if ch == "#" {
                let endIdx = source[index...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                index = endIdx
                continue
            }
            break
        }
    }

    private mutating func parseDefinition() throws -> GraphQLNode? {
        skipWhitespaceAndComments()
        guard index < source.endIndex else { return nil }

        let startUtf8 = source.utf8.distance(from: source.startIndex, to: index)

        if source[index] == "{" {
            let selectionSet = try parseSelectionSet()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return GraphQLOperation(operationType: "query", name: nil, selectionSet: selectionSet, range: startUtf8..<endUtf8)
        }

        let word = scanWord()

        if word == "query" || word == "mutation" || word == "subscription" {
            skipWhitespaceAndComments()
            var name: String? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_") {
                name = scanWord()
            }
            skipWhitespaceAndComments()
            var vars: [GraphQLVariableDefinition] = []
            if index < source.endIndex && source[index] == "(" {
                vars = try parseVariableDefinitions()
            }
            skipWhitespaceAndComments()
            let directives = try parseDirectives()
            skipWhitespaceAndComments()
            let selectionSet = try parseSelectionSet()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return GraphQLOperation(
                operationType: word,
                name: name,
                variables: vars,
                directives: directives,
                selectionSet: selectionSet,
                range: startUtf8..<endUtf8
            )
        }

        if word == "fragment" {
            skipWhitespaceAndComments()
            let name = scanWord()
            skipWhitespaceAndComments()
            if scanWord() == "on" {
                skipWhitespaceAndComments()
            }
            let typeCondition = scanWord()
            skipWhitespaceAndComments()
            let directives = try parseDirectives()
            skipWhitespaceAndComments()
            let selectionSet = try parseSelectionSet()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return GraphQLFragment(
                name: name,
                typeCondition: typeCondition,
                directives: directives,
                selectionSet: selectionSet,
                range: startUtf8..<endUtf8
            )
        }

        if ["type", "input", "interface", "enum", "union", "scalar"].contains(word) {
            skipWhitespaceAndComments()
            let name = scanWord()
            skipWhitespaceAndComments()
            var fields: [GraphQLFieldDefinition] = []
            if index < source.endIndex && source[index] == "{" {
                index = source.index(after: index)
                while index < source.endIndex {
                    skipWhitespaceAndComments()
                    if source[index] == "}" {
                        index = source.index(after: index)
                        break
                    }
                    let fieldName = scanWord()
                    skipWhitespaceAndComments()
                    var fieldArgs: [GraphQLArgument] = []
                    if index < source.endIndex && source[index] == "(" {
                        fieldArgs = try parseArguments()
                    }
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == ":" {
                        index = source.index(after: index)
                    }
                    skipWhitespaceAndComments()
                    let fieldType = scanType()
                    fields.append(GraphQLFieldDefinition(name: fieldName, arguments: fieldArgs, type: fieldType))
                }
            }
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return GraphQLTypeDefinition(kind: word, name: name, fields: fields, range: startUtf8..<endUtf8)
        }

        return nil
    }

    private mutating func parseSelectionSet() throws -> GraphQLSelectionSet {
        let startUtf8 = source.utf8.distance(from: source.startIndex, to: index)
        if index < source.endIndex && source[index] == "{" {
            index = source.index(after: index)
        }
        var selections: [GraphQLNode] = []

        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }
            if source[index] == "}" {
                index = source.index(after: index)
                break
            }

            if source[index...].hasPrefix("...") {
                index = source.index(index, offsetBy: 3)
                skipWhitespaceAndComments()
                if source[index...].hasPrefix("on ") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                    let typeCond = scanWord()
                    skipWhitespaceAndComments()
                    let directives = try parseDirectives()
                    skipWhitespaceAndComments()
                    let selSet = try parseSelectionSet()
                    selections.append(GraphQLInlineFragment(typeCondition: typeCond, directives: directives, selectionSet: selSet))
                } else if source[index] == "{" {
                    let selSet = try parseSelectionSet()
                    selections.append(GraphQLInlineFragment(typeCondition: nil, selectionSet: selSet))
                } else {
                    let fragName = scanWord()
                    skipWhitespaceAndComments()
                    let directives = try parseDirectives()
                    selections.append(GraphQLFragmentSpread(name: fragName, directives: directives))
                }
                continue
            }

            let word1 = scanWord()
            skipWhitespaceAndComments()
            var alias: String? = nil
            var fieldName = word1
            if index < source.endIndex && source[index] == ":" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                alias = word1
                fieldName = scanWord()
                skipWhitespaceAndComments()
            }

            var args: [GraphQLArgument] = []
            if index < source.endIndex && source[index] == "(" {
                args = try parseArguments()
                skipWhitespaceAndComments()
            }

            let directives = try parseDirectives()
            skipWhitespaceAndComments()

            var subSelectionSet: GraphQLSelectionSet? = nil
            if index < source.endIndex && source[index] == "{" {
                subSelectionSet = try parseSelectionSet()
            }

            selections.append(GraphQLField(
                alias: alias,
                name: fieldName,
                arguments: args,
                directives: directives,
                selectionSet: subSelectionSet
            ))
        }

        let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
        return GraphQLSelectionSet(selections: selections, range: startUtf8..<endUtf8)
    }

    private mutating func parseArguments() throws -> [GraphQLArgument] {
        if index < source.endIndex && source[index] == "(" {
            index = source.index(after: index)
        }
        var args: [GraphQLArgument] = []

        while index < source.endIndex && source[index] != ")" {
            skipWhitespaceAndComments()
            if source[index] == ")" { break }

            let argName = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ":" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            let argVal = scanValue()
            args.append(GraphQLArgument(name: argName, value: argVal))
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "," {
                index = source.index(after: index)
            }
        }

        if index < source.endIndex && source[index] == ")" {
            index = source.index(after: index)
        }
        return args
    }

    private mutating func parseDirectives() throws -> [GraphQLDirective] {
        var directives: [GraphQLDirective] = []
        while index < source.endIndex && source[index] == "@" {
            index = source.index(after: index)
            let dirName = scanWord()
            skipWhitespaceAndComments()
            var args: [GraphQLArgument] = []
            if index < source.endIndex && source[index] == "(" {
                args = try parseArguments()
            }
            directives.append(GraphQLDirective(name: "@" + dirName, arguments: args))
            skipWhitespaceAndComments()
        }
        return directives
    }

    private mutating func parseVariableDefinitions() throws -> [GraphQLVariableDefinition] {
        if index < source.endIndex && source[index] == "(" {
            index = source.index(after: index)
        }
        var vars: [GraphQLVariableDefinition] = []

        while index < source.endIndex && source[index] != ")" {
            skipWhitespaceAndComments()
            if source[index] == ")" { break }

            var varName = ""
            if source[index] == "$" {
                varName = "$"
                index = source.index(after: index)
            }
            varName += scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ":" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            let varType = scanType()
            skipWhitespaceAndComments()
            var defaultVal: String? = nil
            if index < source.endIndex && source[index] == "=" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                defaultVal = scanValue()
            }
            vars.append(GraphQLVariableDefinition(variable: varName, type: varType, defaultValue: defaultVal))
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "," {
                index = source.index(after: index)
            }
        }

        if index < source.endIndex && source[index] == ")" {
            index = source.index(after: index)
        }
        return vars
    }

    private mutating func scanWord() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isLetter || ch.isNumber || ch == "_" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return String(source[start..<index])
    }

    private mutating func scanType() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "!" || ch == "[" || ch == "]" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return String(source[start..<index])
    }

    private mutating func scanValue() -> String {
        guard index < source.endIndex else { return "" }
        let ch = source[index]

        if ch == "\"" {
            index = source.index(after: index)
            let start = index
            while index < source.endIndex && source[index] != "\"" {
                if source[index] == "\\" {
                    index = source.index(after: index)
                    if index < source.endIndex { index = source.index(after: index) }
                } else {
                    index = source.index(after: index)
                }
            }
            let str = String(source[start..<index])
            if index < source.endIndex && source[index] == "\"" {
                index = source.index(after: index)
            }
            return "\"\(str)\""
        }

        if ch == "$" {
            let start = index
            index = source.index(after: index)
            _ = scanWord()
            return String(source[start..<index])
        }

        let start = index
        while index < source.endIndex {
            let c = source[index]
            if c.isWhitespace || c == "," || c == ")" || c == "}" || c == "]" {
                break
            }
            index = source.index(after: index)
        }
        return String(source[start..<index])
    }
}
