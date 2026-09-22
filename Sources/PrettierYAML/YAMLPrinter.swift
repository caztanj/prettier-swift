import PrettierDoc
import PrettierCore

public func formatYAML(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try YAMLParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printYAMLNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printYAMLNode(
    _ node: YAMLNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let doc as YAMLDocument:
        var parts: [Doc] = []
        if doc.hasDirectivesEnd {
            parts.append("---")
            parts.append(.hardline)
        }
        if let body = doc.body {
            parts.append(printYAMLNode(body, options: options, sourceText: sourceText))
        }
        parts.append(.hardline)
        return .concat(parts)

    case let mapping as YAMLMapping:
        let printedItems = mapping.items.map { item in
            printYAMLNode(item, options: options, sourceText: sourceText)
        }
        innerDoc = .concat(join(separator: .hardline, printedItems))

    case let item as YAMLMappingItem:
        let keyDoc = printYAMLNode(item.key, options: options, sourceText: sourceText)
        if let val = item.value {
            if val is YAMLMapping || val is YAMLSequence {
                let valDoc = printYAMLNode(val, options: options, sourceText: sourceText)
                innerDoc = .concat([keyDoc, ":", .indent([.hardline, valDoc])])
            } else {
                let valDoc = printYAMLNode(val, options: options, sourceText: sourceText)
                innerDoc = .concat([keyDoc, ": ", valDoc])
            }
        } else {
            innerDoc = .concat([keyDoc, ":"])
        }

    case let seq as YAMLSequence:
        let printedItems = seq.items.map { elem in
            let elemDoc = printYAMLNode(elem, options: options, sourceText: sourceText)
            if elem is YAMLMapping {
                return Doc.concat(["- ", elemDoc])
            } else if elem is YAMLSequence {
                return Doc.concat(["-", .indent([.hardline, elemDoc])])
            } else {
                return Doc.concat(["- ", elemDoc])
            }
        }
        innerDoc = .concat(join(separator: .hardline, printedItems))

    case let scalar as YAMLScalar:
        switch scalar.style {
        case .singleQuote:
            innerDoc = .text("'\(scalar.value)'")
        case .doubleQuote:
            innerDoc = .text("\"\(scalar.value)\"")
        case .plain, .literal, .folded:
            innerDoc = .text(scalar.value)
        }

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}
