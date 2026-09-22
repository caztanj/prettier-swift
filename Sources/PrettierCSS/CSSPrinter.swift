import Foundation
import PrettierDoc
import PrettierCore

public func formatCSS(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try CSSParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printCSSNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printCSSNode(
    _ node: CSSNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let sheet as CSSStyleSheet:
        let printedChildren = sheet.children.map { printCSSNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat(join(separator: .concat([.hardline, .hardline]), printedChildren) + [.hardline])

    case let rule as CSSRule:
        let selectorDoc: Doc
        if rule.selectors.count == 1 {
            selectorDoc = .text(rule.selectors[0])
        } else {
            let joinedSelectors = join(separator: .concat([",", .hardline]), rule.selectors.map { Doc.text($0) })
            selectorDoc = .concat(joinedSelectors)
        }

        if rule.body.isEmpty {
            innerDoc = .concat([selectorDoc, " {}"])
        } else {
            let bodyDocs = rule.body.map { printCSSNode($0, options: options, sourceText: sourceText) }
            let bodyContent = join(separator: .hardline, bodyDocs)
            innerDoc = .concat([
                selectorDoc,
                " {",
                .indent([.hardline, .concat(bodyContent)]),
                .hardline,
                "}"
            ])
        }

    case let decl as CSSDeclaration:
        var text = "\(decl.property): \(decl.value)"
        if decl.important {
            text += " !important"
        }
        text += ";"
        innerDoc = .text(text)

    case let atRule as CSSAtRule:
        let prefix = atRule.params.isEmpty ? atRule.name : "\(atRule.name) \(atRule.params)"
        if let block = atRule.block {
            if block.isEmpty {
                innerDoc = .text("\(prefix) {}")
            } else {
                let bodyDocs = block.map { printCSSNode($0, options: options, sourceText: sourceText) }
                let isAllDeclarations = block.allSatisfy { $0 is CSSDeclaration }
                let separator: Doc = isAllDeclarations ? .hardline : .concat([.hardline, .hardline])
                let bodyContent = join(separator: separator, bodyDocs)
                innerDoc = .concat([
                    .text(prefix),
                    " {",
                    .indent([.hardline, .concat(bodyContent)]),
                    .hardline,
                    "}"
                ])
            }
        } else {
            innerDoc = .text("\(prefix);")
        }

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}
