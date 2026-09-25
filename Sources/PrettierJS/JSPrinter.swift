import Foundation
import PrettierDoc
import PrettierCore

public func formatJS(
    _ source: String,
    options: PrintOptions = PrintOptions()
) throws -> String {
    let (root, comments) = try JSParser.parse(source)
    attachComments(root: root, comments: comments, sourceText: source)
    let doc = printJSNode(root, options: options, sourceText: source)
    let output = try printDocToString(doc, options: options)
    return output.formatted
}

public func printJSNode(
    _ node: JSNode,
    options: PrintOptions,
    sourceText: String
) -> Doc {
    let innerDoc: Doc

    switch node {
    case let program as JSProgram:
        if program.body.isEmpty {
            innerDoc = .empty
        } else {
            let printed = printStatementSequence(program.body, options: options, sourceText: sourceText)
            innerDoc = .concat(printed + [.hardline])
        }

    case let varDecl as JSVariableDeclaration:
        var declDocs: [Doc] = []
        for decl in varDecl.declarations {
            let idDoc = printJSNode(decl.id, options: options, sourceText: sourceText)
            var typeDoc: Doc = .empty
            if let type = decl.typeAnnotation, !type.isEmpty {
                typeDoc = .text(": \(type)")
            }
            if let initVal = decl.initValue {
                let initDoc = printJSNode(initVal, options: options, sourceText: sourceText)
                declDocs.append(.concat([idDoc, typeDoc, .text(" = "), initDoc]))
            } else {
                declDocs.append(.concat([idDoc, typeDoc]))
            }
        }
        let joinedDecls = join(separator: .text(", "), declDocs)
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        innerDoc = .concat([.text("\(varDecl.kind) "), .concat(joinedDecls), semiDoc])

    case let fn as JSFunctionDeclaration:
        var prefix = fn.isAsync ? "async function" : "function"
        if let id = fn.id {
            prefix += " \(id.name)"
        }
        let paramDocs = fn.params.map { printJSNode($0, options: options, sourceText: sourceText) }
        let paramsGroup = join(separator: .text(", "), paramDocs)
        var returnTypeDoc: Doc = .empty
        if let returnType = fn.returnType, !returnType.isEmpty {
            returnTypeDoc = .text(": \(returnType)")
        }
        let bodyDoc = printJSNode(fn.body, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("\(prefix)("), .concat(paramsGroup), .text(")"), returnTypeDoc, .text(" "), bodyDoc])

    case let arrow as JSArrowFunctionExpression:
        let paramDocs = arrow.params.map { printJSNode($0, options: options, sourceText: sourceText) }
        let paramsGroup = join(separator: .text(", "), paramDocs)
        let asyncPrefix = arrow.isAsync ? "async " : ""
        let paramsDoc = Doc.concat([.text("\(asyncPrefix)("), .concat(paramsGroup), .text(")")])
        var returnTypeDoc: Doc = .empty
        if let returnType = arrow.returnType, !returnType.isEmpty {
            returnTypeDoc = .text(": \(returnType)")
        }

        var bodyDoc = printJSNode(arrow.body, options: options, sourceText: sourceText)
        if arrow.body is JSObjectExpression {
            bodyDoc = .concat([.text("("), bodyDoc, .text(")")])
        }
        innerDoc = .concat([paramsDoc, returnTypeDoc, .text(" => "), bodyDoc])

    case let block as JSBlockStatement:
        if block.body.isEmpty {
            innerDoc = .text("{}")
        } else {
            let bodyDocs = printStatementSequence(block.body, options: options, sourceText: sourceText)
            innerDoc = .concat([
                .text("{"),
                .indent(.concat([.hardline, .concat(bodyDocs)])),
                .hardline,
                .text("}")
            ])
        }

    case let ret as JSReturnStatement:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        if let arg = ret.argument {
            let argDoc = printJSNode(arg, options: options, sourceText: sourceText)
            innerDoc = .concat([.text("return "), argDoc, semiDoc])
        } else {
            innerDoc = .concat([.text("return"), semiDoc])
        }

    case let ifStmt as JSIfStatement:
        let testDoc = printJSNode(ifStmt.test, options: options, sourceText: sourceText)
        let consDoc = printJSNode(ifStmt.consequent, options: options, sourceText: sourceText)
        var parts: [Doc] = [.text("if ("), testDoc, .text(") "), consDoc]
        if let alt = ifStmt.alternate {
            let altDoc = printJSNode(alt, options: options, sourceText: sourceText)
            parts.append(.text(" else "))
            parts.append(altDoc)
        }
        innerDoc = .concat(parts)

    case let exprStmt as JSExpressionStatement:
        let exprDoc = printJSNode(exprStmt.expression, options: options, sourceText: sourceText)
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        innerDoc = .concat([exprDoc, semiDoc])

    case let bin as JSBinaryExpression:
        let leftDoc: Doc
        if shouldParenthesizeBinaryOperand(bin.left, parentOp: bin.operatorStr, isRight: false) {
            leftDoc = .concat([.text("("), printJSNode(bin.left, options: options, sourceText: sourceText), .text(")")])
        } else {
            leftDoc = printJSNode(bin.left, options: options, sourceText: sourceText)
        }

        let rightDoc: Doc
        if shouldParenthesizeBinaryOperand(bin.right, parentOp: bin.operatorStr, isRight: true) {
            rightDoc = .concat([.text("("), printJSNode(bin.right, options: options, sourceText: sourceText), .text(")")])
        } else {
            rightDoc = printJSNode(bin.right, options: options, sourceText: sourceText)
        }

        innerDoc = .concat([leftDoc, .text(" \(bin.operatorStr) "), rightDoc])

    case let un as JSUnaryExpression:
        let argDoc: Doc
        if un.argument is JSBinaryExpression || un.argument is JSArrowFunctionExpression {
            argDoc = .concat([.text("("), printJSNode(un.argument, options: options, sourceText: sourceText), .text(")")])
        } else {
            argDoc = printJSNode(un.argument, options: options, sourceText: sourceText)
        }
        if un.prefix {
            innerDoc = .concat([.text(un.operatorStr), argDoc])
        } else {
            innerDoc = .concat([argDoc, .text(un.operatorStr)])
        }

    case let call as JSCallExpression:
        let calleeDoc = printJSNode(call.callee, options: options, sourceText: sourceText)
        let typeArgsDoc: Doc
        if let typeArgs = call.typeArguments, !typeArgs.isEmpty {
            typeArgsDoc = printTypeArgumentsDoc(typeArgs)
        } else {
            typeArgsDoc = .empty
        }
        if call.arguments.isEmpty {
            innerDoc = .concat([calleeDoc, typeArgsDoc, .text("()")])
        } else {
            let argDocs = call.arguments.map { printJSNode($0, options: options, sourceText: sourceText) }
            let argsBody = join(separator: .concat([.text(","), .line]), argDocs)
            innerDoc = group(.concat([
                calleeDoc,
                typeArgsDoc,
                .text("("),
                .indent(.concat([.softline, .concat(argsBody)])),
                .softline,
                .text(")")
            ]))
        }

    case let member as JSMemberExpression:
        let objDoc = printJSNode(member.object, options: options, sourceText: sourceText)
        let propDoc = printJSNode(member.property, options: options, sourceText: sourceText)
        if member.computed {
            innerDoc = .concat([objDoc, .text("["), propDoc, .text("]")])
        } else {
            innerDoc = .concat([objDoc, .text("."), propDoc])
        }

    case let obj as JSObjectExpression:
        if obj.properties.isEmpty {
            innerDoc = .text("{}")
        } else {
            let propDocs = obj.properties.map { prop -> Doc in
                let keyDoc = printJSNode(prop.key, options: options, sourceText: sourceText)
                if prop.shorthand {
                    return keyDoc
                } else {
                    let valDoc = printJSNode(prop.value, options: options, sourceText: sourceText)
                    return .concat([keyDoc, .text(": "), valDoc])
                }
            }
            let joined = join(separator: .concat([.text(","), .line]), propDocs)
            let lineDoc = options.bracketSpacing ? Doc.line : Doc.softline
            innerDoc = group(.concat([
                .text("{"),
                .indent(.concat([lineDoc, .concat(joined)])),
                lineDoc,
                .text("}")
            ]))
        }

    case let arr as JSArrayExpression:
        if arr.elements.isEmpty {
            innerDoc = .text("[]")
        } else {
            let elemDocs = arr.elements.map { printJSNode($0, options: options, sourceText: sourceText) }
            let joined = join(separator: .concat([.text(","), .line]), elemDocs)
            innerDoc = group(.concat([
                .text("["),
                .indent(.concat([.softline, .concat(joined)])),
                .softline,
                .text("]")
            ]))
        }

    case let id as JSIdentifier:
        innerDoc = .text(id.name)

    case let lit as JSLiteral:
        if lit.isString {
            if options.singleQuote {
                let escaped = lit.value.replacingOccurrences(of: "'", with: "\\'")
                innerDoc = .text("'\(escaped)'")
            } else {
                let escaped = lit.value.replacingOccurrences(of: "\"", with: "\\\"")
                innerDoc = .text("\"\(escaped)\"")
            }
        } else {
            innerDoc = .text(lit.raw)
        }

    case let tmpl as JSTemplateLiteral:
        innerDoc = .text("`\(tmpl.quasis.joined(separator: ""))`")

    case let imp as JSImportDeclaration:
        var parts: [Doc] = [.text("import ")]
        if imp.isTypeOnly {
            parts.append(.text("type "))
        }

        var clauses: [Doc] = []
        if let def = imp.defaultSpecifier {
            clauses.append(.text(def.name))
        }
        if let ns = imp.namespaceSpecifier {
            clauses.append(.text("* as " + ns.name))
        }
        if !imp.specifiers.isEmpty {
            let specDocs: [Doc] = imp.specifiers.map { spec in
                var s = spec.isType ? "type " : ""
                if spec.imported.name == spec.local.name {
                    s += spec.imported.name
                } else {
                    s += spec.imported.name + " as " + spec.local.name
                }
                return .text(s)
            }
            let specGroup = join(separator: .text(", "), specDocs)
            if options.bracketSpacing {
                clauses.append(.concat([.text("{ "), .concat(specGroup), .text(" }")]))
            } else {
                clauses.append(.concat([.text("{"), .concat(specGroup), .text("}")]))
            }
        }

        let sourceDoc = printJSNode(imp.source, options: options, sourceText: sourceText)
        let semiDoc: Doc = options.semi ? .text(";") : .empty

        if clauses.isEmpty {
            parts.append(.concat([sourceDoc, semiDoc]))
        } else {
            let clauseDoc = join(separator: .text(", "), clauses)
            parts.append(.concat([.concat(clauseDoc), .text(" from "), sourceDoc, semiDoc]))
        }
        innerDoc = .concat(parts)

    case let expNamed as JSExportNamedDeclaration:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        if let decl = expNamed.declaration {
            let declDoc = printJSNode(decl, options: options, sourceText: sourceText)
            innerDoc = .concat([.text("export "), declDoc])
        } else if !expNamed.specifiers.isEmpty {
            let prefix = expNamed.isTypeOnly ? "export type " : "export "
            let specDocs: [Doc] = expNamed.specifiers.map { spec in
                let typePrefix = spec.isType ? "type " : ""
                if spec.local.name == spec.exported.name {
                    return .text("\(typePrefix)\(spec.local.name)")
                } else {
                    return .text("\(typePrefix)\(spec.local.name) as \(spec.exported.name)")
                }
            }
            let joined = join(separator: .text(", "), specDocs)
            let bracedDoc: Doc
            if options.bracketSpacing {
                bracedDoc = .concat([.text("{ "), .concat(joined), .text(" }")])
            } else {
                bracedDoc = .concat([.text("{"), .concat(joined), .text("}")])
            }
            if let source = expNamed.source {
                let sourceDoc = printJSNode(source, options: options, sourceText: sourceText)
                innerDoc = .concat([.text(prefix), bracedDoc, .text(" from "), sourceDoc, semiDoc])
            } else {
                innerDoc = .concat([.text(prefix), bracedDoc, semiDoc])
            }
        } else {
            innerDoc = .concat([.text("export"), semiDoc])
        }

    case let expAll as JSExportAllDeclaration:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        let prefix = expAll.isTypeOnly ? "export type * " : "export * "
        let sourceDoc = printJSNode(expAll.source, options: options, sourceText: sourceText)
        if let exported = expAll.exported {
            innerDoc = .concat([.text("\(prefix)as \(exported.name) from "), sourceDoc, semiDoc])
        } else {
            innerDoc = .concat([.text("\(prefix)from "), sourceDoc, semiDoc])
        }

    case let expDef as JSExportDefaultDeclaration:
        let declDoc = printJSNode(expDef.declaration, options: options, sourceText: sourceText)
        if expDef.declaration is JSFunctionDeclaration {
            innerDoc = .concat([.text("export default "), declDoc])
        } else {
            let semiDoc: Doc = options.semi ? .text(";") : .empty
            innerDoc = .concat([.text("export default "), declDoc, semiDoc])
        }

    case let typeAlias as JSTypeAliasDeclaration:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        let typeParams = typeAlias.typeParameters ?? ""
        innerDoc = .concat([.text("type \(typeAlias.id.name)\(typeParams) = "), .text(typeAlias.typeAnnotation), semiDoc])

    case let interfaceDecl as JSInterfaceDeclaration:
        let typeParams = interfaceDecl.typeParameters ?? ""
        let extendsPart = interfaceDecl.extendsClause != nil ? " extends \(interfaceDecl.extendsClause!)" : ""
        let bodyDoc = interfaceDecl.body
        innerDoc = .concat([.text("interface \(interfaceDecl.id.name)\(typeParams)\(extendsPart) "), .text(bodyDoc)])

    case let whileStmt as JSWhileStatement:
        let testDoc = printJSNode(whileStmt.test, options: options, sourceText: sourceText)
        let bodyDoc = printJSNode(whileStmt.body, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("while ("), testDoc, .text(") "), bodyDoc])

    case let forStmt as JSForStatement:
        let bodyDoc = printJSNode(forStmt.body, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("for (\(forStmt.header)) "), bodyDoc])

    case let tryStmt as JSTryStatement:
        let blockDoc = printJSNode(tryStmt.block, options: options, sourceText: sourceText)
        var parts: [Doc] = [.text("try "), blockDoc]
        if let handler = tryStmt.handler {
            let handlerDoc = printJSNode(handler, options: options, sourceText: sourceText)
            let paramPart = tryStmt.handlerParam != nil ? " (\(tryStmt.handlerParam!))" : ""
            parts.append(.text(" catch\(paramPart) "))
            parts.append(handlerDoc)
        }
        if let finalizer = tryStmt.finalizer {
            let finalizerDoc = printJSNode(finalizer, options: options, sourceText: sourceText)
            parts.append(.text(" finally "))
            parts.append(finalizerDoc)
        }
        innerDoc = .concat(parts)

    case let throwStmt as JSThrowStatement:
        let argDoc = printJSNode(throwStmt.argument, options: options, sourceText: sourceText)
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        innerDoc = .concat([.text("throw "), argDoc, semiDoc])

    case let newExpr as JSNewExpression:
        let calleeDoc = printJSNode(newExpr.callee, options: options, sourceText: sourceText)
        let typeArgsDoc: Doc
        if let typeArgs = newExpr.typeArguments, !typeArgs.isEmpty {
            typeArgsDoc = printTypeArgumentsDoc(typeArgs)
        } else {
            typeArgsDoc = .empty
        }
        if newExpr.arguments.isEmpty {
            innerDoc = .concat([.text("new "), calleeDoc, typeArgsDoc, .text("()")])
        } else {
            let argDocs = newExpr.arguments.map { printJSNode($0, options: options, sourceText: sourceText) }
            let argsBody = join(separator: .concat([.text(","), .line]), argDocs)
            innerDoc = group(.concat([
                .text("new "),
                calleeDoc,
                typeArgsDoc,
                .text("("),
                .indent(.concat([.softline, .concat(argsBody)])),
                .softline,
                .text(")")
            ]))
        }


    case let awaitExpr as JSAwaitExpression:
        let argDoc = printJSNode(awaitExpr.argument, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("await "), argDoc])

    default:
        innerDoc = .empty
    }

    return CommentPrinter.wrapWithComments(doc: innerDoc, node: node, sourceText: sourceText)
}

