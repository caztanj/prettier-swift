import Foundation
import PrettierDoc
import PrettierCore

public func formatGraphQL(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try GraphQLParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printGraphQLNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printGraphQLNode(
    _ node: GraphQLNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let doc as GraphQLDocument:
        let defDocs = doc.definitions.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat(join(separator: .concat([.hardline, .hardline]), defDocs) + [.hardline])

    case let op as GraphQLOperation:
        var headerParts: [Doc] = []
        if let name = op.name {
            headerParts.append(.text("\(op.operationType) \(name)"))
        } else if !op.variables.isEmpty || !op.directives.isEmpty || op.operationType != "query" {
            headerParts.append(.text(op.operationType))
        }

        if !op.variables.isEmpty {
            let varDocs = op.variables.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            headerParts.append(.concat([.text("("), .concat(join(separator: .text(", "), varDocs)), .text(")")]))
        }

        for dir in op.directives {
            headerParts.append(.text(" "))
            headerParts.append(printGraphQLNode(dir, options: options, sourceText: sourceText))
        }

        let selSetDoc = printGraphQLNode(op.selectionSet, options: options, sourceText: sourceText)
        if headerParts.isEmpty {
            innerDoc = selSetDoc
        } else {
            innerDoc = .concat(join(separator: .text(""), headerParts) + [.text(" "), selSetDoc])
        }

    case let frag as GraphQLFragment:
        var headerParts: [Doc] = [.text("fragment \(frag.name) on \(frag.typeCondition)")]
        for dir in frag.directives {
            headerParts.append(.text(" "))
            headerParts.append(printGraphQLNode(dir, options: options, sourceText: sourceText))
        }
        let selSetDoc = printGraphQLNode(frag.selectionSet, options: options, sourceText: sourceText)
        innerDoc = .concat(join(separator: .text(""), headerParts) + [.text(" "), selSetDoc])

    case let selSet as GraphQLSelectionSet:
        if selSet.selections.isEmpty {
            innerDoc = .text("{}")
        } else {
            let selDocs = selSet.selections.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            let selGroup = join(separator: .hardline, selDocs)
            innerDoc = .concat([
                .text("{"),
                .indent(.concat([.hardline, .concat(selGroup)])),
                .hardline,
                .text("}")
            ])
        }

    case let field as GraphQLField:
        var parts: [Doc] = []
        if let alias = field.alias {
            parts.append(.text("\(alias): "))
        }
        parts.append(.text(field.name))

        if !field.arguments.isEmpty {
            let argDocs = field.arguments.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            parts.append(.concat([.text("("), .concat(join(separator: .text(", "), argDocs)), .text(")")]))
        }

        for dir in field.directives {
            parts.append(.text(" "))
            parts.append(printGraphQLNode(dir, options: options, sourceText: sourceText))
        }

        if let subSel = field.selectionSet {
            parts.append(.text(" "))
            parts.append(printGraphQLNode(subSel, options: options, sourceText: sourceText))
        }
        innerDoc = .concat(parts)

    case let spread as GraphQLFragmentSpread:
        var parts: [Doc] = [.text("...\(spread.name)")]
        for dir in spread.directives {
            parts.append(.text(" "))
            parts.append(printGraphQLNode(dir, options: options, sourceText: sourceText))
        }
        innerDoc = .concat(parts)

    case let inline as GraphQLInlineFragment:
        var parts: [Doc] = [.text("...")]
        if let cond = inline.typeCondition {
            parts.append(.text(" on \(cond)"))
        }
        for dir in inline.directives {
            parts.append(.text(" "))
            parts.append(printGraphQLNode(dir, options: options, sourceText: sourceText))
        }
        parts.append(.text(" "))
        parts.append(printGraphQLNode(inline.selectionSet, options: options, sourceText: sourceText))
        innerDoc = .concat(parts)

    case let arg as GraphQLArgument:
        innerDoc = .text("\(arg.name): \(arg.value)")

    case let dir as GraphQLDirective:
        if dir.arguments.isEmpty {
            innerDoc = .text(dir.name)
        } else {
            let argDocs = dir.arguments.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            innerDoc = .concat([.text("\(dir.name)("), .concat(join(separator: .text(", "), argDocs)), .text(")")])
        }

    case let v as GraphQLVariableDefinition:
        if let def = v.defaultValue {
            innerDoc = .text("\(v.variable): \(v.type) = \(def)")
        } else {
            innerDoc = .text("\(v.variable): \(v.type)")
        }

    case let typeDef as GraphQLTypeDefinition:
        if typeDef.fields.isEmpty {
            innerDoc = .text("\(typeDef.kind) \(typeDef.name)")
        } else {
            let fieldDocs = typeDef.fields.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            let fieldGroup = join(separator: .hardline, fieldDocs)
            innerDoc = .concat([
                .text("\(typeDef.kind) \(typeDef.name) {"),
                .indent(.concat([.hardline, .concat(fieldGroup)])),
                .hardline,
                .text("}")
            ])
        }

    case let fieldDef as GraphQLFieldDefinition:
        if fieldDef.arguments.isEmpty {
            if fieldDef.type.isEmpty {
                innerDoc = .text(fieldDef.name)
            } else {
                innerDoc = .text("\(fieldDef.name): \(fieldDef.type)")
            }
        } else {
            let argDocs = fieldDef.arguments.map { printGraphQLNode($0, options: options, sourceText: sourceText) }
            let argsGroup = join(separator: .text(", "), argDocs)
            innerDoc = .concat([.text("\(fieldDef.name)("), .concat(argsGroup), .text("): \(fieldDef.type)")])
        }

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}
