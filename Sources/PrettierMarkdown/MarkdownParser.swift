import Foundation
import PrettierCore

public struct MarkdownParser {
    public static func parse(_ source: String) -> (MarkdownDocument, [Comment]) {
        var parser = MarkdownParserImpl(source: source)
        return parser.parse()
    }
}

private struct MarkdownParserImpl {
    let source: String
    var comments: [Comment] = []

    init(source: String) {
        self.source = source
    }

    mutating func parse() -> (MarkdownDocument, [Comment]) {
        extractHTMLComments()
        let lines = source.components(separatedBy: "\n")
        var blocks: [MarkdownNode] = []
        var lineIndex = 0

        while lineIndex < lines.count {
            let before = lineIndex
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                lineIndex += 1
                continue
            }

            if let heading = parseHeading(line, lineIndex: lineIndex) {
                blocks.append(heading)
                lineIndex += 1
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let (codeBlock, nextIndex) = parseFencedCodeBlock(lines: lines, startIndex: lineIndex)
                blocks.append(codeBlock)
                lineIndex = max(before + 1, nextIndex)
                continue
            }

            if isThematicBreak(trimmed) {
                blocks.append(MarkdownThematicBreak())
                lineIndex += 1
                continue
            }

            if isTableStart(lines: lines, currentIndex: lineIndex) {
                let (table, nextIndex) = parseTable(lines: lines, startIndex: lineIndex)
                blocks.append(table)
                lineIndex = max(before + 1, nextIndex)
                continue
            }

            if trimmed.hasPrefix(">") {
                let (blockquote, nextIndex) = parseBlockquote(lines: lines, startIndex: lineIndex)
                blocks.append(blockquote)
                lineIndex = max(before + 1, nextIndex)
                continue
            }

            if isListStart(trimmed) {
                let (list, nextIndex) = parseList(lines: lines, startIndex: lineIndex)
                blocks.append(list)
                lineIndex = max(before + 1, nextIndex)
                continue
            }

            if trimmed.hasPrefix("<!--") {
                let (htmlBlock, nextIndex) = parseHTMLCommentBlock(lines: lines, startIndex: lineIndex)
                blocks.append(htmlBlock)
                lineIndex = max(before + 1, nextIndex)
                continue
            }

            let (paraOrHeading, nextIndex) = parseParagraphOrSetext(lines: lines, startIndex: lineIndex)
            blocks.append(paraOrHeading)
            lineIndex = max(before + 1, nextIndex)
        }