private func jsOperatorPrecedence(_ op: String) -> Int {
    switch op {
    case "=", "+=", "-=", "*=", "/=": return 1
    case "??": return 2
    case "||": return 3
    case "&&": return 4
    case "|": return 5
    case "^": return 6
    case "&": return 7
    case "===", "!==", "==", "!=": return 8
    case "<=", ">=", "<", ">", "instanceof", "in": return 9
    case "<<", ">>", ">>>": return 10
    case "+", "-": return 11
    case "*", "/", "%": return 12
    case "**": return 13
    default: return 0
    }
}

private func shouldParenthesizeBinaryOperand(_ child: JSNode, parentOp: String, isRight: Bool) -> Bool {
    if child is JSArrowFunctionExpression {
        return true
    }
    guard let childBin = child as? JSBinaryExpression else {
        return false
    }
    let parentPrec = jsOperatorPrecedence(parentOp)
    let childPrec = jsOperatorPrecedence(childBin.operatorStr)

    if childPrec < parentPrec {
        return true
    }
    if isRight && childPrec == parentPrec {
        if parentOp == "-" || parentOp == "/" || parentOp == "%" {
            return true
        }
    }
    return false
}

private func hasBlankLineBetween(current: JSNode, next: JSNode, in sourceText: String) -> Bool {
    guard !sourceText.isEmpty else { return false }

    let currentEnd: Int
    if let maxTrailing = current.comments.filter({ $0.trailing }).map({ $0.range.upperBound }).max() {
        currentEnd = max(current.sourceRange.upperBound, maxTrailing)
    } else {
        currentEnd = current.sourceRange.upperBound
    }

    let nextStart: Int
    if let minLeading = next.comments.filter({ $0.leading }).map({ $0.range.lowerBound }).min() {
        nextStart = min(next.sourceRange.lowerBound, minLeading)
    } else {
        nextStart = next.sourceRange.lowerBound
    }

    guard currentEnd > 0 && nextStart >= currentEnd else { return false }

    let utf8 = sourceText.utf8
    guard currentEnd <= utf8.count && nextStart <= utf8.count else { return false }

    let startIdx = utf8.index(utf8.startIndex, offsetBy: currentEnd)
    let endIdx = utf8.index(utf8.startIndex, offsetBy: nextStart)

    var newlineCount = 0
    var idx = startIdx
    while idx < endIdx {
        let byte = utf8[idx]
        if byte == 0x0A { // '\n'
            newlineCount += 1
            if newlineCount >= 2 {
                return true
            }
        }
        idx = utf8.index(after: idx)
    }

    return false
}

