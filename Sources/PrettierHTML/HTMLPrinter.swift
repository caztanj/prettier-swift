import Foundation
import PrettierDoc
import PrettierCore

public func formatHTML(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try HTMLParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printHTMLNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printHTMLNode(
    _ node: HTMLNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let doc as HTMLDocument:
        let printedNodes = doc.children.map { printHTMLNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat(join(separator: .hardline, printedNodes) + [.hardline])

    case let doctype as HTMLDoctype:
        let trimmed = doctype.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "<!doctype html>" {
            innerDoc = .text("<!doctype html>")
        } else {
            innerDoc = .text(trimmed)
        }

    case let elem as HTMLElement:
        let tag = elem.tag.lowercased()

        var attrDocs: [Doc] = []
        for attr in elem.attributes {
            attrDocs.append(printAttribute(attr))
        }

        let openTagStart = Doc.text("<\(tag)")
        let openTagAttrs: Doc
        if attrDocs.isEmpty {
            openTagAttrs = .empty
        } else {
            let joined = join(separator: .line, attrDocs)
            openTagAttrs = .concat([.text(" "), group(.concat(joined))])
        }

        if elem.isSelfClosing {
            innerDoc = .concat([openTagStart, openTagAttrs, .text(" />")])
        } else if elem.isVoid {
            innerDoc = .concat([openTagStart, openTagAttrs, .text(">")])
        } else if elem.children.isEmpty {
            innerDoc = .concat([openTagStart, openTagAttrs, .text("></\(tag)>")])
        } else if elem.children.count == 1, let textNode = elem.children[0] as? HTMLText {
            innerDoc = .concat([openTagStart, openTagAttrs, .text(">"), .text(textNode.value), .text("</\(tag)>")])
        } else {
            let childDocs = elem.children.map { printHTMLNode($0, options: options, sourceText: sourceText) }
            let childrenGroup = join(separator: .hardline, childDocs)
            innerDoc = .concat([
                openTagStart,
                openTagAttrs,
                .text(">"),
                .indent(.concat([.hardline, .concat(childrenGroup)])),
                .hardline,
                .text("</\(tag)>")
            ])
        }

    case let text as HTMLText:
        innerDoc = .text(text.value)

    case let attr as HTMLAttribute:
        innerDoc = printAttribute(attr)

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}

private func printAttribute(_ attr: HTMLAttribute) -> Doc {
    if let val = attr.value {
        return .text("\(attr.name)=\"\(val)\"")
    } else {
        return .text(attr.name)
    }
}
