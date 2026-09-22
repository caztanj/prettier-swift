import Foundation
import PrettierCore

public struct CSSParser {
    public static func parse(_ source: String) throws -> (CSSStyleSheet, [Comment]) {
        var parser = CSSParserImpl(source: source)
        return try parser.parse()
    }
}

private struct CSSParserImpl {
    let source: String
    var comments: [Comment] = []
    var index: String.Index

    init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    mutating func parse() throws -> (CSSStyleSheet, [Comment]) {
        extractComments()
        let children = try parseNodeList(isTopLevel: true)
        let root = CSSStyleSheet(children: children, range: 0..<source.utf8.count)
        return (root, comments)
    }

    private mutating func extractComments() {
        var i = source.startIndex
        while i < source.endIndex {
            if source[i] == "\"" || source[i] == "'" {
                let quote = source[i]
                i = source.index(after: i)
                while i < source.endIndex {
                    if source[i] == "\\" {
                        i = source.index(after: i)
                        if i < source.endIndex { i = source.index(after: i) }
                    } else if source[i] == quote {
                        i = source.index(after: i)
                        break
                    } else {
                        i = source.index(after: i)
                    }
                }
                continue
            }

            if source[i] == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "*" {
                let startIdx = i
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
                i = source.index(i, offsetBy: 2)
                if let endRange = source[i...].range(of: "*/") {
                    let text = String(source[startIdx..<endRange.upperBound])
                    let endUtf8 = source.utf8.distance(from: source.startIndex, to: endRange.upperBound)
                    comments.append(Comment(text: text, range: startUtf8..<endUtf8, isBlock: true))
                    i = endRange.upperBound
                } else {
                    let text = String(source[startIdx...])
                    let endUtf8 = source.utf8.count
                    comments.append(Comment(text: text, range: startUtf8..<endUtf8, isBlock: true))
                    i = source.endIndex
                }
                continue
            }

            if source[i] == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "/" {
                let startIdx = i
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
                i = source.index(i, offsetBy: 2)
                let endIdx = source[i...].firstIndex(of: "\n") ?? source.endIndex
                let text = String(source[startIdx..<endIdx])
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: endIdx)
                comments.append(Comment(text: text, range: startUtf8..<endUtf8, isBlock: false))
                i = endIdx
                continue
            }

            i = source.index(after: i)
        }
    }

    private mutating func skipWhitespaceAndComments() {
        while index < source.endIndex {
            let ch = source[index]
            if ch.isWhitespace {
                index = source.index(after: index)
                continue
            }

            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "*" {
                index = source.index(index, offsetBy: 2)
                if let endRange = source[index...].range(of: "*/") {
                    index = endRange.upperBound
                } else {
                    index = source.endIndex
                }
                continue
            }

            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "/" {
                index = source.index(index, offsetBy: 2)
                if let nextLine = source[index...].firstIndex(of: "\n") {
                    index = source.index(after: nextLine)
                } else {
                    index = source.endIndex
                }
                continue
            }

            break
        }
    }

    private mutating func parseNodeList(isTopLevel: Bool) throws -> [CSSNode] {
        var nodes: [CSSNode] = []

        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }

            if !isTopLevel && source[index] == "}" {
                break
            }

            let startIdx = index
            let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)

            if source[index] == "@" {
                let atRule = try parseAtRule(startUtf8: startUtf8)
                nodes.append(atRule)
            } else {
                let (prefix, delimiter) = scanUntilAny([";", "{", "}"])
                if delimiter == "{" {
                    let rule = try parseRule(selectorsText: prefix, startUtf8: startUtf8)
                    nodes.append(rule)
                } else if delimiter == ";" || delimiter == "}" {
                    if !isTopLevel && prefix.contains(":") {
                        let decl = parseDeclaration(prefix, startUtf8: startUtf8)
                        nodes.append(decl)
                    }
                    if delimiter == ";" {
                        index = source.index(after: index)
                    }
                } else {
                    break
                }
            }
        }

        return nodes
    }

    private mutating func parseAtRule(startUtf8: Int) throws -> CSSAtRule {
        index = source.index(after: index)
        let name = scanIdentifier()
        skipWhitespaceAndComments()

        let (paramsText, delimiter) = scanUntilAny([";", "{"])
        let params = paramsText.trimmingCharacters(in: .whitespacesAndNewlines)

        if delimiter == "{" {
            index = source.index(after: index)
            let body = try parseNodeList(isTopLevel: false)
            if index < source.endIndex && source[index] == "}" {
                index = source.index(after: index)
            }
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return CSSAtRule(name: "@" + name, params: params, block: body, range: startUtf8..<endUtf8)
        } else {
            if delimiter == ";" {
                index = source.index(after: index)
            }
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return CSSAtRule(name: "@" + name, params: params, block: nil, range: startUtf8..<endUtf8)
        }
    }

    private mutating func parseRule(selectorsText: String, startUtf8: Int) throws -> CSSRule {
        let rawSelectors = selectorsText.components(separatedBy: ",")
        let selectors = rawSelectors.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        index = source.index(after: index)
        let body = try parseNodeList(isTopLevel: false)
        if index < source.endIndex && source[index] == "}" {
            index = source.index(after: index)
        }
        let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
        return CSSRule(selectors: selectors, body: body, range: startUtf8..<endUtf8)
    }

    private func parseDeclaration(_ text: String, startUtf8: Int) -> CSSDeclaration {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let property = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        var rawValue = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        var important = false
        if rawValue.lowercased().hasSuffix("!important") {
            important = true
            let endIndex = rawValue.index(rawValue.endIndex, offsetBy: -"!important".count)
            rawValue = String(rawValue[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return CSSDeclaration(property: property, value: rawValue, important: important, range: startUtf8..<startUtf8 + text.utf8.count)
    }

    private mutating func scanIdentifier() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return String(source[start..<index])
    }

    private mutating func scanUntilAny(_ delimiters: [Character]) -> (String, Character?) {
        let start = index
        var parenDepth = 0

        while index < source.endIndex {
            let ch = source[index]

            if ch == "\"" || ch == "'" {
                let quote = ch
                index = source.index(after: index)
                while index < source.endIndex {
                    if source[index] == "\\" {
                        index = source.index(after: index)
                        if index < source.endIndex { index = source.index(after: index) }
                    } else if source[index] == quote {
                        index = source.index(after: index)
                        break
                    } else {
                        index = source.index(after: index)
                    }
                }
                continue
            }

            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "*" {
                index = source.index(index, offsetBy: 2)
                if let endRange = source[index...].range(of: "*/") {
                    index = endRange.upperBound
                } else {
                    index = source.endIndex
                }
                continue
            }

            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "/" {
                index = source.index(index, offsetBy: 2)
                if let nextLine = source[index...].firstIndex(of: "\n") {
                    index = source.index(after: nextLine)
                } else {
                    index = source.endIndex
                }
                continue
            }

            if ch == "(" {
                parenDepth += 1
            } else if ch == ")" {
                parenDepth = max(0, parenDepth - 1)
            } else if parenDepth == 0 && delimiters.contains(ch) {
                let scanned = String(source[start..<index])
                return (scanned, ch)
            }

            index = source.index(after: index)
        }

        return (String(source[start..<index]), nil)
    }
}
