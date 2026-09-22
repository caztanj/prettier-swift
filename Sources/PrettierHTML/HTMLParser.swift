import Foundation
import PrettierCore

public struct HTMLParser {
    public static func parse(_ source: String) throws -> (HTMLDocument, [Comment]) {
        var parser = HTMLParserImpl(source: source)
        return try parser.parse()
    }
}

private struct HTMLParserImpl {
    let source: String
    var comments: [Comment] = []
    var index: String.Index

    init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    mutating func parse() throws -> (HTMLDocument, [Comment]) {
        extractComments()
        let children = try parseNodes(parentTag: nil)
        let doc = HTMLDocument(children: children, range: 0..<source.utf8.count)
        return (doc, comments)
    }

    private mutating func extractComments() {
        var i = source.startIndex
        while let startRange = source[i...].range(of: "<!--") {
            let startIdx = startRange.lowerBound
            let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
            if let endRange = source[startRange.upperBound...].range(of: "-->") {
                let fullComment = String(source[startIdx..<endRange.upperBound])
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: endRange.upperBound)
                comments.append(Comment(text: fullComment, range: startUtf8..<endUtf8, isBlock: true))
                i = endRange.upperBound
            } else {
                let fullComment = String(source[startIdx...])
                let endUtf8 = source.utf8.count
                comments.append(Comment(text: fullComment, range: startUtf8..<endUtf8, isBlock: true))
                break
            }
        }
    }

    private mutating func parseNodes(parentTag: String?) throws -> [HTMLNode] {
        var nodes: [HTMLNode] = []

        while index < source.endIndex {
            skipWhitespace()
            guard index < source.endIndex else { break }

            if source[index...].hasPrefix("</") {
                if parentTag != nil {
                    break
                } else {
                    if let closeEnd = source[index...].firstIndex(of: ">") {
                        index = source.index(after: closeEnd)
                        continue
                    }
                }
            }

            if source[index...].hasPrefix("<!--") {
                if let endRange = source[index...].range(of: "-->") {
                    index = endRange.upperBound
                    continue
                } else {
                    index = source.endIndex
                    break
                }
            }

            if source[index...].lowercased().hasPrefix("<!doctype") {
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                if let endIdx = source[index...].firstIndex(of: ">") {
                    let doctypeContent = String(source[index...endIdx])
                    index = source.index(after: endIdx)
                    let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                    nodes.append(HTMLDoctype(value: doctypeContent, range: startUtf8..<endUtf8))
                    continue
                }
            }

            if source[index] == "<" {
                if let element = try parseElement() {
                    nodes.append(element)
                    continue
                }
            }

            let start = index
            let startUtf8 = source.utf8.distance(from: source.startIndex, to: start)
            while index < source.endIndex && source[index] != "<" {
                index = source.index(after: index)
            }
            let text = String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                nodes.append(HTMLText(value: text, range: startUtf8..<endUtf8))
            }
        }

        return nodes
    }

    private mutating func parseElement() throws -> HTMLElement? {
        let startIdx = index
        let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
        index = source.index(after: index)

        let tagName = scanIdentifier()
        guard !tagName.isEmpty else { return nil }

        var attributes: [HTMLAttribute] = []

        while index < source.endIndex {
            skipWhitespace()
            guard index < source.endIndex else { break }

            if source[index] == ">" || source[index...].hasPrefix("/>") {
                break
            }

            let attrStart = index
            let attrStartUtf8 = source.utf8.distance(from: source.startIndex, to: attrStart)
            let attrName = scanAttributeName()
            guard !attrName.isEmpty else {
                index = source.index(after: index)
                continue
            }

            skipWhitespace()
            var attrVal: String? = nil

            if index < source.endIndex && source[index] == "=" {
                index = source.index(after: index)
                skipWhitespace()
                attrVal = scanAttributeValue()
            }

            let attrEndUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            attributes.append(HTMLAttribute(name: attrName, value: attrVal, range: attrStartUtf8..<attrEndUtf8))
        }

        skipWhitespace()
        let isExplicitSelfClosing = source[index...].hasPrefix("/>")
        if isExplicitSelfClosing {
            index = source.index(index, offsetBy: 2)
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return HTMLElement(
                tag: tagName,
                attributes: attributes,
                children: [],
                isSelfClosing: true,
                range: startUtf8..<endUtf8
            )
        } else if index < source.endIndex && source[index] == ">" {
            index = source.index(after: index)
        }

        if HTMLElement.voidTags.contains(tagName.lowercased()) {
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return HTMLElement(
                tag: tagName,
                attributes: attributes,
                children: [],
                isSelfClosing: false,
                range: startUtf8..<endUtf8
            )
        }

        let lowerTag = tagName.lowercased()
        if lowerTag == "script" || lowerTag == "style" {
            let closeTag = "</\(tagName)>"
            let textStart = index
            let textStartUtf8 = source.utf8.distance(from: source.startIndex, to: textStart)
            if let closeRange = source[index...].range(of: closeTag, options: .caseInsensitive) {
                let rawText = String(source[textStart..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                index = closeRange.upperBound
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                var children: [HTMLNode] = []
                if !rawText.isEmpty {
                    children.append(HTMLText(value: rawText, range: textStartUtf8..<source.utf8.distance(from: source.startIndex, to: closeRange.lowerBound)))
                }
                return HTMLElement(
                    tag: tagName,
                    attributes: attributes,
                    children: children,
                    isSelfClosing: false,
                    range: startUtf8..<endUtf8
                )
            }
        }

        let children = try parseNodes(parentTag: tagName)

        if source[index...].hasPrefix("</") {
            if let closeEnd = source[index...].firstIndex(of: ">") {
                index = source.index(after: closeEnd)
            }
        }

        let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
        return HTMLElement(
            tag: tagName,
            attributes: attributes,
            children: children,
            isSelfClosing: false,
            range: startUtf8..<endUtf8
        )
    }

    private mutating func scanIdentifier() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" || ch == ":" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return String(source[start..<index])
    }

    private mutating func scanAttributeName() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isWhitespace || ch == "=" || ch == ">" || ch == "/" {
                break
            }
            index = source.index(after: index)
        }
        return String(source[start..<index])
    }

    private mutating func scanAttributeValue() -> String {
        guard index < source.endIndex else { return "" }
        let quote = source[index]
        if quote == "\"" || quote == "'" {
            index = source.index(after: index)
            let start = index
            while index < source.endIndex && source[index] != quote {
                index = source.index(after: index)
            }
            let val = String(source[start..<index])
            if index < source.endIndex && source[index] == quote {
                index = source.index(after: index)
            }
            return val
        } else {
            let start = index
            while index < source.endIndex && !source[index].isWhitespace && source[index] != ">" {
                index = source.index(after: index)
            }
            return String(source[start..<index])
        }
    }

    private mutating func skipWhitespace() {
        while index < source.endIndex && source[index].isWhitespace {
            index = source.index(after: index)
        }
    }
}
