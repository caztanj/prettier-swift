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
                if initVal is JSConditionalExpression {
                    let flat = Doc.concat([idDoc, typeDoc, .text(" = "), initDoc])
                    let broken = Doc.concat([idDoc, typeDoc, .text(" ="), .indent(.concat([.line, initDoc]))])
                    declDocs.append(conditionalGroup([flat, broken]))
                } else {
                    declDocs.append(.concat([idDoc, typeDoc, .text(" = "), initDoc]))
                }
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
        } else if fn.typeParameters == nil || fn.typeParameters!.isEmpty {
            prefix += " "
        }
        let typeParamsDoc: Doc
        if let typeParams = fn.typeParameters, !typeParams.isEmpty {
            typeParamsDoc = printTypeArgumentsDoc(typeParams)
        } else {
            typeParamsDoc = .empty
        }
        let paramDocs = fn.params.map { printJSNode($0, options: options, sourceText: sourceText) }
        var returnTypeDoc: Doc = .empty
        if let returnType = fn.returnType, !returnType.isEmpty {
            returnTypeDoc = .text(": \(returnType)")
        }

        let paramsDoc: Doc
        if fn.params.isEmpty {
            paramsDoc = .text("()")
        } else if fn.params.count == 1, let firstParamStr = (fn.params.first as? JSIdentifier)?.name, firstParamStr.contains("\n") {
            paramsDoc = .concat([.text("("), .text(firstParamStr), .text(")")])
        } else {
            let joinedMulti = join(separator: .concat([.text(","), .line]), paramDocs)
            let hasRest = fn.params.last.map { ($0 as? JSIdentifier)?.name.hasPrefix("...") ?? false } ?? false
            let trailingCommaDoc = hasRest ? Doc.empty : .ifBreak(breakContents: .text(","), flatContents: .empty)
            paramsDoc = group(.concat([
                .text("("),
                .indent(.concat([.softline, .concat(joinedMulti), trailingCommaDoc])),
                .softline,
                .text(")")
            ]))
        }

        if let body = fn.body {
            let bodyDoc = printJSNode(body, options: options, sourceText: sourceText)
            innerDoc = .concat([.text(prefix), typeParamsDoc, paramsDoc, returnTypeDoc, .text(" "), bodyDoc])
        } else {
            let semiDoc: Doc = options.semi ? .text(";") : .empty
            innerDoc = .concat([.text(prefix), typeParamsDoc, paramsDoc, returnTypeDoc, semiDoc])
        }

    case let arrow as JSArrowFunctionExpression:
        let typeParamsDoc: Doc
        if let typeParams = arrow.typeParameters, !typeParams.isEmpty {
            typeParamsDoc = printTypeArgumentsDoc(typeParams)
        } else {
            typeParamsDoc = .empty
        }
        let paramDocs = arrow.params.map { printJSNode($0, options: options, sourceText: sourceText) }
        let asyncPrefix = arrow.isAsync ? "async " : ""
        let paramsDoc: Doc
        if arrow.params.isEmpty {
            paramsDoc = .text("\(asyncPrefix)()")
        } else {
            let joinedMulti = join(separator: .concat([.text(","), .line]), paramDocs)
            let hasRest = arrow.params.last.map { ($0 as? JSIdentifier)?.name.hasPrefix("...") ?? false } ?? false
            let trailingCommaDoc = hasRest ? Doc.empty : .ifBreak(breakContents: .text(","), flatContents: .empty)
            paramsDoc = group(.concat([
                .text("\(asyncPrefix)("),
                .indent(.concat([.softline, .concat(joinedMulti), trailingCommaDoc])),
                .softline,
                .text(")")
            ]))
        }
        var returnTypeDoc: Doc = .empty
        if let returnType = arrow.returnType, !returnType.isEmpty {
            returnTypeDoc = .text(": \(returnType)")
        }

        var bodyDoc = printJSNode(arrow.body, options: options, sourceText: sourceText)
        if arrow.body is JSObjectExpression {
            bodyDoc = .concat([.text("("), bodyDoc, .text(")")])
        }
        if let innerArrow = arrow.body as? JSArrowFunctionExpression {
            if innerArrow.body is JSBlockStatement {
                innerDoc = .concat([typeParamsDoc, paramsDoc, returnTypeDoc, .text(" => "), bodyDoc])
            } else {
                innerDoc = .concat([typeParamsDoc, paramsDoc, returnTypeDoc, .text(" =>"), .indent(.concat([.hardline, bodyDoc]))])
            }
        } else if arrow.isCurried && !(arrow.body is JSBlockStatement) {
            innerDoc = .concat([typeParamsDoc, paramsDoc, returnTypeDoc, .text(" =>"), .indent(.concat([.hardline, bodyDoc]))])
        } else if arrow.body is JSBlockStatement {
            innerDoc = .concat([typeParamsDoc, paramsDoc, returnTypeDoc, .text(" => "), bodyDoc])
        } else {
            innerDoc = group(.concat([typeParamsDoc, paramsDoc, returnTypeDoc, .text(" =>"), .indent(.concat([.line, bodyDoc]))]))
        }

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
            if let paren = arg as? JSParenthesizedExpression, let bin = paren.expression as? JSBinaryExpression {
                let binDoc = printBinaryExpressionFlat(bin, options: options, sourceText: sourceText)
                let flatDoc = Doc.concat([.text("return ("), binDoc, .text(")"), semiDoc])
                let breakDoc = Doc.concat([
                    .text("return ("),
                    .indent(.concat([.line, binDoc])),
                    .line,
                    .text(")"),
                    semiDoc
                ])
                innerDoc = conditionalGroup([flatDoc, breakDoc])
            } else if let bin = arg as? JSBinaryExpression {
                let flatDoc = Doc.concat([.text("return "), printJSNode(bin, options: options, sourceText: sourceText), semiDoc])
                let breakDoc = Doc.concat([
                    .text("return ("),
                    .indent(.concat([.line, printBinaryExpressionFlat(bin, options: options, sourceText: sourceText)])),
                    .line,
                    .text(")"),
                    semiDoc
                ])
                innerDoc = conditionalGroup([flatDoc, breakDoc])
            } else {
                let argDoc = printJSNode(arg, options: options, sourceText: sourceText)
                innerDoc = .concat([.text("return "), argDoc, semiDoc])
            }
        } else {
            innerDoc = .concat([.text("return"), semiDoc])
        }

    case let ifStmt as JSIfStatement:
        let testDoc: Doc
        if let bin = ifStmt.test as? JSBinaryExpression {
            testDoc = printBinaryExpressionFlat(bin, options: options, sourceText: sourceText)
        } else {
            testDoc = printJSNode(ifStmt.test, options: options, sourceText: sourceText)
        }
        let consDoc = printJSNode(ifStmt.consequent, options: options, sourceText: sourceText)
        let headerDoc = group(.concat([
            .text("if ("),
            .indent(.concat([.softline, testDoc])),
            .softline,
            .text(") ")
        ]))
        var parts: [Doc] = [headerDoc, consDoc]
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
        let isAssignment = bin.operatorStr.hasSuffix("=") && bin.operatorStr != "==" && bin.operatorStr != "===" && bin.operatorStr != "!=" && bin.operatorStr != "!==" && bin.operatorStr != "<=" && bin.operatorStr != ">="
        if isAssignment {
            let leftDoc = printJSNode(bin.left, options: options, sourceText: sourceText)
            let rightDoc = printJSNode(bin.right, options: options, sourceText: sourceText)
            innerDoc = group(.concat([leftDoc, .text(" \(bin.operatorStr)"), .indent(.concat([.line, rightDoc]))]))
            break
        }

        var operands: [JSNode] = []
        var curr: JSNode = bin
        while let b = curr as? JSBinaryExpression, b.operatorStr == bin.operatorStr {
            operands.insert(b.right, at: 0)
            curr = b.left
        }
        operands.insert(curr, at: 0)

        let firstNode = operands[0]
        let firstNeedParen = shouldParenthesizeBinaryOperand(firstNode, parentOp: bin.operatorStr, isRight: false)
        let firstNodeDoc = printJSNode(firstNode, options: options, sourceText: sourceText)
        let firstDoc = firstNeedParen ? .concat([.text("("), firstNodeDoc, .text(")")]) : firstNodeDoc

        var restParts: [Doc] = []
        for i in 1..<operands.count {
            let opNode = operands[i]
            let needParen = shouldParenthesizeBinaryOperand(opNode, parentOp: bin.operatorStr, isRight: true)
            let nodeDoc = printJSNode(opNode, options: options, sourceText: sourceText)
            let wrappedDoc = needParen ? .concat([.text("("), nodeDoc, .text(")")]) : nodeDoc

            let isEqualityComparison = bin.operatorStr == "===" || bin.operatorStr == "!==" || bin.operatorStr == "==" || bin.operatorStr == "!="
            let shouldInlineOperand = isEqualityComparison && (opNode is JSLiteral || (opNode as? JSIdentifier)?.name == "undefined" || (opNode as? JSIdentifier)?.name == "null")
            if shouldInlineOperand {
                restParts.append(.text(" \(bin.operatorStr) "))
                restParts.append(wrappedDoc)
            } else {
                restParts.append(.text(" \(bin.operatorStr)"))
                restParts.append(.line)
                restParts.append(wrappedDoc)
            }
        }

        innerDoc = group(.concat([firstDoc, .indent(.concat(restParts))]))

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
        if let member = call.callee as? JSMemberExpression, !member.computed, member.object is JSCallExpression {
            var chain: [(member: JSMemberExpression, typeArgs: String?, args: [JSNode])] = []
            var currentCall: JSCallExpression? = call
            var baseNode: JSNode = call

            while let c = currentCall, let m = c.callee as? JSMemberExpression, !m.computed {
                chain.append((member: m, typeArgs: c.typeArguments, args: c.arguments))
                if let nextCall = m.object as? JSCallExpression {
                    currentCall = nextCall
                } else {
                    baseNode = m.object
                    currentCall = nil
                }
            }

            if chain.count >= 3 {
                chain.reverse()
                let baseDoc = printJSNode(baseNode, options: options, sourceText: sourceText)

                func formatChainItem(_ item: (member: JSMemberExpression, typeArgs: String?, args: [JSNode])) -> Doc {
                    let propDoc = printJSNode(item.member.property, options: options, sourceText: sourceText)
                    let typeArgsDoc = (item.typeArgs != nil && !item.typeArgs!.isEmpty) ? printTypeArgumentsDoc(item.typeArgs!) : .empty
                    let argDocs = item.args.map { printJSNode($0, options: options, sourceText: sourceText) }
                    let argsDoc: Doc
                    if item.args.isEmpty {
                        argsDoc = .text("()")
                    } else {
                        let joined = join(separator: .text(", "), argDocs)
                        argsDoc = .concat([.text("("), .concat(joined), .text(")")])
                    }
                    return Doc.concat([.text("."), propDoc, typeArgsDoc, argsDoc])
                }

                let flatItems = [baseDoc] + chain.map { formatChainItem($0) }
                let flatDoc = Doc.concat(flatItems)

                var breakItems: [Doc] = []
                for item in chain {
                    breakItems.append(.line)
                    breakItems.append(formatChainItem(item))
                }
                let breakDoc = Doc.concat([baseDoc, .indent(.concat(breakItems))])

                innerDoc = conditionalGroup([flatDoc, breakDoc])
                break
            }
        }

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
            if shouldHugCallArguments(call.arguments) {
                let huggedArgs = join(separator: .text(", "), argDocs)
                innerDoc = Doc.concat([
                    calleeDoc,
                    typeArgsDoc,
                    .text("("),
                    .concat(huggedArgs),
                    .text(")")
                ])
            } else {
                let argsBody = join(separator: .concat([.text(","), .line]), argDocs)
                innerDoc = group(.concat([
                    calleeDoc,
                    typeArgsDoc,
                    .text("("),
                    .indent(.concat([.softline, .concat(argsBody), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
                    .softline,
                    .text(")")
                ]))
            }
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
            var parts: [Doc] = []
            var hasAnyBlankLine = false
            for i in 0..<obj.properties.count {
                let current = obj.properties[i]
                parts.append(printJSNode(current, options: options, sourceText: sourceText))
                if i < obj.properties.count - 1 {
                    let next = obj.properties[i + 1]
                    parts.append(.text(","))
                    if hasBlankLineBetween(current: current, next: next, in: sourceText) {
                        hasAnyBlankLine = true
                        parts.append(.concat([.line, .hardline]))
                    } else {
                        parts.append(.line)
                    }
                }
            }
            let lineDoc = options.bracketSpacing ? Doc.line : Doc.softline
            let trailingCommaDoc = Doc.ifBreak(breakContents: .text(","), flatContents: .empty)
            let shouldBreak = hasAnyBlankLine || (obj.properties.count > 1 && obj.sourceRange.count > 0 && {
                guard obj.sourceRange.lowerBound < sourceText.count && obj.sourceRange.upperBound <= sourceText.count else { return false }
                let startIdx = sourceText.index(sourceText.startIndex, offsetBy: obj.sourceRange.lowerBound)
                let endIdx = sourceText.index(sourceText.startIndex, offsetBy: obj.sourceRange.upperBound)
                return sourceText[startIdx..<endIdx].contains("\n")
            }())
            innerDoc = group(.concat([
                .text("{"),
                .indent(.concat([lineDoc, .concat(parts), trailingCommaDoc])),
                lineDoc,
                .text("}")
            ]), shouldBreak: shouldBreak)
        }

    case let arr as JSArrayExpression:
        if arr.elements.isEmpty {
            innerDoc = .text("[]")
        } else {
            let elemDocs = arr.elements.map { printJSNode($0, options: options, sourceText: sourceText) }
            let joined = join(separator: .concat([.text(","), .line]), elemDocs)
            let trailingCommaDoc = Doc.ifBreak(breakContents: .text(","), flatContents: .empty)
            innerDoc = group(.concat([
                .text("["),
                .indent(.concat([.softline, .concat(joined), trailingCommaDoc])),
                .softline,
                .text("]")
            ]))
        }

    case let id as JSIdentifier:
        innerDoc = .text(id.name)

    case let lit as JSLiteral:
        if lit.isString {
            if options.singleQuote {
                if lit.value.contains("'") && !lit.value.contains("\"") {
                    let escaped = lit.value.replacingOccurrences(of: "\"", with: "\\\"")
                    innerDoc = .text("\"\(escaped)\"")
                } else {
                    let escaped = lit.value.replacingOccurrences(of: "'", with: "\\'")
                    innerDoc = .text("'\(escaped)'")
                }
            } else {
                if lit.value.contains("\"") && !lit.value.contains("'") {
                    let escaped = lit.value.replacingOccurrences(of: "'", with: "\\'")
                    innerDoc = .text("'\(escaped)'")
                } else {
                    let escaped = lit.value.replacingOccurrences(of: "\"", with: "\\\"")
                    innerDoc = .text("\"\(escaped)\"")
                }
            }
        } else {
            innerDoc = .text(lit.raw)
        }

    case let tmpl as JSTemplateLiteral:
        if tmpl.expressions.isEmpty {
            innerDoc = .text("`\(tmpl.quasis.first ?? "")`")
        } else {
            var parts: [Doc] = [.text("`")]
            for (idx, expr) in tmpl.expressions.enumerated() {
                if idx < tmpl.quasis.count {
                    parts.append(.text(tmpl.quasis[idx]))
                }
                let exprDoc = printJSNode(expr, options: options, sourceText: sourceText)
                let isMultilineInSource: Bool = {
                    guard expr.sourceRange.lowerBound > 0, expr.sourceRange.lowerBound <= sourceText.count else { return false }
                    let exprStart = sourceText.index(sourceText.startIndex, offsetBy: expr.sourceRange.lowerBound)
                    var cur = exprStart
                    while cur > sourceText.startIndex {
                        cur = sourceText.index(before: cur)
                        if sourceText[cur] == "\n" {
                            return true
                        }
                        if sourceText[cur] == "{" {
                            break
                        }
                    }
                    return false
                }()

                if isMultilineInSource {
                    parts.append(.concat([
                        .text("${"),
                        .indent(.concat([.hardline, exprDoc])),
                        .hardline,
                        .text("}")
                    ]))
                } else {
                    parts.append(.concat([.text("${"), exprDoc, .text("}")]))
                }
            }
            if tmpl.quasis.count > tmpl.expressions.count {
                parts.append(.text(tmpl.quasis[tmpl.expressions.count]))
            }
            parts.append(.text("`"))
            innerDoc = .concat(parts)
        }

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
            let joinedMulti = join(separator: .concat([.text(","), .line]), specDocs)
            let lineDoc = options.bracketSpacing ? Doc.line : Doc.softline
            let bracedDoc = group(.concat([
                .text("{"),
                .indent(.concat([lineDoc, .concat(joinedMulti), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
                lineDoc,
                .text("}")
            ]))
            clauses.append(bracedDoc)
        }

        let sourceDoc = printJSNode(imp.source, options: options, sourceText: sourceText)
        let semiDoc: Doc = options.semi ? .text(";") : .empty

        if clauses.isEmpty {
            parts.append(.concat([sourceDoc, semiDoc]))
        } else {
            let clauseDoc = join(separator: .text(", "), clauses)
            parts.append(.concat([.concat(clauseDoc), .text(" from "), sourceDoc, semiDoc]))
        }
        innerDoc = group(.concat(parts))

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
            let joinedMulti = join(separator: .concat([.text(","), .line]), specDocs)
            let lineDoc = options.bracketSpacing ? Doc.line : Doc.softline
            let bracedDoc = group(.concat([
                .text("{"),
                .indent(.concat([lineDoc, .concat(joinedMulti), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
                lineDoc,
                .text("}")
            ]))
            if let source = expNamed.source {
                let sourceDoc = printJSNode(source, options: options, sourceText: sourceText)
                innerDoc = group(.concat([.text(prefix), bracedDoc, .text(" from "), sourceDoc, semiDoc]))
            } else {
                innerDoc = group(.concat([.text(prefix), bracedDoc, semiDoc]))
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
        let typeParams = ensureTrailingCommaInMultilineDelimiters(typeAlias.typeParameters ?? "", isTypeParameters: true)
        let prefix = "type \(typeAlias.id.name)\(typeParams) = "
        let formattedType = formatTypeAnnotation(typeAlias.typeAnnotation, options: options, prefix: "export " + prefix)
        innerDoc = .concat([.text(prefix), formattedType, semiDoc])

    case let interfaceDecl as JSInterfaceDeclaration:
        let typeParams = ensureTrailingCommaInMultilineDelimiters(interfaceDecl.typeParameters ?? "", isTypeParameters: true)
        let extendsPart = interfaceDecl.extendsClause != nil ? " extends \(interfaceDecl.extendsClause!)" : ""
        let formattedBody = formatTypeMembersBody(interfaceDecl.body, options: options)
        innerDoc = .concat([.text("interface \(interfaceDecl.id.name)\(typeParams)\(extendsPart) "), .text(formattedBody)])

    case let whileStmt as JSWhileStatement:
        let testDoc = printJSNode(whileStmt.test, options: options, sourceText: sourceText)
        let bodyDoc = printJSNode(whileStmt.body, options: options, sourceText: sourceText)
        innerDoc = .concat([
            group(.concat([
                .text("while ("),
                .indent(.concat([.softline, testDoc])),
                .softline,
                .text(") ")
            ])),
            bodyDoc
        ])

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
            if shouldHugCallArguments(newExpr.arguments) {
                let huggedArgs = join(separator: .text(", "), argDocs)
                let huggedDoc = Doc.concat([
                    .text("new "),
                    calleeDoc,
                    typeArgsDoc,
                    .text("("),
                    .concat(huggedArgs),
                    .text(")")
                ])
                let brokenArgs = join(separator: .concat([.text(","), .line]), argDocs)
                let brokenDoc = Doc.group(
                    contents: .concat([
                        .text("new "),
                        calleeDoc,
                        typeArgsDoc,
                        .text("("),
                        .indent(.concat([.line, .concat(brokenArgs), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
                        .line,
                        .text(")")
                    ]),
                    shouldBreak: true
                )
                innerDoc = conditionalGroup([huggedDoc, brokenDoc])
            } else {
                let argsBody = join(separator: .concat([.text(","), .line]), argDocs)
                innerDoc = group(.concat([
                    .text("new "),
                    calleeDoc,
                    typeArgsDoc,
                    .text("("),
                    .indent(.concat([.softline, .concat(argsBody), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
                    .softline,
                    .text(")")
                ]))
            }
        }


    case let awaitExpr as JSAwaitExpression:
        let argDoc = printJSNode(awaitExpr.argument, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("await "), argDoc])

    case let asExpr as JSTypeAssertionExpression:
        let exprDoc = printJSNode(asExpr.expression, options: options, sourceText: sourceText)
        var typeStr = asExpr.typeAnnotation.trimmingCharacters(in: .whitespacesAndNewlines)
        if typeStr.hasPrefix("|") {
            typeStr = typeStr.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if typeStr.contains("\n") {
            let parts = typeStr.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            let filtered = parts.map { $0.hasPrefix("|") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            let singleLine = filtered.joined(separator: " | ")
            if singleLine.count <= options.printWidth {
                typeStr = singleLine
            }
        }
        if !options.singleQuote && !typeStr.contains("\"") && typeStr.contains("'") {
            typeStr = typeStr.replacingOccurrences(of: "'", with: "\"")
        }
        if asExpr.expression is JSObjectExpression || asExpr.expression is JSTypeAssertionExpression {
            innerDoc = .concat([exprDoc, .text(" as "), .text(typeStr)])
        } else {
            innerDoc = group(.concat([exprDoc, .text(" as"), .indent(.concat([.line, .text(typeStr)]))]))
        }

    case let paren as JSParenthesizedExpression:
        if let bin = paren.expression as? JSBinaryExpression {
            innerDoc = .concat([
                .text("("),
                .indent(printBinaryExpressionFlat(bin, options: options, sourceText: sourceText)),
                .text(")")
            ])
        } else {
            let exprDoc = printJSNode(paren.expression, options: options, sourceText: sourceText)
            innerDoc = .concat([.text("("), exprDoc, .text(")")])
        }

    case let declGlobal as JSDeclareGlobalStatement:
        let bodyDoc = printJSNode(declGlobal.body, options: options, sourceText: sourceText)
        innerDoc = .concat([.text("declare global "), bodyDoc])

    case let switchStmt as JSSwitchStatement:
        let discDoc = printJSNode(switchStmt.discriminant, options: options, sourceText: sourceText)
        var caseDocs: [Doc] = []
        for switchCase in switchStmt.cases {
            let header: Doc
            if let test = switchCase.test {
                header = .concat([.text("case "), printJSNode(test, options: options, sourceText: sourceText), .text(":")])
            } else {
                header = .text("default:")
            }
            if switchCase.consequent.isEmpty {
                caseDocs.append(header)
            } else if switchCase.consequent.count == 1, let block = switchCase.consequent.first as? JSBlockStatement {
                let blockDoc = printJSNode(block, options: options, sourceText: sourceText)
                caseDocs.append(.concat([header, .text(" "), blockDoc]))
            } else {
                let stmtsDocs = printStatementSequence(switchCase.consequent, options: options, sourceText: sourceText)
                caseDocs.append(.concat([
                    header,
                    .indent(.concat([.hardline, .concat(stmtsDocs)]))
                ]))
            }
        }
        let joinedCases = join(separator: .hardline, caseDocs)
        innerDoc = .concat([
            .text("switch ("),
            discDoc,
            .text(") {"),
            caseDocs.isEmpty ? .empty : .indent(.concat([.hardline, .concat(joinedCases)])),
            .hardline,
            .text("}")
        ])

    case let brk as JSBreakStatement:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        if let label = brk.label {
            innerDoc = .concat([.text("break \(label.name)"), semiDoc])
        } else {
            innerDoc = .concat([.text("break"), semiDoc])
        }

    case let cont as JSContinueStatement:
        let semiDoc: Doc = options.semi ? .text(";") : .empty
        if let label = cont.label {
            innerDoc = .concat([.text("continue \(label.name)"), semiDoc])
        } else {
            innerDoc = .concat([.text("continue"), semiDoc])
        }

    case let cond as JSConditionalExpression:
        let testDoc = printJSNode(cond.test, options: options, sourceText: sourceText)
        let consequentDoc = printJSNode(cond.consequent, options: options, sourceText: sourceText)
        let alternateDoc = printJSNode(cond.alternate, options: options, sourceText: sourceText)
        let flatDoc = Doc.concat([
            testDoc,
            .text(" ? "),
            consequentDoc,
            .text(" : "),
            alternateDoc
        ])
        let breakDoc = Doc.concat([
            testDoc,
            .indent(.concat([
                .line,
                .text("? "),
                consequentDoc,
                .line,
                .text(": "),
                alternateDoc
            ]))
        ])
        innerDoc = conditionalGroup([flatDoc, breakDoc])

    case let regex as JSRegExpLiteral:
        innerDoc = .text(regex.raw)

    case let prop as JSProperty:
        if let keyId = prop.key as? JSIdentifier, keyId.name == "..." {
            let valDoc = printJSNode(prop.value, options: options, sourceText: sourceText)
            innerDoc = .concat([.text("..."), valDoc])
            break
        }
        let rawKeyDoc = printJSNode(prop.key, options: options, sourceText: sourceText)
        let keyDoc = prop.computed ? Doc.concat([.text("["), rawKeyDoc, .text("]")]) : rawKeyDoc

        if prop.method, let fn = prop.value as? JSFunctionDeclaration {
            let typeParamsDoc: Doc
            if let typeParams = fn.typeParameters, !typeParams.isEmpty {
                typeParamsDoc = printTypeArgumentsDoc(typeParams)
            } else {
                typeParamsDoc = .empty
            }
            let paramDocs = fn.params.map { printJSNode($0, options: options, sourceText: sourceText) }
            let joinedParams = join(separator: .text(", "), paramDocs)
            let paramsDoc = Doc.concat([.text("("), .concat(joinedParams), .text(")")])
            let returnTypeDoc = fn.returnType != nil ? Doc.text(": \(fn.returnType!)") : .empty
            let bodyDoc = fn.body != nil ? printJSNode(fn.body!, options: options, sourceText: sourceText) : .empty
            let asyncPrefix = fn.isAsync ? "async " : ""
            innerDoc = .concat([.text(asyncPrefix), keyDoc, typeParamsDoc, paramsDoc, returnTypeDoc, .text(" "), bodyDoc])
        } else if prop.shorthand {
            innerDoc = keyDoc
        } else {
            let valDoc = printJSNode(prop.value, options: options, sourceText: sourceText)
            innerDoc = .concat([keyDoc, .text(": "), valDoc])
        }

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

private func printBinaryExpressionFlat(_ bin: JSBinaryExpression, options: PrintOptions, sourceText: String) -> Doc {
    var operands: [JSNode] = []
    var curr: JSNode = bin
    while let b = curr as? JSBinaryExpression, b.operatorStr == bin.operatorStr {
        operands.insert(b.right, at: 0)
        curr = b.left
    }
    operands.insert(curr, at: 0)

    let firstNode = operands[0]
    let firstNeedParen = shouldParenthesizeBinaryOperand(firstNode, parentOp: bin.operatorStr, isRight: false)
    let firstNodeDoc = printJSNode(firstNode, options: options, sourceText: sourceText)
    let firstDoc = firstNeedParen ? .concat([.text("("), firstNodeDoc, .text(")")]) : firstNodeDoc

    var restParts: [Doc] = []
    for i in 1..<operands.count {
        let opNode = operands[i]
        let needParen = shouldParenthesizeBinaryOperand(opNode, parentOp: bin.operatorStr, isRight: true)
        let nodeDoc = printJSNode(opNode, options: options, sourceText: sourceText)
        let wrappedDoc = needParen ? .concat([.text("("), nodeDoc, .text(")")]) : nodeDoc

        let isEqualityComparison = bin.operatorStr == "===" || bin.operatorStr == "!==" || bin.operatorStr == "==" || bin.operatorStr == "!="
        let shouldInlineOperand = isEqualityComparison && (opNode is JSLiteral || (opNode as? JSIdentifier)?.name == "undefined" || (opNode as? JSIdentifier)?.name == "null")
        if shouldInlineOperand {
            restParts.append(.text(" \(bin.operatorStr) "))
            restParts.append(wrappedDoc)
        } else {
            restParts.append(.text(" \(bin.operatorStr)"))
            restParts.append(.line)
            restParts.append(wrappedDoc)
        }
    }

    return group(.concat([firstDoc] + restParts))
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
    guard currentEnd <= sourceText.count && nextStart <= sourceText.count else { return false }

    let startIdx = sourceText.index(sourceText.startIndex, offsetBy: currentEnd)
    let endIdx = sourceText.index(sourceText.startIndex, offsetBy: nextStart)

    var newlineCount = 0
    var idx = startIdx
    while idx < endIdx {
        if sourceText[idx] == "\n" {
            newlineCount += 1
            if newlineCount >= 2 {
                return true
            }
        }
        idx = sourceText.index(after: idx)
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
    guard !parts.isEmpty else {
        return .text("<>")
    }
    let typeDocs = parts.map { Doc.text($0) }
    let typeBody = join(separator: .concat([.text(","), .line]), typeDocs)
    return group(.concat([
        .text("<"),
        .indent(.concat([.softline, .concat(typeBody), .ifBreak(breakContents: .text(","), flatContents: .empty)])),
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

private func shouldHugCallArguments(_ args: [JSNode]) -> Bool {
    guard !args.isEmpty else { return false }
    if args.count == 1 {
        return isHuggableArg(args[0])
    }
    let huggableCount = args.filter { isHuggableArg($0) }.count
    if huggableCount == 1 && isHuggableArg(args.last!) {
        return true
    }
    return false
}

private func isHuggableArg(_ node: JSNode) -> Bool {
    if let arrow = node as? JSArrowFunctionExpression {
        return arrow.body is JSBlockStatement
    }
    if node is JSFunctionDeclaration {
        return true
    }
    if node is JSObjectExpression || node is JSArrayExpression {
        return true
    }
    return false
}

private func ensureTrailingCommaInMultilineDelimiters(_ text: String, isTypeParameters: Bool = false) -> String {
    guard text.contains("\n") else { return text }
    var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for i in 0..<lines.count {
        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
        var shouldAddComma = false
        if trimmed.hasPrefix(")") || trimmed.hasPrefix("):") || trimmed.hasPrefix(")=>") || trimmed.hasPrefix(") =>") {
            shouldAddComma = true
        } else if trimmed.hasPrefix(">(") || trimmed.hasPrefix("> =") || trimmed.hasPrefix(">{") || trimmed.hasPrefix("> {") {
            shouldAddComma = true
        } else if trimmed == ">" {
            var nextIdx = i + 1
            while nextIdx < lines.count && lines[nextIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                nextIdx += 1
            }
            if nextIdx < lines.count {
                let nextTrimmed = lines[nextIdx].trimmingCharacters(in: .whitespaces)
                if nextTrimmed.hasPrefix("{") || nextTrimmed.hasPrefix("=") || nextTrimmed.hasPrefix("(") {
                    shouldAddComma = true
                }
            } else if isTypeParameters {
                shouldAddComma = true
            }
        }
        if shouldAddComma {
            var prevIdx = i - 1
            while prevIdx >= 0 && lines[prevIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                prevIdx -= 1
            }
            if prevIdx >= 0 {
                let prevLine = lines[prevIdx]
                let prevTrimmed = prevLine.trimmingCharacters(in: .whitespaces)
                if !prevTrimmed.isEmpty &&
                   !prevTrimmed.hasSuffix(",") &&
                   !prevTrimmed.hasSuffix("(") &&
                   !prevTrimmed.hasSuffix("<") &&
                   !prevTrimmed.hasSuffix("{") &&
                   !prevTrimmed.hasSuffix(";") {
                    if let commentRange = prevLine.range(of: "//") {
                        let codePart = prevLine[..<commentRange.lowerBound].trimmingCharacters(in: .whitespaces)
                        let leadingSpaces = prevLine.prefix(while: { $0 == " " })
                        let commentPart = prevLine[commentRange.lowerBound...]
                        lines[prevIdx] = "\(leadingSpaces)\(codePart), \(commentPart)"
                    } else {
                        lines[prevIdx] = prevLine + ","
                    }
                }
            }
        }
    }
    return lines.joined(separator: "\n")
}

private func formatTypeMembersBody(_ raw: String, options: PrintOptions) -> String {
    let rawWithCommas = ensureTrailingCommaInMultilineDelimiters(raw)
    let trimmed = rawWithCommas.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
        return rawWithCommas
    }
    let inner = trimmed.dropFirst().dropLast()
    guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return "{}"
    }
    if !inner.contains("\n") {
        var cleaned = inner.trimmingCharacters(in: .whitespaces)
        if options.semi && !cleaned.hasSuffix(";") {
            cleaned.append(";")
        } else if !options.semi && cleaned.hasSuffix(";") {
            cleaned.removeLast()
        }
        let space = options.bracketSpacing ? " " : ""
        return "{\(space)\(cleaned)\(space)}"
    }
    var lines = inner.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
        lines.removeFirst()
    }
    while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
        lines.removeLast()
    }
    var formattedLines: [String] = []
    var parenDepth = 0
    var angleDepth = 0
    var bracketDepth = 0

    for i in 0..<lines.count {
        let str = lines[i]
        let trimmedLine = str.trimmingCharacters(in: .whitespaces)
        if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
            formattedLines.append(str)
            continue
        }

        for ch in trimmedLine {
            if ch == "(" { parenDepth += 1 }
            else if ch == ")" { parenDepth = max(0, parenDepth - 1) }
            else if ch == "<" { angleDepth += 1 }
            else if ch == ">" { angleDepth = max(0, angleDepth - 1) }
            else if ch == "[" { bracketDepth += 1 }
            else if ch == "]" { bracketDepth = max(0, bracketDepth - 1) }
        }

        var cleaned = str
        let rtrimmed = cleaned.trimmingCharacters(in: .whitespaces)

        if parenDepth > 0 || angleDepth > 0 || bracketDepth > 0 {
            formattedLines.append(cleaned)
            continue
        }

        var nextIsTernary = false
        for j in (i + 1)..<lines.count {
            let nextTrimmed = lines[j].trimmingCharacters(in: .whitespaces)
            if !nextTrimmed.isEmpty {
                if nextTrimmed.hasPrefix("?") || nextTrimmed.hasPrefix(":") {
                    nextIsTernary = true
                }
                break
            }
        }
        if nextIsTernary || rtrimmed.hasSuffix("?") || rtrimmed.hasSuffix(":") {
            formattedLines.append(cleaned)
            continue
        }

        if rtrimmed.hasSuffix(",") {
            if let lastCommaIdx = cleaned.lastIndex(of: ",") {
                cleaned.remove(at: lastCommaIdx)
            }
        }

        let currentTrimmed = cleaned.trimmingCharacters(in: .whitespaces)
        if options.semi && !currentTrimmed.hasSuffix(";") && !currentTrimmed.hasSuffix("{") {
            cleaned.append(";")
        } else if !options.semi && currentTrimmed.hasSuffix(";") {
            if let lastSemiIdx = cleaned.lastIndex(of: ";") {
                cleaned.remove(at: lastSemiIdx)
            }
        }
        formattedLines.append(cleaned)
    }
    let firstLineIndent = formattedLines.first?.prefix(while: { $0 == " " }).count ?? 2
    let closingIndent = String(repeating: " ", count: max(0, firstLineIndent - 2))
    return "{\n" + formattedLines.joined(separator: "\n") + "\n\(closingIndent)}"
}

private func formatTypeAnnotation(_ raw: String, options: PrintOptions, prefix: String = "") -> Doc {
    var text = ensureTrailingCommaInMultilineDelimiters(raw)

    if text.contains("\n") {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var newLines: [String] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("| ") {
                var unionItems = [String(trimmed.dropFirst(2))]
                var j = i + 1
                while j < lines.count {
                    let nextTrimmed = lines[j].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix("| ") {
                        unionItems.append(String(nextTrimmed.dropFirst(2)))
                        j += 1
                    } else {
                        break
                    }
                }
                let joinedUnion = unionItems.joined(separator: " | ")
                let leadingIndent = line.prefix(while: { $0 == " " })
                let combined = "\(leadingIndent)\(joinedUnion)"
                if combined.count <= options.printWidth {
                    newLines.append(combined)
                    i = j
                    continue
                }
            }
            newLines.append(line)
            i += 1
        }
        text = newLines.joined(separator: "\n")
    }

    var searchStart = text.startIndex
    while let openBrace = text[searchStart...].firstIndex(of: "{") {
        let afterOpen = text.index(after: openBrace)
        if afterOpen < text.endIndex {
            var depth = 1
            var p = afterOpen
            var closeBrace: String.Index? = nil
            while p < text.endIndex {
                if text[p] == "{" { depth += 1 }
                else if text[p] == "}" {
                    depth -= 1
                    if depth == 0 {
                        closeBrace = p
                        break
                    }
                }
                p = text.index(after: p)
            }
            if let close = closeBrace {
                let block = String(text[openBrace...close])
                if block.contains("\n") {
                    let formattedBlock = formatTypeMembersBody(block, options: options)
                    text.replaceSubrange(openBrace...close, with: formattedBlock)
                    searchStart = text.index(openBrace, offsetBy: formattedBlock.count, limitedBy: text.endIndex) ?? text.endIndex
                    continue
                }
            }
        }
        searchStart = afterOpen
    }

    if !text.contains("\n") {
        let lastPrefixLine = prefix.split(separator: "\n").last.map(String.init) ?? prefix
        if (lastPrefixLine.count + text.count + (options.semi ? 1 : 0)) > options.printWidth {
            return .concat([.indent(.concat([.line, .text(text)]))])
        }
        return .text(text)
    }

    return .text(text)
}
