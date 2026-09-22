import Foundation
import PrettierDoc
import PrettierCore

public func formatMarkdown(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = MarkdownParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printMarkdownNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printMarkdownNode(
    _ node: MarkdownNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let doc as MarkdownDocument:
        var blockDocs: [Doc] = []
        for child in doc.children {
            blockDocs.append(printMarkdownNode(child, options: options, sourceText: sourceText))
        }
        innerDoc = .concat(join(separator: .concat([.hardline, .hardline]), blockDocs) + [.hardline])

    case let heading as MarkdownHeading:
        let prefix = String(repeating: "#", count: heading.level) + " "
        let inlinesDoc = heading.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat([.text(prefix)] + inlinesDoc)

    case let para as MarkdownParagraph:
        let inlinesDoc = para.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat(inlinesDoc)

    case let codeBlock as MarkdownCodeBlock:
        let fence = "```"
        var parts: [Doc] = [
            .text(fence + codeBlock.language),
            .hardline
        ]
        if !codeBlock.value.isEmpty {
            parts.append(.text(codeBlock.value))
            parts.append(.hardline)
        }
        parts.append(.text(fence))
        innerDoc = .concat(parts)

    case let bq as MarkdownBlockQuote:
        let innerBlocks = bq.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        let joined = Doc.concat(join(separator: .concat([.hardline, .hardline]), innerBlocks))
        innerDoc = .concat(["> ", .indent([joined])])

    case let list as MarkdownList:
        var items: [Doc] = []
        for (index, item) in list.items.enumerated() {
            let marker = list.isOrdered ? "\(index + 1). " : "- "
            let itemBodyDocs = item.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
            let itemContent = Doc.concat(join(separator: .concat([.hardline, .hardline]), itemBodyDocs))
            items.append(.concat([.text(marker), itemContent]))
        }
        innerDoc = .concat(join(separator: .hardline, items))

    case is MarkdownThematicBreak:
        innerDoc = .text("---")

    case let table as MarkdownTable:
        innerDoc = printTable(table)

    case let html as MarkdownHTMLBlock:
        innerDoc = .text(html.value)

    case let text as MarkdownText:
        innerDoc = .text(text.value)

    case let code as MarkdownInlineCode:
        innerDoc = .text("`\(code.value)`")

    case let strong as MarkdownStrong:
        let childrenDoc = strong.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat([.text("**")] + childrenDoc + [.text("**")])

    case let em as MarkdownEmphasis:
        let childrenDoc = em.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat([.text("*")] + childrenDoc + [.text("*")])

    case let link as MarkdownLink:
        let textDocs = link.children.map { printMarkdownNode($0, options: options, sourceText: sourceText) }
        var parts: [Doc] = [.text("[")] + textDocs + [.text("](\(link.url)")]
        if let title = link.title {
            parts.removeLast()
            parts.append(.text("](\(link.url) \"\(title)\")"))
        }
        innerDoc = .concat(parts)

    case let img as MarkdownImage:
        if let title = img.title {
            innerDoc = .text("![\(img.alt)](\(img.url) \"\(title)\")")
        } else {
            innerDoc = .text("![\(img.alt)](\(img.url))")
        }

    case is MarkdownBreak:
        innerDoc = .concat([.text("  "), .hardline])

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}

private func printTable(_ table: MarkdownTable) -> Doc {
    let colCount = max(table.headers.count, table.rows.map(\.count).max() ?? 0)
    guard colCount > 0 else { return .empty }

    var colWidths = Array(repeating: 3, count: colCount)

    for (col, header) in table.headers.enumerated() {
        if col < colWidths.count {
            colWidths[col] = max(colWidths[col], header.count)
        }
    }

    for row in table.rows {
        for (col, cell) in row.enumerated() {
            if col < colWidths.count {
                colWidths[col] = max(colWidths[col], cell.count)
            }
        }
    }

    func formatRow(_ cells: [String]) -> String {
        var rowStr = "| "
        for col in 0..<colCount {
            let cell = col < cells.count ? cells[col] : ""
            let width = colWidths[col]
            let padded = cell.padding(toLength: width, withPad: " ", startingAt: 0)
            rowStr += padded + " | "
        }
        rowStr.removeLast()
        return rowStr
    }

    func formatDelimiter() -> String {
        var delimStr = "| "
        for col in 0..<colCount {
            let width = colWidths[col]
            let align = col < table.alignments.count ? table.alignments[col] : .none
            var dashes: String
            switch align {
            case .none:
                dashes = String(repeating: "-", count: width)
            case .left:
                dashes = ":" + String(repeating: "-", count: max(width - 1, 1))
            case .center:
                dashes = ":" + String(repeating: "-", count: max(width - 2, 1)) + ":"
            case .right:
                dashes = String(repeating: "-", count: max(width - 1, 1)) + ":"
            }
            delimStr += dashes + " | "
        }
        delimStr.removeLast()
        return delimStr
    }

    var lines: [Doc] = []
    lines.append(.text(formatRow(table.headers)))
    lines.append(.hardline)
    lines.append(.text(formatDelimiter()))

    for row in table.rows {
        lines.append(.hardline)
        lines.append(.text(formatRow(row)))
    }

    return .concat(lines)
}