private func printStatementSequence(
    _ statements: [JSNode],
    options: PrintOptions,
    sourceText: String
) -> [Doc] {
    guard !statements.isEmpty else { return [] }
    var docs: [Doc] = []

    for i in 0..<statements.count {
        let current = statements[i]
        let currentDoc = printJSNode(current, options: options, sourceText: sourceText)
        docs.append(currentDoc)

        if i < statements.count - 1 {
            let next = statements[i + 1]
            if hasBlankLineBetween(current: current, next: next, in: sourceText) {
                docs.append(.hardline)
                docs.append(.hardline)
            } else {
                docs.append(.hardline)
            }
        }
    }

    return docs
}

private func printTypeArgumentsDoc(_ typeArgs: String) -> Doc {
    guard typeArgs.hasPrefix("<") && typeArgs.hasSuffix(">") else {
        return .text(typeArgs)
    }
    let inner = typeArgs.dropFirst().dropLast()
    let parts = splitTypeArguments(String(inner))
    guard parts.count > 1 else {
        return .text(typeArgs)
    }
    let typeDocs = parts.map { Doc.text($0) }
    let typeBody = join(separator: .concat([.text(","), .line]), typeDocs)
    return group(.concat([
        .text("<"),
        .indent(.concat([.softline, .concat(typeBody)])),
        .softline,
        .text(">")
    ]))
}

