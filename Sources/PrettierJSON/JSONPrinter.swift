import PrettierDoc
import PrettierCore

public func formatJSON(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try JSONParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let path = AstPath(root)
    let doc = printJSONNode(path: path, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printJSONNode(
    path: AstPath,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    guard let node = path.node as? JSONNode else {
        return .empty
    }

    let innerDoc: Doc
    switch node {
    case let root as JSONRoot:
        let printedValue = path.call(key: "value", root.value) { p in
            printJSONNode(path: p, options: options, sourceText: sourceText)
        }
        innerDoc = .concat([printedValue, .hardline])

    case let obj as JSONObject:
        if obj.properties.isEmpty {
            let dangling = CommentPrinter.printDangling(comments: obj.comments, indent: true)
            if dangling == .empty {
                innerDoc = "{}"
            } else {
                innerDoc = .concat(["{", dangling, .hardline, "}"])
            }
        } else {
            let printedProps = path.map(key: "properties", obj.properties) { p, _, _ in
                printJSONNode(path: p, options: options, sourceText: sourceText)
            }
            let body = join(separator: .concat([",", .line]), printedProps)
            innerDoc = group(.concat([
                "{",
                .indent([.line, .concat(body)]),
                .line,
                "}"
            ]))
        }

    case let prop as JSONProperty:
        let keyDoc = path.call(key: "key", prop.key) { p in
            printJSONNode(path: p, options: options, sourceText: sourceText)
        }
        let valDoc = path.call(key: "value", prop.value) { p in
            printJSONNode(path: p, options: options, sourceText: sourceText)
        }
        innerDoc = .concat([keyDoc, ": ", valDoc])

    case let arr as JSONArray:
        if arr.elements.isEmpty {
            let dangling = CommentPrinter.printDangling(comments: arr.comments, indent: true)
            if dangling == .empty {
                innerDoc = "[]"
            } else {
                innerDoc = .concat(["[", dangling, .hardline, "]"])
            }
        } else {
            let printedElements = path.map(key: "elements", arr.elements) { p, _, _ in
                printJSONNode(path: p, options: options, sourceText: sourceText)
            }
            let body = join(separator: .concat([",", .line]), printedElements)
            innerDoc = group(.concat([
                "[",
                .indent([.softline, .concat(body)]),
                .softline,
                "]"
            ]))
        }

    case let str as JSONString:
        innerDoc = .text(escapeJSONString(str.value))

    case let num as JSONNumber:
        innerDoc = .text(num.raw)

    case let boolNode as JSONBoolean:
        innerDoc = .text(boolNode.value ? "true" : "false")

    case _ as JSONNull:
        innerDoc = "null"

    case let id as JSONIdentifier:
        innerDoc = .text(escapeJSONString(id.name))

    default:
        innerDoc = .empty
    }

    if node is JSONRoot {
        return innerDoc
    }
    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}

public func escapeJSONString(_ str: String) -> String {
    var out = "\""
    for ch in str {
        switch ch {
        case "\"": out.append("\\\"")
        case "\\": out.append("\\\\")
        case "\n": out.append("\\n")
        case "\r": out.append("\\r")
        case "\t": out.append("\\t")
        default:
            out.append(ch)
        }
    }
    out.append("\"")
    return out
}
