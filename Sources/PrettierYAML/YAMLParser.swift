import Foundation
import PrettierCore

public enum YAMLParserError: Error {
    case invalidSyntax(String)
}

public final class YAMLParser {
    private let source: String
    private var lines: [String] = []
    private var comments: [Comment] = []

    public init(_ source: String) {
        self.source = source
        self.lines = source.components(separatedBy: .newlines)
    }

    public static func parse(_ source: String) throws -> (root: YAMLDocument, comments: [Comment]) {
        let parser = YAMLParser(source)
        let root = try parser.parseDocument()
        return (root, parser.comments)
    }

    private func parseDocument() throws -> YAMLDocument {
        extractComments()

        var hasDirectivesEnd = false
        var lineIndex = 0

        while lineIndex < lines.count {
            let trimmed = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                hasDirectivesEnd = true
                lineIndex += 1
                break
            }
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                break
            }
            lineIndex += 1
        }

        let body = parseBlock(startingAt: &lineIndex, minIndent: 0)
        return YAMLDocument(body: body, hasDirectivesEnd: hasDirectivesEnd)
    }

    private func parseBlock(startingAt lineIndex: inout Int, minIndent: Int) -> YAMLNode? {
        skipEmptyLines(startingAt: &lineIndex)
        guard lineIndex < lines.count else { return nil }

        let currentLine = lines[lineIndex]
        let currentIndent = countIndent(currentLine)
        guard currentIndent >= minIndent else { return nil }

        let trimmed = stripComment(currentLine).trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") || trimmed == "-" {
            return parseSequence(startingAt: &lineIndex, indent: currentIndent)
        }

        if isMappingLine(trimmed) {
            return parseMapping(startingAt: &lineIndex, indent: currentIndent)
        }

        return parseScalarOrFlow(startingAt: &lineIndex, indent: currentIndent)
    }

    private func parseMapping(startingAt lineIndex: inout Int, indent: Int) -> YAMLMapping {
        var items: [YAMLMappingItem] = []

        while lineIndex < lines.count {
            skipEmptyLines(startingAt: &lineIndex)
            guard lineIndex < lines.count else { break }

            let line = lines[lineIndex]
            let lineIndent = countIndent(line)
            if lineIndent < indent {
                break
            }
            if lineIndent > indent && !items.isEmpty {
                break
            }

            let trimmed = stripComment(line).trimmingCharacters(in: .whitespaces)
            guard isMappingLine(trimmed) else { break }

            let colonIndex = trimmed.firstIndex(of: ":")!
            let keyStr = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            let keyNode = parseSimpleScalar(keyStr)
            lineIndex += 1

            let valueNode: YAMLNode?
            if rawValue.isEmpty {
                valueNode = parseBlock(startingAt: &lineIndex, minIndent: indent + 1)
            } else {
                valueNode = parseSimpleScalar(rawValue)
            }

            items.append(YAMLMappingItem(key: keyNode, value: valueNode))
        }

        return YAMLMapping(items: items)
    }

    private func parseSequence(startingAt lineIndex: inout Int, indent: Int) -> YAMLSequence {
        var items: [YAMLNode] = []

        while lineIndex < lines.count {
            skipEmptyLines(startingAt: &lineIndex)
            guard lineIndex < lines.count else { break }

            let line = lines[lineIndex]
            let lineIndent = countIndent(line)
            if lineIndent < indent {
                break
            }
            if lineIndent > indent && !items.isEmpty {
                break
            }

            let trimmed = stripComment(line).trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed == "-" else { break }

            let remainder = trimmed == "-" ? "" : String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            lineIndex += 1

            if remainder.isEmpty {
                if let child = parseBlock(startingAt: &lineIndex, minIndent: indent + 1) {
                    items.append(child)
                } else {
                    items.append(YAMLScalar(value: "", style: .plain))
                }
            } else if isMappingLine(remainder) {
                let colonIdx = remainder.firstIndex(of: ":")!
                let k = String(remainder[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let v = String(remainder[remainder.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                let valNode = v.isEmpty ? parseBlock(startingAt: &lineIndex, minIndent: indent + 2) : parseSimpleScalar(v)
                let mapItem = YAMLMappingItem(key: parseSimpleScalar(k), value: valNode)
                items.append(YAMLMapping(items: [mapItem]))
            } else {
                items.append(parseSimpleScalar(remainder))
            }
        }

        return YAMLSequence(items: items)
    }

    private func parseScalarOrFlow(startingAt lineIndex: inout Int, indent: Int) -> YAMLNode {
        let line = lines[lineIndex]
        lineIndex += 1
        let trimmed = stripComment(line).trimmingCharacters(in: .whitespaces)
        return parseSimpleScalar(trimmed)
    }

    private func parseSimpleScalar(_ text: String) -> YAMLScalar {
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2 {
            let inner = String(text.dropFirst().dropLast())
            return YAMLScalar(value: inner, style: .doubleQuote, raw: text)
        }
        if text.hasPrefix("'") && text.hasSuffix("'") && text.count >= 2 {
            let inner = String(text.dropFirst().dropLast())
            return YAMLScalar(value: inner, style: .singleQuote, raw: text)
        }
        return YAMLScalar(value: text, style: .plain, raw: text)
    }

    private func isMappingLine(_ text: String) -> Bool {
        guard let colonIdx = text.firstIndex(of: ":") else { return false }
        if text.hasPrefix("- ") { return false }
        let afterColon = text[text.index(after: colonIdx)...]
        return afterColon.isEmpty || afterColon.hasPrefix(" ") || afterColon.hasPrefix("\t")
    }

    private func countIndent(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 2 }
            else { break }
        }
        return count
    }

    private func stripComment(_ line: String) -> String {
        var inSingle = false
        var inDouble = false
        for (i, ch) in line.enumerated() {
            if ch == "'" && !inDouble { inSingle.toggle() }
            else if ch == "\"" && !inSingle { inDouble.toggle() }
            else if ch == "#" && !inSingle && !inDouble {
                let idx = line.index(line.startIndex, offsetBy: i)
                return String(line[..<idx])
            }
        }
        return line
    }

    private func skipEmptyLines(startingAt index: inout Int) {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                break
            }
            index += 1
        }
    }

    private func extractComments() {
        var charOffset = 0
        for line in lines {
            if let hashIdx = line.firstIndex(of: "#") {
                let commentText = String(line[hashIdx...])
                let start = charOffset + line.distance(from: line.startIndex, to: hashIdx)
                let end = start + commentText.count
                comments.append(Comment(text: commentText, range: start..<end, isBlock: false))
            }
            let newlineByteCount = 1
            charOffset += line.count + newlineByteCount
        }
    }
}
