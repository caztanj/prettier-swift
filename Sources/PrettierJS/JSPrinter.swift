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
        let printedStatements = program.body.map { printJSNode($0, options: options, sourceText: sourceText) }
        innerDoc = .concat(join(separator: .hardline, printedStatements) + [.hardline])

    case let varDecl as JSVariableDeclaration:
        var declDocs: [Doc] = []
        for decl in varDecl.declarations {
            let idDoc = printJSNode(decl.id, options: options, sourceText: sourceText)
            if let initVal = decl.initValue {
                let initDoc = printJSNode(initVal, options: options, sourceText: sourceText)
                declDocs.append(.concat([idDoc, .text(" = "), initDoc]))
            } else {
                declDocs.append(idDoc)
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
            let bodyDocs = block.body.map { printJSNode($0, options: options, sourceText: sourceText) }
            let bodyGroup = join(separator: .hardline, bodyDocs)
            innerDoc = .concat([
                .text("{"),
                .indent(.concat([.hardline, .concat(bodyGroup)])),
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
        innerDoc = .concat([.text(un.operatorStr), argDoc])

    case let call as JSCallExpression:
        let calleeDoc = printJSNode(call.callee, options: options, sourceText: sourceText)
        let argDocs = call.arguments.map { printJSNode($0, options: options, sourceText: sourceText) }
        let argsGroup = join(separator: .text(", "), argDocs)
        innerDoc = .concat([calleeDoc, .text("("), .concat(argsGroup), .text(")")])

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
            let joined = join(separator: .text(", "), propDocs)
            if options.bracketSpacing {
                innerDoc = .concat([.text("{ "), .concat(joined), .text(" }")])
            } else {
                innerDoc = .concat([.text("{"), .concat(joined), .text("}")])
            }
        }

    case let arr as JSArrayExpression:
        if arr.elements.isEmpty {
            innerDoc = .text("[]")
        } else {
            let elemDocs = arr.elements.map { printJSNode($0, options: options, sourceText: sourceText) }
            let joined = join(separator: .text(", "), elemDocs)
            innerDoc = .concat([.text("["), .concat(joined), .text("]")])
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
        if let decl = expNamed.declaration {
            let declDoc = printJSNode(decl, options: options, sourceText: sourceText)
            innerDoc = .concat([.text("export "), declDoc])
        } else {
            innerDoc = .text("export;")
        }

    case let expDef as JSExportDefaultDeclaration:
        let declDoc = printJSNode(expDef.declaration, options: options, sourceText: sourceText)
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        innerDoc = .concat([.text("export default "), declDoc, semiDoc])

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