        let doc = MarkdownDocument(children: blocks, range: 0..<source.utf8.count)
        return (doc, comments)
    }

    private mutating func extractHTMLComments() {
        var searchStart = source.startIndex
        while let commentStart = source.range(of: "<!--", range: searchStart..<source.endIndex) {
            if let commentEnd = source.range(of: "-->", range: commentStart.upperBound..<source.endIndex) {
                let value = String(source[commentStart.upperBound..<commentEnd.lowerBound])
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: commentStart.lowerBound)
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: commentEnd.upperBound)
                comments.append(Comment(
                    text: value,
                    range: startUtf8..<endUtf8,
                    isBlock: true
                ))
                searchStart = commentEnd.upperBound
            } else {
                break
            }
        }
    }

    private func parseHeading(_ line: String, lineIndex: Int) -> MarkdownHeading? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level >= 1 && level <= 6 else { return nil }
        let remainder = trimmed.dropFirst(level)
        guard remainder.isEmpty || remainder.hasPrefix(" ") || remainder.hasPrefix("\t") else {
            return nil
        }

        var textContent = remainder.trimmingCharacters(in: .whitespaces)
        while textContent.hasSuffix("#") {
            textContent.removeLast()
        }
        textContent = textContent.trimmingCharacters(in: .whitespaces)

        let inlines = parseInlines(textContent)
        return MarkdownHeading(level: level, children: inlines)
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        let first = stripped.first!
        guard first == "-" || first == "*" || first == "_" else { return false }
        return stripped.allSatisfy { $0 == first }
    }

    private func parseFencedCodeBlock(lines: [String], startIndex: Int) -> (MarkdownCodeBlock, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let fenceChar: Character = firstLine.hasPrefix("```") ? "`" : "~"
        let fenceCount = firstLine.prefix(while: { $0 == fenceChar }).count
        let fence = String(repeating: fenceChar, count: fenceCount)
        let info = firstLine.dropFirst(fenceCount).trimmingCharacters(in: .whitespaces)

        var codeLines: [String] = []
        var i = startIndex + 1

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(fence) {
                i += 1
                break
            }
            codeLines.append(line)
            i += 1
        }

        let value = codeLines.joined(separator: "\n")
        let block = MarkdownCodeBlock(
            language: info,
            value: value
        )
        return (block, i)
    }

    private func isTableStart(lines: [String], currentIndex: Int) -> Bool {
        guard currentIndex + 1 < lines.count else { return false }
        let first = lines[currentIndex].trimmingCharacters(in: .whitespaces)
        let second = lines[currentIndex + 1].trimmingCharacters(in: .whitespaces)

        guard first.contains("|") && second.contains("|") else { return false }

        let cells = second.split(separator: "|", omittingEmptySubsequences: true)
        guard !cells.isEmpty else { return false }

        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let inner = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard inner.count >= 1 && inner.allSatisfy({ $0 == "-" }) else {
                return false
            }
        }
        return true
    }

    private func parseTable(lines: [String], startIndex: Int) -> (MarkdownTable, Int) {
        let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let delimiterLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)

        let rawHeaders = splitTableLine(headerLine)
        let rawDelims = splitTableLine(delimiterLine)

        var alignments: [MarkdownTableAlignment] = []
        for delim in rawDelims {
            let trimmed = delim.trimmingCharacters(in: .whitespaces)
            let leftColon = trimmed.hasPrefix(":")
            let rightColon = trimmed.hasSuffix(":")
            if leftColon && rightColon {
                alignments.append(.center)
            } else if leftColon {
                alignments.append(.left)
            } else if rightColon {
                alignments.append(.right)
            } else {
                alignments.append(.none)
            }
        }

        var rows: [[String]] = []
        var i = startIndex + 2
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || !line.contains("|") {
                break
            }
            rows.append(splitTableLine(line))
            i += 1
        }

        let table = MarkdownTable(
            headers: rawHeaders,
            alignments: alignments,
            rows: rows
        )
        return (table, i)
    }

    private func splitTableLine(_ line: String) -> [String] {
        var str = line
        if str.hasPrefix("|") { str.removeFirst() }
        if str.hasSuffix("|") { str.removeLast() }
        return str.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseBlockquote(lines: [String], startIndex: Int) -> (MarkdownBlockQuote, Int) {
        var quoteLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                break
            }
            if trimmed.hasPrefix(">") {
                var stripped = trimmed.dropFirst()
                if stripped.hasPrefix(" ") {
                    stripped = stripped.dropFirst()
                }
                quoteLines.append(String(stripped))
                i += 1
            } else {
                quoteLines.append(trimmed)
                i += 1
            }
        }

        let innerContent = quoteLines.joined(separator: "\n")
        var subParser = MarkdownParserImpl(source: innerContent)
        let (subDoc, subComments) = subParser.parse()
        _ = subComments

        let bq = MarkdownBlockQuote(children: subDoc.children)
        return (bq, i)
    }

    private func isOrderedListStart(_ line: String) -> Bool {
        line.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
    }

    private func isUnorderedListStart(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private func isListStart(_ line: String) -> Bool {
        isUnorderedListStart(line) || isOrderedListStart(line)
    }

    private func parseList(lines: [String], startIndex: Int) -> (MarkdownList, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let isOrdered = isOrderedListStart(firstLine)

        var items: [MarkdownListItem] = []
        var i = startIndex

        var currentItemLines: [String] = []

        func finalizeCurrentItem() {
            guard !currentItemLines.isEmpty else { return }
            let itemContent = currentItemLines.joined(separator: "\n")
            var itemParser = MarkdownParserImpl(source: itemContent)
            let (doc, _) = itemParser.parse()
            items.append(MarkdownListItem(children: doc.children))
            currentItemLines.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let sameType = isOrdered ? isOrderedListStart(nextTrimmed) : isUnorderedListStart(nextTrimmed)
                    if nextLine.hasPrefix("  ") || nextLine.hasPrefix("\t") || sameType {
                        i += 1
                        continue
                    }
                }
                break
            }

            let matchesCurrentListType = isOrdered ? isOrderedListStart(trimmed) : isUnorderedListStart(trimmed)
            if matchesCurrentListType {
                finalizeCurrentItem()

                var itemText = trimmed
                if isUnorderedListStart(itemText) {
                    itemText = String(itemText.dropFirst(2))
                } else if let dotRange = itemText.range(of: #"^\d+[.)]\s*"#, options: .regularExpression) {
                    itemText = String(itemText[dotRange.upperBound...])
                }
                currentItemLines.append(itemText)
                i += 1
            } else if line.hasPrefix("  ") || line.hasPrefix("\t") {
                currentItemLines.append(trimmed)
                i += 1
            } else {
                break
            }
        }

        finalizeCurrentItem()

        let list = MarkdownList(isOrdered: isOrdered, items: items)
        return (list, i)
    }

    private func parseHTMLCommentBlock(lines: [String], startIndex: Int) -> (MarkdownHTMLBlock, Int) {
        var commentLines: [String] = []
        var i = startIndex
        while i < lines.count {
            let line = lines[i]
            commentLines.append(line)
            i += 1
            if line.contains("-->") {
                break
            }
        }
        let block = MarkdownHTMLBlock(value: commentLines.joined(separator: "\n"))
        return (block, i)
    }

    private func parseParagraphOrSetext(lines: [String], startIndex: Int) -> (MarkdownNode, Int) {
        if startIndex + 1 < lines.count {
            let nextTrimmed = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
            if !nextTrimmed.isEmpty {
                if nextTrimmed.allSatisfy({ $0 == "=" }) {
                    let inlines = parseInlines(lines[startIndex].trimmingCharacters(in: .whitespaces))
                    let heading = MarkdownHeading(level: 1, children: inlines)
                    return (heading, startIndex + 2)
                } else if nextTrimmed.allSatisfy({ $0 == "-" }) {
                    let inlines = parseInlines(lines[startIndex].trimmingCharacters(in: .whitespaces))
                    let heading = MarkdownHeading(level: 2, children: inlines)
                    return (heading, startIndex + 2)
                }
            }
        }

        var paraLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                break
            }
            if parseHeading(line, lineIndex: i) != nil ||
               trimmed.hasPrefix("```") ||
               trimmed.hasPrefix("~~~") ||
               isThematicBreak(trimmed) ||
               isTableStart(lines: lines, currentIndex: i) ||
               trimmed.hasPrefix(">") ||
               isListStart(trimmed) {
                break
            }
            paraLines.append(trimmed)
            i += 1
        }

        let fullText = paraLines.joined(separator: " ")
        let inlines = parseInlines(fullText)
        let paragraph = MarkdownParagraph(children: inlines)
        return (paragraph, i)
    }

    private func parseInlines(_ text: String) -> [MarkdownNode] {
        var nodes: [MarkdownNode] = []
        var i = text.startIndex

        while i < text.endIndex {
            if text[i] == "`" {
                let codeStart = text.index(after: i)
                if let codeEnd = text[codeStart...].firstIndex(of: "`") {
                    let codeVal = String(text[codeStart..<codeEnd])
                    nodes.append(MarkdownInlineCode(value: codeVal))
                    i = text.index(after: codeEnd)
                    continue
                }
            }

            if text[i] == "*" || text[i] == "_" {
                let marker = text[i]
                let isDouble = text.index(after: i) < text.endIndex && text[text.index(after: i)] == marker

                if isDouble {
                    let markStr = String(repeating: marker, count: 2)
                    let contentStart = text.index(i, offsetBy: 2)
                    if let endRange = text[contentStart...].range(of: markStr) {
                        let inner = String(text[contentStart..<endRange.lowerBound])
                        let children = parseInlines(inner)
                        nodes.append(MarkdownStrong(children: children))
                        i = endRange.upperBound
                        continue
                    }
                } else {
                    let contentStart = text.index(after: i)
                    if let endIdx = text[contentStart...].firstIndex(of: marker) {
                        let inner = String(text[contentStart..<endIdx])
                        let children = parseInlines(inner)
                        nodes.append(MarkdownEmphasis(children: children))
                        i = text.index(after: endIdx)
                        continue
                    }
                }
            }

            if text[i] == "!" && text.index(after: i) < text.endIndex && text[text.index(after: i)] == "[" {
                if let (image, nextIdx) = parseImage(text, from: i) {
                    nodes.append(image)
                    i = nextIdx
                    continue
                }
            }

            if text[i] == "[" {
                if let (link, nextIdx) = parseLink(text, from: i) {
                    nodes.append(link)
                    i = nextIdx
                    continue
                }
            }

            let nextSpecial = text[i...].firstIndex(where: { $0 == "`" || $0 == "*" || $0 == "_" || $0 == "[" || $0 == "!" }) ?? text.endIndex
            if nextSpecial == i {
                let charStr = String(text[i])
                if let lastText = nodes.last as? MarkdownText {
                    lastText.value += charStr
                } else {
                    nodes.append(MarkdownText(value: charStr))
                }
                i = text.index(after: i)
            } else {
                let plain = String(text[i..<nextSpecial])
                if let lastText = nodes.last as? MarkdownText {
                    lastText.value += plain
                } else {
                    nodes.append(MarkdownText(value: plain))
                }
                i = nextSpecial
            }
        }

        return nodes
    }

    private func parseImage(_ text: String, from start: String.Index) -> (MarkdownImage, String.Index)? {
        let bracketStart = text.index(after: start)
        guard let bracketEnd = text[bracketStart...].firstIndex(of: "]") else { return nil }
        let alt = String(text[text.index(after: bracketStart)..<bracketEnd])

        let parenStart = text.index(after: bracketEnd)
        guard parenStart < text.endIndex && text[parenStart] == "(" else { return nil }
        guard let parenEnd = text[parenStart...].firstIndex(of: ")") else { return nil }

        let insideParen = String(text[text.index(after: parenStart)..<parenEnd]).trimmingCharacters(in: .whitespaces)
        let parts = insideParen.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let url = parts.isEmpty ? "" : String(parts[0])
        var title: String? = nil
        if parts.count > 1 {
            var rawTitle = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if (rawTitle.hasPrefix("\"") && rawTitle.hasSuffix("\"")) || (rawTitle.hasPrefix("'") && rawTitle.hasSuffix("'")) {
                rawTitle.removeFirst()
                rawTitle.removeLast()
            }
            title = rawTitle
        }

        let image = MarkdownImage(url: url, title: title, alt: alt)
        return (image, text.index(after: parenEnd))
    }

    private func parseLink(_ text: String, from start: String.Index) -> (MarkdownLink, String.Index)? {
        guard let bracketEnd = text[start...].firstIndex(of: "]") else { return nil }
        let linkText = String(text[text.index(after: start)..<bracketEnd])

        let parenStart = text.index(after: bracketEnd)
        guard parenStart < text.endIndex && text[parenStart] == "(" else { return nil }
        guard let parenEnd = text[parenStart...].firstIndex(of: ")") else { return nil }

        let insideParen = String(text[text.index(after: parenStart)..<parenEnd]).trimmingCharacters(in: .whitespaces)
        let parts = insideParen.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let url = parts.isEmpty ? "" : String(parts[0])
        var title: String? = nil
        if parts.count > 1 {
            var rawTitle = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if (rawTitle.hasPrefix("\"") && rawTitle.hasSuffix("\"")) || (rawTitle.hasPrefix("'") && rawTitle.hasSuffix("'")) {
                rawTitle.removeFirst()
                rawTitle.removeLast()
            }
            title = rawTitle
        }

        let children = parseInlines(linkText)
        let link = MarkdownLink(url: url, title: title, children: children)
        return (link, text.index(after: parenEnd))
    }
}