private func splitTypeArguments(_ inner: String) -> [String] {
    var parts: [String] = []
    var start = inner.startIndex
    var i = inner.startIndex
    var parenDepth = 0
    var braceDepth = 0
    var bracketDepth = 0
    var angleDepth = 0
    var inString: Character? = nil

    while i < inner.endIndex {
        let ch = inner[i]
        if let quote = inString {
            if ch == "\\" {
                i = inner.index(after: i)
                if i < inner.endIndex { i = inner.index(after: i) }
                continue
            } else if ch == quote {
                inString = nil
            }
        } else {
            if ch == "\"" || ch == "'" || ch == "`" {
                inString = ch
            } else if ch == "(" { parenDepth += 1 }
            else if ch == ")" { parenDepth = max(0, parenDepth - 1) }
            else if ch == "{" { braceDepth += 1 }
            else if ch == "}" { braceDepth = max(0, braceDepth - 1) }
            else if ch == "[" { bracketDepth += 1 }
            else if ch == "]" { bracketDepth = max(0, bracketDepth - 1) }
            else if ch == "<" { angleDepth += 1 }
            else if ch == ">" { angleDepth = max(0, angleDepth - 1) }
            else if ch == "," && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                let part = String(inner[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { parts.append(part) }
                start = inner.index(after: i)
            }
        }
        i = inner.index(after: i)
    }
    let last = String(inner[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !last.isEmpty { parts.append(last) }
    return parts
}
