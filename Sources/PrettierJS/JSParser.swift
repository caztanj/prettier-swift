import Foundation
import PrettierCore

public struct JSParser {
    public static func parse(_ source: String) throws -> (JSProgram, [Comment]) {
        var parser = JSParserImpl(source: source)
        return try parser.parse()
    }
}

private struct JSParserImpl {
    let source: String
    var comments: [Comment] = []
    var index: String.Index

    init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    mutating func parse() throws -> (JSProgram, [Comment]) {
        extractComments()
        var statements: [JSNode] = []

        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }

            let before = index
            if let stmt = try parseStatement() {
                if index == before {
                    index = source.index(after: index)
                } else {
                    statements.append(stmt)
                }
            } else {
                index = source.index(after: index)
            }
        }

        let program = JSProgram(body: statements, range: 0..<source.count)
        return (program, comments)
    }

    private mutating func extractComments() {
        enum Mode {
            case normal
            case templateLiteral
            case templateExpr(braceDepth: Int)
        }
        var modeStack: [Mode] = [.normal]
        var i = source.startIndex
        while i < source.endIndex {
            let ch = source[i]
            let currentMode = modeStack.last ?? .normal

            switch currentMode {
            case .normal:
                if ch == "\"" || ch == "'" {
                    let quote = ch
                    i = source.index(after: i)
                    while i < source.endIndex {
                        if source[i] == "\\" {
                            i = source.index(after: i)
                            if i < source.endIndex { i = source.index(after: i) }
                        } else if source[i] == quote {
                            i = source.index(after: i)
                            break
                        } else {
                            i = source.index(after: i)
                        }
                    }
                    continue
                }
                if ch == "`" {
                    modeStack.append(.templateLiteral)
                    i = source.index(after: i)
                    continue
                }
                if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "*" {
                    let startIdx = i
                    let startUtf8 = source.distance(from: source.startIndex, to: startIdx)
                    i = source.index(i, offsetBy: 2)
                    if let endRange = source[i...].range(of: "*/") {
                        let fullText = String(source[startIdx..<endRange.upperBound])
                        let endUtf8 = source.distance(from: source.startIndex, to: endRange.upperBound)
                        comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                        i = endRange.upperBound
                    } else {
                        let fullText = String(source[startIdx...])
                        let endUtf8 = source.count
                        comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                        i = source.endIndex
                    }
                    continue
                }
                if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "/" {
                    let startIdx = i
                    let startUtf8 = source.distance(from: source.startIndex, to: startIdx)
                    i = source.index(i, offsetBy: 2)
                    let endIdx = source[i...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                    let fullText = String(source[startIdx..<endIdx])
                    let endUtf8 = source.distance(from: source.startIndex, to: endIdx)
                    comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: false))
                    i = endIdx
                    continue
                }
                i = source.index(after: i)

            case .templateLiteral:
                if ch == "\\" {
                    i = source.index(after: i)
                    if i < source.endIndex { i = source.index(after: i) }
                    continue
                }
                if ch == "`" {
                    modeStack.removeLast()
                    i = source.index(after: i)
                    continue
                }
                let nextIdx = source.index(after: i)
                if ch == "$" && nextIdx < source.endIndex && source[nextIdx] == "{" {
                    modeStack.append(.templateExpr(braceDepth: 1))
                    i = source.index(after: nextIdx)
                    continue
                }
                i = source.index(after: i)

            case .templateExpr(let depth):
                if ch == "\"" || ch == "'" {
                    let quote = ch
                    i = source.index(after: i)
                    while i < source.endIndex {
                        if source[i] == "\\" {
                            i = source.index(after: i)
                            if i < source.endIndex { i = source.index(after: i) }
                        } else if source[i] == quote {
                            i = source.index(after: i)
                            break
                        } else {
                            i = source.index(after: i)
                        }
                    }
                    continue
                }
                if ch == "`" {
                    modeStack.append(.templateLiteral)
                    i = source.index(after: i)
                    continue
                }
                if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "*" {
                    let startIdx = i
                    let startUtf8 = source.distance(from: source.startIndex, to: startIdx)
                    i = source.index(i, offsetBy: 2)
                    if let endRange = source[i...].range(of: "*/") {
                        let fullText = String(source[startIdx..<endRange.upperBound])
                        let endUtf8 = source.distance(from: source.startIndex, to: endRange.upperBound)
                        comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                        i = endRange.upperBound
                    } else {
                        let fullText = String(source[startIdx...])
                        let endUtf8 = source.count
                        comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                        i = source.endIndex
                    }
                    continue
                }
                if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "/" {
                    let startIdx = i
                    let startUtf8 = source.distance(from: source.startIndex, to: startIdx)
                    i = source.index(i, offsetBy: 2)
                    let endIdx = source[i...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                    let fullText = String(source[startIdx..<endIdx])
                    let endUtf8 = source.distance(from: source.startIndex, to: endIdx)
                    comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: false))
                    i = endIdx
                    continue
                }
                if ch == "{" {
                    modeStack[modeStack.count - 1] = .templateExpr(braceDepth: depth + 1)
                    i = source.index(after: i)
                    continue
                }
                if ch == "}" {
                    if depth == 1 {
                        modeStack.removeLast()
                    } else {
                        modeStack[modeStack.count - 1] = .templateExpr(braceDepth: depth - 1)
                    }
                    i = source.index(after: i)
                    continue
                }
                i = source.index(after: i)
            }
        }
    }

    private mutating func skipWhitespaceAndComments() {
        while index < source.endIndex {
            let ch = source[index]
            if ch.isWhitespace {
                index = source.index(after: index)
                continue
            }
            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "*" {
                index = source.index(index, offsetBy: 2)
                if let endRange = source[index...].range(of: "*/") {
                    index = endRange.upperBound
                } else {
                    index = source.endIndex
                }
                continue
            }
            if ch == "/" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "/" {
                index = source.index(index, offsetBy: 2)
                let endIdx = source[index...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                index = endIdx
                continue
            }
            break
        }
    }

    private mutating func parseStatement() throws -> JSNode? {
        skipWhitespaceAndComments()
        guard index < source.endIndex else { return nil }

        let startUtf8 = source.distance(from: source.startIndex, to: index)

        if source[index] == "{" {
            return try parseBlockStatement()
        }

        if matchKeyword("const") || matchKeyword("let") || matchKeyword("var") {
            let kind = scanWord()
            var declarators: [JSVariableDeclarator] = []
            while true {
                skipWhitespaceAndComments()
                let before = index
                let idNode: JSNode
                if index < source.endIndex && source[index] == "{" {
                    let start = index
                    var depth = 0
                    while index < source.endIndex {
                        let c = source[index]
                        if c == "{" { depth += 1 }
                        else if c == "}" {
                            depth -= 1
                            if depth == 0 {
                                index = source.index(after: index)
                                break
                            }
                        }
                        index = source.index(after: index)
                    }
                    let patternText = String(source[start..<index])
                    idNode = JSIdentifier(name: formatParamString(patternText))
                } else if index < source.endIndex && source[index] == "[" {
                    let start = index
                    var depth = 0
                    while index < source.endIndex {
                        let c = source[index]
                        if c == "[" { depth += 1 }
                        else if c == "]" {
                            depth -= 1
                            if depth == 0 {
                                index = source.index(after: index)
                                break
                            }
                        }
                        index = source.index(after: index)
                    }
                    let patternText = String(source[start..<index])
                    idNode = JSIdentifier(name: formatParamString(patternText))
                } else {
                    let idStart = source.distance(from: source.startIndex, to: index)
                    let id = scanWord()
                    let idEnd = source.distance(from: source.startIndex, to: index)
                    idNode = JSIdentifier(name: id, range: idStart..<idEnd)
                }

                skipWhitespaceAndComments()
                var typeAnnotation: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    typeAnnotation = scanVariableTypeAnnotation()
                }

                skipWhitespaceAndComments()
                var initVal: JSNode? = nil
                if index < source.endIndex && source[index] == "=" {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                    initVal = try parseExpression()
                }
                let declEnd = source.distance(from: source.startIndex, to: index)
                let declStart = source.distance(from: source.startIndex, to: before)
                declarators.append(JSVariableDeclarator(id: idNode, initValue: initVal, typeAnnotation: typeAnnotation, range: declStart..<declEnd))
                let savedBeforeComma = index
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                } else {
                    index = savedBeforeComma
                    break
                }
                if index == before {
                    if index < source.endIndex { index = source.index(after: index) } else { break }
                }
            }
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSVariableDeclaration(kind: kind, declarations: declarators, range: startUtf8..<endUtf8)
        }

        var isAsync = false
        if matchKeyword("async") {
            let saved = index
            _ = scanWord()
            skipWhitespaceAndComments()
            if matchKeyword("function") {
                isAsync = true
            } else {
                index = saved
            }
        }
        if matchKeyword("function") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var name: JSIdentifier? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                name = JSIdentifier(name: scanWord())
            }
            skipWhitespaceAndComments()
            var typeParameters: String? = nil
            if index < source.endIndex && source[index] == "<" {
                typeParameters = scanTypeParameters()
            }
            skipWhitespaceAndComments()
            let params = try parseParameterList()
            skipWhitespaceAndComments()
            var returnType: String? = nil
            if index < source.endIndex && source[index] == ":" {
                returnType = scanReturnType()
            }
            var body: JSBlockStatement? = nil
            let beforeBody = index
            while index < source.endIndex && (source[index] == " " || source[index] == "\t") {
                index = source.index(after: index)
            }
            if index < source.endIndex && source[index] == "{" {
                body = try parseBlockStatement()
            } else if index < source.endIndex && source[index] == ";" {
                index = source.index(after: index)
            } else {
                let saved = index
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "{" {
                    body = try parseBlockStatement()
                } else {
                    index = beforeBody
                }
            }
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSFunctionDeclaration(id: name, typeParameters: typeParameters, params: params, body: body, isAsync: isAsync, returnType: returnType, range: startUtf8..<endUtf8)
        }

        if matchKeyword("return") {
            _ = scanWord()
            var sawNewline = false
            var p = index
            while p < source.endIndex {
                let ch = source[p]
                if ch == "\n" || ch == "\r" {
                    sawNewline = true
                    break
                }
                if ch == " " || ch == "\t" {
                    p = source.index(after: p)
                    continue
                }
                if ch == "/" && source.index(after: p) < source.endIndex && source[source.index(after: p)] == "*" {
                    let commentStart = p
                    p = source.index(p, offsetBy: 2)
                    if let endRange = source[p...].range(of: "*/") {
                        if source[commentStart..<endRange.upperBound].contains(where: { $0 == "\n" || $0 == "\r" }) {
                            sawNewline = true
                            break
                        }
                        p = endRange.upperBound
                        continue
                    } else {
                        break
                    }
                }
                if ch == "/" && source.index(after: p) < source.endIndex && source[source.index(after: p)] == "/" {
                    sawNewline = true
                    break
                }
                break
            }
            var arg: JSNode? = nil
            if !sawNewline {
                index = p
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] != ";" && source[index] != "}" {
                    arg = try parseExpression()
                }
            }
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSReturnStatement(argument: arg, range: startUtf8..<endUtf8)
        }

        if matchKeyword("if") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "(" {
                index = source.index(after: index)
            }
            let testExpr = try parseExpression()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            let consequent = try parseStatement() ?? JSBlockStatement(body: [])
            let savedIndex = index
            skipWhitespaceAndComments()
            var alternate: JSNode? = nil
            if matchKeyword("else") {
                _ = scanWord()
                skipWhitespaceAndComments()
                alternate = try parseStatement()
            } else {
                index = savedIndex
            }
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSIfStatement(test: testExpr, consequent: consequent, alternate: alternate, range: startUtf8..<endUtf8)
        }

        if matchKeyword("declare") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if matchKeyword("global") {
                _ = scanWord()
                skipWhitespaceAndComments()
                let body = try parseBlockStatement()
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                return JSDeclareGlobalStatement(body: body, range: startUtf8..<endUtf8)
            } else if let stmt = try parseStatement() {
                return stmt
            }
        }

        if matchKeyword("switch") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "(" {
                index = source.index(after: index)
            }
            let discriminant = try parseExpression()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "{" {
                index = source.index(after: index)
            }
            var cases: [JSSwitchCase] = []
            while index < source.endIndex {
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "}" {
                    index = source.index(after: index)
                    break
                }
                let caseStart = source.distance(from: source.startIndex, to: index)
                var testExpr: JSNode? = nil
                if matchKeyword("case") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                    testExpr = try parseExpression()
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == ":" {
                        index = source.index(after: index)
                    }
                } else if matchKeyword("default") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == ":" {
                        index = source.index(after: index)
                    }
                } else {
                    break
                }

                var consequent: [JSNode] = []
                while index < source.endIndex {
                    let before = index
                    skipWhitespaceAndComments()
                    if index >= source.endIndex || source[index] == "}" || matchKeyword("case") || matchKeyword("default") {
                        index = before
                        break
                    }
                    if let stmt = try parseStatement() {
                        consequent.append(stmt)
                    } else {
                        break
                    }
                }
                let caseEnd = source.distance(from: source.startIndex, to: index)
                cases.append(JSSwitchCase(test: testExpr, consequent: consequent, range: caseStart..<caseEnd))
            }
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSSwitchStatement(discriminant: discriminant, cases: cases, range: startUtf8..<endUtf8)
        }

        if matchKeyword("break") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var label: JSIdentifier? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") && source[index] != ";" {
                label = JSIdentifier(name: scanWord())
            }
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSBreakStatement(label: label, range: startUtf8..<endUtf8)
        }

        if matchKeyword("continue") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var label: JSIdentifier? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") && source[index] != ";" {
                label = JSIdentifier(name: scanWord())
            }
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSContinueStatement(label: label, range: startUtf8..<endUtf8)
        }

        if matchKeyword("import") {
            _ = scanWord()
            skipWhitespaceAndComments()

            var isTypeOnly = false
            if matchKeyword("type") {
                let saved = index
                _ = scanWord()
                skipWhitespaceAndComments()
                if index < source.endIndex && (source[index] == "{" || source[index] == "*" || (source[index].isLetter && !matchKeyword("from"))) {
                    isTypeOnly = true
                } else {
                    index = saved
                }
            }

            var defaultSpecifier: JSIdentifier? = nil
            var namespaceSpecifier: JSIdentifier? = nil
            var specifiers: [JSImportSpecifier] = []

            if index < source.endIndex && (source[index] == "\"" || source[index] == "'") {
                let sourceLit = parseStringLiteral()
                consumeSemicolon()
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                return JSImportDeclaration(specifiers: [], source: sourceLit, isTypeOnly: isTypeOnly, range: startUtf8..<endUtf8)
            }

            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                let name = scanWord()
                defaultSpecifier = JSIdentifier(name: name)
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                }
            } else if index < source.endIndex && source[index] == "*" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                if matchKeyword("as") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                }
                let name = scanWord()
                namespaceSpecifier = JSIdentifier(name: name)
                skipWhitespaceAndComments()
            }

            if index < source.endIndex && source[index] == "{" {
                index = source.index(after: index)
                while index < source.endIndex && source[index] != "}" {
                    skipWhitespaceAndComments()
                    if source[index] == "}" { break }
                    let before = index
                    var isSpecType = false
                    if matchKeyword("type") {
                        let saved = index
                        _ = scanWord()
                        skipWhitespaceAndComments()
                        if index < source.endIndex && source[index] != "," && source[index] != "}" && !matchKeyword("as") {
                            isSpecType = true
                        } else {
                            index = saved
                        }
                    }
                    let importedName = scanWord()
                    var localName = importedName
                    skipWhitespaceAndComments()
                    if matchKeyword("as") {
                        _ = scanWord()
                        skipWhitespaceAndComments()
                        localName = scanWord()
                    }
                    specifiers.append(JSImportSpecifier(
                        imported: JSIdentifier(name: importedName),
                        local: JSIdentifier(name: localName),
                        isType: isSpecType
                    ))
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "," {
                        index = source.index(after: index)
                    }
                    if index == before && index < source.endIndex {
                        index = source.index(after: index)
                    }
                }
                if index < source.endIndex && source[index] == "}" {
                    index = source.index(after: index)
                }
            }

            skipWhitespaceAndComments()
            if matchKeyword("from") {
                _ = scanWord()
            }
            skipWhitespaceAndComments()
            let sourceLit = parseStringLiteral()
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSImportDeclaration(
                defaultSpecifier: defaultSpecifier,
                namespaceSpecifier: namespaceSpecifier,
                specifiers: specifiers,
                source: sourceLit,
                isTypeOnly: isTypeOnly,
                range: startUtf8..<endUtf8
            )
        }

        if matchKeyword("export") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if matchKeyword("default") {
                _ = scanWord()
                skipWhitespaceAndComments()
                if matchKeyword("function") || matchKeyword("async") {
                    let decl = try parseStatement() ?? JSBlockStatement(body: [])
                    let endUtf8 = source.distance(from: source.startIndex, to: index)
                    return JSExportDefaultDeclaration(declaration: decl, range: startUtf8..<endUtf8)
                } else {
                    let expr = try parseExpression()
                    consumeSemicolon()
                    let endUtf8 = source.distance(from: source.startIndex, to: index)
                    return JSExportDefaultDeclaration(declaration: expr, range: startUtf8..<endUtf8)
                }
            }

            var isTypeOnly = false
            if matchKeyword("type") {
                let saved = index
                _ = scanWord()
                skipWhitespaceAndComments()
                if index < source.endIndex && (source[index] == "{" || source[index] == "*") {
                    isTypeOnly = true
                } else {
                    index = saved
                }
            }

            if index < source.endIndex && source[index] == "*" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                var exportedName: JSIdentifier? = nil
                if matchKeyword("as") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                    exportedName = JSIdentifier(name: scanWord())
                    skipWhitespaceAndComments()
                }
                if matchKeyword("from") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                }
                let sourceLit = parseStringLiteral()
                consumeSemicolon()
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                return JSExportAllDeclaration(exported: exportedName, source: sourceLit, isTypeOnly: isTypeOnly, range: startUtf8..<endUtf8)
            }

            if index < source.endIndex && source[index] == "{" {
                index = source.index(after: index)
                var specifiers: [JSExportSpecifier] = []
                while index < source.endIndex && source[index] != "}" {
                    skipWhitespaceAndComments()
                    if source[index] == "}" { break }
                    let before = index
                    var isSpecType = false
                    if matchKeyword("type") {
                        let saved = index
                        _ = scanWord()
                        skipWhitespaceAndComments()
                        if index < source.endIndex && source[index] != "," && source[index] != "}" && !matchKeyword("as") {
                            isSpecType = true
                        } else {
                            index = saved
                        }
                    }
                    let localName = scanWord()
                    var exportedName = localName
                    skipWhitespaceAndComments()
                    if matchKeyword("as") {
                        _ = scanWord()
                        skipWhitespaceAndComments()
                        exportedName = scanWord()
                    }
                    specifiers.append(JSExportSpecifier(
                        local: JSIdentifier(name: localName),
                        exported: JSIdentifier(name: exportedName),
                        isType: isSpecType
                    ))
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "," {
                        index = source.index(after: index)
                    }
                    if index == before && index < source.endIndex {
                        index = source.index(after: index)
                    }
                }
                if index < source.endIndex && source[index] == "}" {
                    index = source.index(after: index)
                }
                skipWhitespaceAndComments()
                var sourceLit: JSLiteral? = nil
                if matchKeyword("from") {
                    _ = scanWord()
                    skipWhitespaceAndComments()
                    sourceLit = parseStringLiteral()
                }
                consumeSemicolon()
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                return JSExportNamedDeclaration(
                    declaration: nil,
                    specifiers: specifiers,
                    source: sourceLit,
                    isTypeOnly: isTypeOnly,
                    range: startUtf8..<endUtf8
                )
            }

            let decl = try parseStatement()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSExportNamedDeclaration(declaration: decl, range: startUtf8..<endUtf8)
        }

        if matchKeyword("type") {
            let saved = index
            _ = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                let name = scanWord()
                skipWhitespaceAndComments()
                var typeParams: String? = nil
                if index < source.endIndex && source[index] == "<" {
                    let start = index
                    var depth = 0
                    while index < source.endIndex {
                        let c = source[index]
                        if c == "<" { depth += 1 }
                        else if c == ">" {
                            depth -= 1
                            if depth == 0 {
                                index = source.index(after: index)
                                break
                            }
                        }
                        index = source.index(after: index)
                    }
                    typeParams = String(source[start..<index])
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "=" {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                    let start = index
                    var parenDepth = 0
                    var braceDepth = 0
                    var bracketDepth = 0
                    var angleDepth = 0
                    while index < source.endIndex {
                        if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                            if source[index] == ";" {
                                break
                            }
                            if source[index] == "\n" && isAtStatementStart(from: source.index(after: index)) {
                                break
                            }
                        }
                        let c = source[index]
                        if c == "(" { parenDepth += 1 }
                        else if c == ")" { parenDepth = max(0, parenDepth - 1) }
                        else if c == "{" { braceDepth += 1 }
                        else if c == "}" { braceDepth = max(0, braceDepth - 1) }
                        else if c == "[" { bracketDepth += 1 }
                        else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
                        else if c == "<" { angleDepth += 1 }
                        else if c == ">" { angleDepth = max(0, angleDepth - 1) }
                        index = source.index(after: index)
                    }
                    let typeDef = String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                    consumeSemicolon()
                    let endUtf8 = source.distance(from: source.startIndex, to: index)
                    return JSTypeAliasDeclaration(id: JSIdentifier(name: name), typeParameters: typeParams, typeAnnotation: typeDef, range: startUtf8..<endUtf8)
                }
            }
            index = saved
        }

        if matchKeyword("interface") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let name = scanWord()
            skipWhitespaceAndComments()
            var typeParams: String? = nil
            if index < source.endIndex && source[index] == "<" {
                let start = index
                var depth = 0
                while index < source.endIndex {
                    let c = source[index]
                    if c == "<" { depth += 1 }
                    else if c == ">" {
                        depth -= 1
                        if depth == 0 {
                            index = source.index(after: index)
                            break
                        }
                    }
                    index = source.index(after: index)
                }
                typeParams = String(source[start..<index])
            }
            skipWhitespaceAndComments()
            var extendsClause: String? = nil
            if matchKeyword("extends") {
                _ = scanWord()
                skipWhitespaceAndComments()
                let start = index
                while index < source.endIndex && source[index] != "{" {
                    index = source.index(after: index)
                }
                extendsClause = String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            skipWhitespaceAndComments()
            var bodyText = "{}"
            if index < source.endIndex && source[index] == "{" {
                let start = index
                var depth = 0
                while index < source.endIndex {
                    let c = source[index]
                    if c == "{" { depth += 1 }
                    else if c == "}" {
                        depth -= 1
                        if depth == 0 {
                            index = source.index(after: index)
                            break
                        }
                    }
                    index = source.index(after: index)
                }
                bodyText = String(source[start..<index])
            }
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSInterfaceDeclaration(
                id: JSIdentifier(name: name),
                typeParameters: typeParams,
                extendsClause: extendsClause,
                body: bodyText,
                range: startUtf8..<endUtf8
            )
        }

        if matchKeyword("while") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "(" {
                index = source.index(after: index)
            }
            let testExpr = try parseExpression()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            let body = try parseStatement() ?? JSBlockStatement(body: [])
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSWhileStatement(test: testExpr, body: body, range: startUtf8..<endUtf8)
        }

        if matchKeyword("for") {
            _ = scanWord()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "(" {
                index = source.index(after: index)
            }
            let start = index
            var parenDepth = 0
            while index < source.endIndex {
                let c = source[index]
                if c == "(" { parenDepth += 1 }
                else if c == ")" {
                    if parenDepth == 0 {
                        break
                    }
                    parenDepth -= 1
                }
                index = source.index(after: index)
            }
            let header = String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            let body = try parseStatement() ?? JSBlockStatement(body: [])
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSForStatement(header: header, body: body, range: startUtf8..<endUtf8)
        }

        if matchKeyword("try") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let block = try parseBlockStatement()
            let afterBlockIndex = index
            skipWhitespaceAndComments()
            var handlerParam: String? = nil
            var handler: JSBlockStatement? = nil
            if matchKeyword("catch") {
                _ = scanWord()
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "(" {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                    let paramStart = index
                    while index < source.endIndex && source[index] != ")" {
                        index = source.index(after: index)
                    }
                    handlerParam = String(source[paramStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if index < source.endIndex && source[index] == ")" {
                        index = source.index(after: index)
                    }
                    skipWhitespaceAndComments()
                }
                handler = try parseBlockStatement()
            } else {
                index = afterBlockIndex
            }
            let afterCatchIndex = index
            skipWhitespaceAndComments()
            var finalizer: JSBlockStatement? = nil
            if matchKeyword("finally") {
                _ = scanWord()
                skipWhitespaceAndComments()
                finalizer = try parseBlockStatement()
            } else {
                index = afterCatchIndex
            }
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSTryStatement(block: block, handlerParam: handlerParam, handler: handler, finalizer: finalizer, range: startUtf8..<endUtf8)
        }

        if matchKeyword("throw") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let arg = try parseExpression()
            consumeSemicolon()
            let endUtf8 = source.distance(from: source.startIndex, to: index)
            return JSThrowStatement(argument: arg, range: startUtf8..<endUtf8)
        }

        let expr = try parseExpression()
        consumeSemicolon()
        let endUtf8 = source.distance(from: source.startIndex, to: index)
        return JSExpressionStatement(expression: expr, range: startUtf8..<endUtf8)
    }

    private mutating func parseBlockStatement() throws -> JSBlockStatement {
        let startUtf8 = source.distance(from: source.startIndex, to: index)
        if index < source.endIndex && source[index] == "{" {
            index = source.index(after: index)
        }
        var body: [JSNode] = []
        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }
            if source[index] == "}" {
                index = source.index(after: index)
                break
            }
            let before = index
            if let stmt = try parseStatement() {
                if index == before {
                    index = source.index(after: index)
                } else {
                    body.append(stmt)
                }
            } else {
                index = source.index(after: index)
            }
        }
        let endUtf8 = source.distance(from: source.startIndex, to: index)
        return JSBlockStatement(body: body, range: startUtf8..<endUtf8)
    }

    private func formatParamString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var colonIndex: String.Index? = nil
        var equalIndex: String.Index? = nil

        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        var angleDepth = 0
        var inString: Character? = nil

        var i = trimmed.startIndex
        while i < trimmed.endIndex {
            let ch = trimmed[i]
            if let quote = inString {
                if ch == "\\" {
                    i = trimmed.index(after: i)
                    if i < trimmed.endIndex { i = trimmed.index(after: i) }
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
                else if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                    if ch == ":" && colonIndex == nil && equalIndex == nil {
                        colonIndex = i
                    } else if ch == "=" && equalIndex == nil {
                        let next = trimmed.index(after: i)
                        let nextChar = next < trimmed.endIndex ? trimmed[next] : nil
                        let prevChar = i > trimmed.startIndex ? trimmed[trimmed.index(before: i)] : nil
                        if nextChar != "=" && nextChar != ">" && prevChar != "=" && prevChar != "!" && prevChar != "<" && prevChar != ">" {
                            equalIndex = i
                        }
                    }
                }
            }
            i = trimmed.index(after: i)
        }

        if let col = colonIndex {
            var paramPart = String(trimmed[..<col]).trimmingCharacters(in: .whitespaces)
            if paramPart.hasSuffix(" ?") {
                paramPart = String(paramPart.dropLast(2)) + "?"
            }
            if let eq = equalIndex, eq > col {
                let afterCol = trimmed.index(after: col)
                let typePart = String(trimmed[afterCol..<eq]).trimmingCharacters(in: .whitespaces)
                let afterEq = trimmed.index(after: eq)
                let defaultPart = String(trimmed[afterEq...]).trimmingCharacters(in: .whitespaces)
                return "\(paramPart): \(typePart) = \(defaultPart)"
            } else {
                let afterCol = trimmed.index(after: col)
                let typePart = String(trimmed[afterCol...]).trimmingCharacters(in: .whitespaces)
                var cleanType = typePart
                if cleanType.contains("\n") && cleanType.hasPrefix("{") && cleanType.hasSuffix("}") {
                    let inner = cleanType.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
                    var member = inner
                    if !member.hasSuffix(";") { member += ";" }
                    cleanType = "{\n  \(member)\n}"
                }
                return "\(paramPart): \(cleanType)"
            }
        } else if let eq = equalIndex {
            let paramPart = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            let afterEq = trimmed.index(after: eq)
            let defaultPart = String(trimmed[afterEq...]).trimmingCharacters(in: .whitespaces)
            return "\(paramPart) = \(defaultPart)"
        }

        return trimmed
    }

    private mutating func scanTypeParameters() -> String? {
        guard index < source.endIndex && source[index] == "<" else { return nil }
        let start = index
        var angleDepth = 0
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        while index < source.endIndex {
            let c = source[index]
            if c == "<" { angleDepth += 1 }
            else if c == ">" {
                angleDepth -= 1
                if angleDepth == 0 {
                    index = source.index(after: index)
                    break
                }
            }
            else if c == "(" { parenDepth += 1 }
            else if c == ")" { parenDepth = max(0, parenDepth - 1) }
            else if c == "{" { braceDepth += 1 }
            else if c == "}" { braceDepth = max(0, braceDepth - 1) }
            else if c == "[" { bracketDepth += 1 }
            else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
            index = source.index(after: index)
        }
        return String(source[start..<index])
    }

    private mutating func scanReturnType(isArrow: Bool = false) -> String {
        guard index < source.endIndex && source[index] == ":" else { return "" }
        index = source.index(after: index)
        skipWhitespaceAndComments()
        let start = index
        var angleDepth = 0
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0

        while index < source.endIndex {
            if angleDepth == 0 && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                if isArrow && source[index...].hasPrefix("=>") {
                    break
                }
                if source[index] == ";" || source[index] == "{" || (isArrow && (source[index] == "," || source[index] == ")")) {
                    break
                }
                if source[index] == "\n" && isAtStatementStart(from: source.index(after: index)) {
                    break
                }
            }
            let c = source[index]
            if c == "<" { angleDepth += 1 }
            else if c == ">" { angleDepth = max(0, angleDepth - 1) }
            else if c == "(" { parenDepth += 1 }
            else if c == ")" { parenDepth = max(0, parenDepth - 1) }
            else if c == "{" { braceDepth += 1 }
            else if c == "}" { braceDepth = max(0, braceDepth - 1) }
            else if c == "[" { bracketDepth += 1 }
            else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
            index = source.index(after: index)
        }
        return String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func scanVariableTypeAnnotation() -> String {
        guard index < source.endIndex && source[index] == ":" else { return "" }
        index = source.index(after: index)
        skipWhitespaceAndComments()
        let start = index
        var angleDepth = 0
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0

        while index < source.endIndex {
            if angleDepth == 0 && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                if source[index] == "=" || source[index] == ";" || source[index] == "," || source[index] == "}" {
                    break
                }
                if source[index] == "\n" || source[index] == "\r" {
                    var p = source.index(after: index)
                    while p < source.endIndex && (source[p] == " " || source[p] == "\t" || source[p] == "\r" || source[p] == "\n") {
                        p = source.index(after: p)
                    }
                    if p >= source.endIndex { break }
                    let nextCh = source[p]
                    if nextCh != "|" && nextCh != "&" {
                        break
                    }
                }
            }
            let c = source[index]
            if c == "<" { angleDepth += 1 }
            else if c == ">" { angleDepth = max(0, angleDepth - 1) }
            else if c == "(" { parenDepth += 1 }
            else if c == ")" { parenDepth = max(0, parenDepth - 1) }
            else if c == "{" { braceDepth += 1 }
            else if c == "}" { braceDepth = max(0, braceDepth - 1) }
            else if c == "[" { bracketDepth += 1 }
            else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
            index = source.index(after: index)
        }
        return String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private func isArrowFunctionAhead() -> Bool {
        guard index < source.endIndex && source[index] == "(" else { return false }
        var lookIndex = source.index(after: index)
        var parenDepth = 1
        var braceDepth = 0
        var bracketDepth = 0
        var inString: Character? = nil

        while lookIndex < source.endIndex && parenDepth > 0 {
            let ch = source[lookIndex]
            if let quote = inString {
                if ch == "\\" {
                    lookIndex = source.index(after: lookIndex)
                    if lookIndex < source.endIndex {
                        lookIndex = source.index(after: lookIndex)
                    }
                    continue
                } else if ch == quote {
                    inString = nil
                }
            } else {
                if ch == "\"" || ch == "'" || ch == "`" {
                    inString = ch
                } else if ch == "/" && source.index(after: lookIndex) < source.endIndex {
                    let next = source[source.index(after: lookIndex)]
                    if next == "/" {
                        lookIndex = source.index(after: lookIndex)
                        while lookIndex < source.endIndex && source[lookIndex] != "\n" {
                            lookIndex = source.index(after: lookIndex)
                        }
                        continue
                    } else if next == "*" {
                        lookIndex = source.index(after: lookIndex)
                        while lookIndex < source.endIndex {
                            if source[lookIndex] == "*" && source.index(after: lookIndex) < source.endIndex && source[source.index(after: lookIndex)] == "/" {
                                lookIndex = source.index(lookIndex, offsetBy: 2)
                                break
                            }
                            lookIndex = source.index(after: lookIndex)
                        }
                        continue
                    }
                } else if ch == "(" {
                    parenDepth += 1
                } else if ch == ")" {
                    parenDepth -= 1
                    if parenDepth == 0 {
                        lookIndex = source.index(after: lookIndex)
                        break
                    }
                } else if ch == "{" {
                    braceDepth += 1
                } else if ch == "}" {
                    braceDepth = max(0, braceDepth - 1)
                } else if ch == "[" {
                    bracketDepth += 1
                } else if ch == "]" {
                    bracketDepth = max(0, bracketDepth - 1)
                }
            }
            lookIndex = source.index(after: lookIndex)
        }

        guard parenDepth == 0 else { return false }

        while lookIndex < source.endIndex {
            let ch = source[lookIndex]
            if ch.isWhitespace {
                lookIndex = source.index(after: lookIndex)
            } else if ch == "/" && source.index(after: lookIndex) < source.endIndex {
                let next = source[source.index(after: lookIndex)]
                if next == "/" {
                    while lookIndex < source.endIndex && source[lookIndex] != "\n" {
                        lookIndex = source.index(after: lookIndex)
                    }
                } else if next == "*" {
                    lookIndex = source.index(after: lookIndex)
                    while lookIndex < source.endIndex {
                        if source[lookIndex] == "*" && source.index(after: lookIndex) < source.endIndex && source[source.index(after: lookIndex)] == "/" {
                            lookIndex = source.index(lookIndex, offsetBy: 2)
                            break
                        }
                        lookIndex = source.index(after: lookIndex)
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }

        guard lookIndex < source.endIndex else { return false }

        if source[lookIndex...].hasPrefix("=>") {
            return true
        }

        if source[lookIndex] == ":" {
            lookIndex = source.index(after: lookIndex)
            var typeAngleDepth = 0
            var typeParenDepth = 0
            var typeBraceDepth = 0
            var typeBracketDepth = 0

            while lookIndex < source.endIndex {
                if typeAngleDepth == 0 && typeParenDepth == 0 && typeBraceDepth == 0 && typeBracketDepth == 0 {
                    if source[lookIndex...].hasPrefix("=>") {
                        return true
                    }
                    if source[lookIndex] == ";" || source[lookIndex] == "{" || source[lookIndex] == "," || source[lookIndex] == ")" {
                        return false
                    }
                }
                let c = source[lookIndex]
                if c == "<" { typeAngleDepth += 1 }
                else if c == ">" { typeAngleDepth = max(0, typeAngleDepth - 1) }
                else if c == "(" { typeParenDepth += 1 }
                else if c == ")" { typeParenDepth = max(0, typeParenDepth - 1) }
                else if c == "{" { typeBraceDepth += 1 }
                else if c == "}" { typeBraceDepth = max(0, typeBraceDepth - 1) }
                else if c == "[" { typeBracketDepth += 1 }
                else if c == "]" { typeBracketDepth = max(0, typeBracketDepth - 1) }
                lookIndex = source.index(after: lookIndex)
            }
        }

        return false
    }

    private mutating func parseParameterList() throws -> [JSNode] {
        if index < source.endIndex && source[index] == "(" {
            index = source.index(after: index)
        }
        var params: [JSNode] = []
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        var angleDepth = 0
        var currentParam = ""
        var inString: Character? = nil

        while index < source.endIndex {
            let ch = source[index]

            if inString == nil && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 && ch == ")" {
                index = source.index(after: index)
                break
            }

            if let quote = inString {
                currentParam.append(ch)
                if ch == "\\" {
                    index = source.index(after: index)
                    if index < source.endIndex {
                        currentParam.append(source[index])
                    }
                } else if ch == quote {
                    inString = nil
                }
                index = source.index(after: index)
                continue
            }

            if ch == "\"" || ch == "'" || ch == "`" {
                inString = ch
                currentParam.append(ch)
                index = source.index(after: index)
                continue
            }

            if ch == "/" && source.index(after: index) < source.endIndex {
                let next = source[source.index(after: index)]
                if next == "/" {
                    while index < source.endIndex && source[index] != "\n" {
                        index = source.index(after: index)
                    }
                    continue
                } else if next == "*" {
                    index = source.index(after: index)
                    while index < source.endIndex {
                        if source[index] == "*" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "/" {
                            index = source.index(index, offsetBy: 2)
                            break
                        }
                        index = source.index(after: index)
                    }
                    continue
                }
            }

            if ch == "<" { angleDepth += 1 }
            else if ch == ">" { angleDepth = max(0, angleDepth - 1) }
            else if ch == "(" { parenDepth += 1 }
            else if ch == ")" { parenDepth = max(0, parenDepth - 1) }
            else if ch == "{" { braceDepth += 1 }
            else if ch == "}" { braceDepth = max(0, braceDepth - 1) }
            else if ch == "[" { bracketDepth += 1 }
            else if ch == "]" { bracketDepth = max(0, bracketDepth - 1) }

            if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 && ch == "," {
                let formatted = formatParamString(currentParam)
                if !formatted.isEmpty {
                    params.append(JSIdentifier(name: formatted))
                }
                currentParam = ""
                index = source.index(after: index)
                continue
            }

            if ch == "\n" {
                currentParam.append("\n")
            } else if ch.isWhitespace {
                if !currentParam.isEmpty && !currentParam.hasSuffix(" ") && !currentParam.hasSuffix("\n") {
                    currentParam.append(" ")
                }
            } else {
                currentParam.append(ch)
            }
            index = source.index(after: index)
        }

        let formatted = formatParamString(currentParam)
        if !formatted.isEmpty {
            params.append(JSIdentifier(name: formatted))
        }

        return params
    }

    private mutating func parseExpression() throws -> JSNode {
        let expr = try parseBinaryExpression(minPrecedence: 0)
        let saved = index
        skipWhitespaceAndComments()
        if index < source.endIndex && source[index] == "?" {
            index = source.index(after: index)
            skipWhitespaceAndComments()
            let consequent = try parseExpression()
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ":" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                let alternate = try parseExpression()
                let startUtf8 = expr.sourceRange.lowerBound
                let endUtf8 = max(startUtf8, alternate.sourceRange.upperBound)
                return JSConditionalExpression(test: expr, consequent: consequent, alternate: alternate, range: startUtf8..<endUtf8)
            }
        }
        index = saved
        return expr
    }

    private mutating func parseBinaryExpression(minPrecedence: Int) throws -> JSNode {
        var left = try parseUnaryOrPrimary()

        while true {
            let savedBeforeOp = index
            skipWhitespaceAndComments()
            guard index < source.endIndex else {
                index = savedBeforeOp
                break
            }

            guard let (op, prec) = peekBinaryOperator(), prec >= minPrecedence else {
                index = savedBeforeOp
                break
            }

            index = source.index(index, offsetBy: op.count)
            skipWhitespaceAndComments()
            let isAssignment = op.hasSuffix("=") && op != "==" && op != "===" && op != "!=" && op != "!==" && op != "<=" && op != ">="
            let right = try parseBinaryExpression(minPrecedence: isAssignment ? prec : prec + 1)
            let bStart = left.sourceRange.lowerBound
            let bEnd = max(bStart, right.sourceRange.upperBound)
            left = JSBinaryExpression(operatorStr: op, left: left, right: right, range: bStart..<bEnd)
        }

        return left
    }

    private func peekBinaryOperator() -> (String, Int)? {
        if matchKeyword("instanceof") {
            return ("instanceof", 9)
        }
        if matchKeyword("in") {
            return ("in", 9)
        }

        let operators: [(String, Int)] = [
            ("===", 8), ("!==", 8),
            (">>>=", 1), (">>>", 10),
            (">>=", 1), (">>", 10),
            ("<<=", 1), ("<<", 10),
            ("<=", 9), (">=", 9),
            ("==", 8), ("!=", 8),
            ("??=", 1), ("||=", 1), ("&&=", 1),
            ("**=", 1), ("**", 13),
            ("+=", 1), ("-=", 1), ("*=", 1), ("/=", 1), ("%=", 1),
            ("&=", 1), ("^=", 1), ("|=", 1),
            ("??", 2),
            ("||", 3),
            ("&&", 4),
            ("|", 5),
            ("^", 6),
            ("&", 7),
            ("<", 9), (">", 9),
            ("+", 11), ("-", 11),
            ("*", 12), ("/", 12), ("%", 12),
            ("=", 1)
        ]
        for (op, prec) in operators {
            if source[index...].hasPrefix(op) {
                if op == "=" && source[index...].hasPrefix("=>") {
                    continue
                }
                return (op, prec)
            }
        }
        return nil
    }

    private mutating func parseUnaryOrPrimary() throws -> JSNode {
        skipWhitespaceAndComments()
        guard index < source.endIndex else {
            return JSIdentifier(name: "")
        }

        if matchKeyword("await") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let argument = try parseUnaryOrPrimary()
            return JSAwaitExpression(argument: argument)
        }

        if matchKeyword("new") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let target = try parsePostfix()
            if let call = target as? JSCallExpression {
                return JSNewExpression(callee: call.callee, arguments: call.arguments, typeArguments: call.typeArguments)
            } else {
                return JSNewExpression(callee: target, arguments: [])
            }
        }

        if matchKeyword("typeof") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: "typeof ", prefix: true, argument: operand)
        }

        if matchKeyword("void") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: "void ", prefix: true, argument: operand)
        }

        if matchKeyword("delete") {
            _ = scanWord()
            skipWhitespaceAndComments()
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: "delete ", prefix: true, argument: operand)
        }

        if source[index...].hasPrefix("++") {
            index = source.index(index, offsetBy: 2)
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: "++", prefix: true, argument: operand)
        }
        if source[index...].hasPrefix("--") {
            index = source.index(index, offsetBy: 2)
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: "--", prefix: true, argument: operand)
        }

        let ch = source[index]
        if ch == "!" || ch == "~" || ch == "+" || ch == "-" {
            index = source.index(after: index)
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: String(ch), prefix: true, argument: operand)
        }

        return try parsePostfix()
    }

    private mutating func parseArgumentList() throws -> [JSNode] {
        guard index < source.endIndex && source[index] == "(" else { return [] }
        index = source.index(after: index)
        var args: [JSNode] = []
        while index < source.endIndex && source[index] != ")" {
            skipWhitespaceAndComments()
            if source[index] == ")" { break }
            let before = index
            args.append(try parseExpression())
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "," {
                index = source.index(after: index)
            }
            if index == before && index < source.endIndex {
                index = source.index(after: index)
            }
        }
        if index < source.endIndex && source[index] == ")" {
            index = source.index(after: index)
        }
        return args
    }

    private mutating func tryScanTypeArguments() -> String? {
        guard index < source.endIndex && source[index] == "<" else { return nil }

        let nextIdx = source.index(after: index)
        guard nextIdx < source.endIndex else { return nil }
        let nextCh = source[nextIdx]
        guard nextCh != "<" && nextCh != "=" else { return nil }

        var lookIndex = source.index(after: index)
        var angleDepth = 1
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        var inString: Character? = nil

        while lookIndex < source.endIndex && angleDepth > 0 {
            let ch = source[lookIndex]
            if let quote = inString {
                if ch == "\\" {
                    lookIndex = source.index(after: lookIndex)
                    if lookIndex < source.endIndex {
                        lookIndex = source.index(after: lookIndex)
                    }
                    continue
                } else if ch == quote {
                    inString = nil
                }
            } else {
                if ch == "\"" || ch == "'" || ch == "`" {
                    inString = ch
                } else if ch == "/" && source.index(after: lookIndex) < source.endIndex && source[source.index(after: lookIndex)] == "*" {
                    lookIndex = source.index(lookIndex, offsetBy: 2)
                    if let endRange = source[lookIndex...].range(of: "*/") {
                        lookIndex = endRange.upperBound
                    } else {
                        return nil
                    }
                    continue
                } else if ch == "/" && source.index(after: lookIndex) < source.endIndex && source[source.index(after: lookIndex)] == "/" {
                    lookIndex = source.index(lookIndex, offsetBy: 2)
                    let endIdx = source[lookIndex...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                    lookIndex = endIdx
                    continue
                } else if ch == "<" {
                    let n = source.index(after: lookIndex)
                    if n < source.endIndex && (source[n] == "=" || source[n] == "<") {
                        return nil
                    }
                    angleDepth += 1
                } else if ch == ">" {
                    let prev = lookIndex > index ? source[source.index(before: lookIndex)] : nil
                    let n = source.index(after: lookIndex)
                    let nextCh = n < source.endIndex ? source[n] : nil

                    if prev == "=" || nextCh == "=" {
                    } else if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                        angleDepth -= 1
                        if angleDepth == 0 {
                            lookIndex = source.index(after: lookIndex)
                            break
                        }
                    } else {
                        angleDepth = max(0, angleDepth - 1)
                    }
                } else if ch == "(" {
                    parenDepth += 1
                } else if ch == ")" {
                    parenDepth = max(0, parenDepth - 1)
                } else if ch == "{" {
                    braceDepth += 1
                } else if ch == "}" {
                    braceDepth = max(0, braceDepth - 1)
                } else if ch == "[" {
                    bracketDepth += 1
                } else if ch == "]" {
                    bracketDepth = max(0, bracketDepth - 1)
                } else if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                    if ch == ";" || ch == "!" {
                        return nil
                    }
                    let n = source.index(after: lookIndex)
                    if n < source.endIndex {
                        let nextCh = source[n]
                        if (ch == "&" && nextCh == "&") || (ch == "|" && nextCh == "|") || (ch == "=" && nextCh == "=") {
                            return nil
                        }
                    }
                }
            }
            lookIndex = source.index(after: lookIndex)
        }

        guard angleDepth == 0 else { return nil }

        var afterIdx = lookIndex
        while afterIdx < source.endIndex {
            let ch = source[afterIdx]
            if ch.isWhitespace || ch == "\n" || ch == "\r" {
                afterIdx = source.index(after: afterIdx)
                continue
            }
            if ch == "/" && source.index(after: afterIdx) < source.endIndex && source[source.index(after: afterIdx)] == "*" {
                afterIdx = source.index(afterIdx, offsetBy: 2)
                if let endRange = source[afterIdx...].range(of: "*/") {
                    afterIdx = endRange.upperBound
                } else {
                    return nil
                }
                continue
            }
            if ch == "/" && source.index(after: afterIdx) < source.endIndex && source[source.index(after: afterIdx)] == "/" {
                afterIdx = source.index(afterIdx, offsetBy: 2)
                let endIdx = source[afterIdx...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                afterIdx = endIdx
                continue
            }
            break
        }

        guard afterIdx < source.endIndex && (source[afterIdx] == "(" || source[afterIdx] == "`") else {
            return nil
        }

        let raw = String(source[index..<lookIndex])
        let formatted = formatTypeArguments(raw)
        index = lookIndex
        return formatted
    }

    private func formatTypeArguments(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<") && trimmed.hasSuffix(">") else { return trimmed }
        let inner = trimmed.dropFirst().dropLast()
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
        let lastPart = String(inner[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastPart.isEmpty { parts.append(lastPart) }
        return "<" + parts.joined(separator: ", ") + ">"
    }

    private mutating func scanTypeAnnotationForAs() -> String {
        let start = index
        var angleDepth = 0
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0

        while index < source.endIndex {
            let ch = source[index]

            if ch == "\"" || ch == "'" || ch == "`" {
                let quote = ch
                index = source.index(after: index)
                while index < source.endIndex && source[index] != quote {
                    if source[index] == "\\" && source.index(after: index) < source.endIndex {
                        index = source.index(after: index)
                    }
                    index = source.index(after: index)
                }
                if index < source.endIndex {
                    index = source.index(after: index)
                }
                continue
            }

            if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                if ch == ";" || ch == "," || ch == ")" || ch == "}" || ch == "]" || ch == "=" {
                    break
                }
                if source[index...].hasPrefix("===") || source[index...].hasPrefix("!==") ||
                   source[index...].hasPrefix("&&") || source[index...].hasPrefix("||") ||
                   source[index...].hasPrefix("??") {
                    break
                }
                if matchKeyword("as") {
                    break
                }
                if ch == "\n" || ch == "\r" {
                    var p = source.index(after: index)
                    while p < source.endIndex && (source[p] == " " || source[p] == "\t" || source[p] == "\r" || source[p] == "\n") {
                        p = source.index(after: p)
                    }
                    if p >= source.endIndex { break }
                    let nextCh = source[p]
                    if nextCh != "|" && nextCh != "&" {
                        break
                    }
                }
            }

            if ch == "<" {
                angleDepth += 1
            } else if ch == ">" {
                angleDepth = max(0, angleDepth - 1)
            } else if ch == "(" {
                parenDepth += 1
            } else if ch == ")" {
                parenDepth = max(0, parenDepth - 1)
            } else if ch == "{" {
                braceDepth += 1
            } else if ch == "}" {
                braceDepth = max(0, braceDepth - 1)
            } else if ch == "[" {
                bracketDepth += 1
            } else if ch == "]" {
                bracketDepth = max(0, bracketDepth - 1)
            }

            index = source.index(after: index)
        }

        return String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func parsePostfix() throws -> JSNode {
        var expr = try parsePrimary()

        while index < source.endIndex {
            let savedBeforePostfix = index
            skipWhitespaceAndComments()
            guard index < source.endIndex else {
                index = savedBeforePostfix
                break
            }

            if source[index...].hasPrefix("++") {
                index = source.index(index, offsetBy: 2)
                expr = JSUnaryExpression(operatorStr: "++", prefix: false, argument: expr)
            } else if source[index...].hasPrefix("--") {
                index = source.index(index, offsetBy: 2)
                expr = JSUnaryExpression(operatorStr: "--", prefix: false, argument: expr)
            } else if matchKeyword("as") {
                _ = scanWord()
                skipWhitespaceAndComments()
                let typeAnnotation = scanTypeAnnotationForAs()
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                expr = JSTypeAssertionExpression(expression: expr, typeAnnotation: typeAnnotation, range: expr.sourceRange.lowerBound..<endUtf8)
            } else if source[index] == "<" {
                if let typeArgs = tryScanTypeArguments() {
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "(" {
                        let args = try parseArgumentList()
                        let startUtf8 = expr.sourceRange.lowerBound
                        let endUtf8 = source.distance(from: source.startIndex, to: index)
                        expr = JSCallExpression(callee: expr, arguments: args, typeArguments: typeArgs, range: startUtf8..<endUtf8)
                    } else {
                        index = savedBeforePostfix
                        break
                    }
                } else {
                    index = savedBeforePostfix
                    break
                }
            } else if source[index] == "(" {
                let args = try parseArgumentList()
                let startUtf8 = expr.sourceRange.lowerBound
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                expr = JSCallExpression(callee: expr, arguments: args, range: startUtf8..<endUtf8)
            } else if source[index] == "." {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                let propStart = source.distance(from: source.startIndex, to: index)
                let propName = scanWord()
                let propEnd = source.distance(from: source.startIndex, to: index)
                expr = JSMemberExpression(object: expr, property: JSIdentifier(name: propName, range: propStart..<propEnd), computed: false, range: expr.sourceRange.lowerBound..<propEnd)
            } else if source[index] == "[" {
                index = source.index(after: index)
                let propExpr = try parseExpression()
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "]" {
                    index = source.index(after: index)
                }
                let endUtf8 = source.distance(from: source.startIndex, to: index)
                expr = JSMemberExpression(object: expr, property: propExpr, computed: true, range: expr.sourceRange.lowerBound..<endUtf8)
            } else {
                index = savedBeforePostfix
                break
            }
        }

        return expr
    }

    private mutating func parsePrimary() throws -> JSNode {
        skipWhitespaceAndComments()
        guard index < source.endIndex else {
            return JSIdentifier(name: "")
        }

        let ch = source[index]

        if ch == "\"" || ch == "'" {
            return parseStringLiteral()
        }

        if ch == "/" {
            let nextIdx = source.index(after: index)
            if nextIdx < source.endIndex && source[nextIdx] != "/" && source[nextIdx] != "*" {
                let start = index
                let startUtf8 = source.distance(from: source.startIndex, to: start)
                index = nextIdx
                var inCharClass = false
                while index < source.endIndex {
                    let c = source[index]
                    if c == "\\" {
                        index = source.index(after: index)
                        if index < source.endIndex { index = source.index(after: index) }
                        continue
                    }
                    if c == "[" { inCharClass = true }
                    else if c == "]" { inCharClass = false }
                    else if c == "/" && !inCharClass {
                        let patternEnd = index
                        let pattern = String(source[source.index(after: start)..<patternEnd])
                        index = source.index(after: index)
                        let flagsStart = index
                        while index < source.endIndex && (source[index].isLetter) {
                            index = source.index(after: index)
                        }
                        let flags = String(source[flagsStart..<index])
                        let raw = String(source[start..<index])
                        let endUtf8 = source.distance(from: source.startIndex, to: index)
                        return JSRegExpLiteral(pattern: pattern, flags: flags, raw: raw, range: startUtf8..<endUtf8)
                    }
                    index = source.index(after: index)
                }
            }
        }

        if ch == "`" {
            let tmplStart = index
            index = source.index(after: index)
            var quasis: [String] = []
            var expressions: [JSNode] = []
            var currentQuasiStart = index

            while index < source.endIndex {
                let c = source[index]
                if c == "\\" {
                    index = source.index(after: index)
                    if index < source.endIndex {
                        index = source.index(after: index)
                    }
                    continue
                }
                if c == "$" && source.index(after: index) < source.endIndex && source[source.index(after: index)] == "{" {
                    quasis.append(String(source[currentQuasiStart..<index]))
                    index = source.index(index, offsetBy: 2) // skip ${
                    skipWhitespaceAndComments()
                    let expr = try parseExpression()
                    expressions.append(expr)
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "}" {
                        index = source.index(after: index)
                    }
                    currentQuasiStart = index
                    continue
                }
                if c == "`" {
                    quasis.append(String(source[currentQuasiStart..<index]))
                    index = source.index(after: index)
                    let tmplEnd = index
                    return JSTemplateLiteral(
                        quasis: quasis,
                        expressions: expressions,
                        range: source.distance(from: source.startIndex, to: tmplStart)..<source.distance(from: source.startIndex, to: tmplEnd)
                    )
                }
                index = source.index(after: index)
            }
            quasis.append(String(source[currentQuasiStart..<index]))
            return JSTemplateLiteral(quasis: quasis, expressions: expressions)
        }

        if ch.isNumber {
            let start = index
            let startOffset = source.distance(from: source.startIndex, to: index)
            while index < source.endIndex && (source[index].isNumber || source[index] == "." || source[index] == "x" || source[index] == "b") {
                index = source.index(after: index)
            }
            let numStr = String(source[start..<index])
            let endOffset = source.distance(from: source.startIndex, to: index)
            return JSLiteral(value: numStr, raw: numStr, isString: false, range: startOffset..<endOffset)
        }

        if ch == "{" {
            let objStart = source.distance(from: source.startIndex, to: index)
            index = source.index(after: index)
            var props: [JSProperty] = []
            while index < source.endIndex && source[index] != "}" {
                skipWhitespaceAndComments()
                if source[index] == "}" { break }
                let before = index
                let propStart = source.distance(from: source.startIndex, to: index)

                if source[index...].hasPrefix("...") {
                    index = source.index(index, offsetBy: 3)
                    skipWhitespaceAndComments()
                    let spreadExpr = try parseExpression()
                    let propEnd = source.distance(from: source.startIndex, to: index)
                    props.append(JSProperty(key: JSIdentifier(name: "..."), value: spreadExpr, shorthand: true, range: propStart..<propEnd))
                } else {
                    let keyNode: JSNode
                    var isComputed = false
                    if source[index] == "\"" || source[index] == "'" {
                        keyNode = parseStringLiteral()
                    } else if source[index] == "[" {
                        isComputed = true
                        index = source.index(after: index)
                        skipWhitespaceAndComments()
                        let computed = try parseExpression()
                        skipWhitespaceAndComments()
                        if index < source.endIndex && source[index] == "]" {
                            index = source.index(after: index)
                        }
                        keyNode = computed
                    } else if source[index].isNumber {
                        let keyStart = source.distance(from: source.startIndex, to: index)
                        let start = index
                        while index < source.endIndex && (source[index].isNumber || source[index] == ".") {
                            index = source.index(after: index)
                        }
                        let numStr = String(source[start..<index])
                        let keyEnd = source.distance(from: source.startIndex, to: index)
                        keyNode = JSLiteral(value: numStr, raw: numStr, isString: false, range: keyStart..<keyEnd)
                    } else {
                        let keyStart = source.distance(from: source.startIndex, to: index)
                        let keyName = scanWord()
                        let keyEnd = source.distance(from: source.startIndex, to: index)
                        keyNode = JSIdentifier(name: keyName, range: keyStart..<keyEnd)
                    }

                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == ":" {
                        index = source.index(after: index)
                        skipWhitespaceAndComments()
                        let valNode = try parseExpression()
                        let propEnd = source.distance(from: source.startIndex, to: index)
                        props.append(JSProperty(key: keyNode, value: valNode, shorthand: false, method: false, computed: isComputed, range: propStart..<propEnd))
                    } else if index < source.endIndex && (source[index] == "(" || source[index] == "<") {
                        var typeParameters: String? = nil
                        if source[index] == "<" {
                            typeParameters = scanTypeParameters()
                            skipWhitespaceAndComments()
                        }
                        let params = try parseParameterList()
                        skipWhitespaceAndComments()
                        var returnType: String? = nil
                        if index < source.endIndex && source[index] == ":" {
                            returnType = scanReturnType()
                            skipWhitespaceAndComments()
                        }
                        let body = try parseBlockStatement()
                        let funcNode = JSFunctionDeclaration(id: nil, typeParameters: typeParameters, params: params, body: body, isAsync: false, returnType: returnType, range: propStart..<source.distance(from: source.startIndex, to: index))
                        let propEnd = source.distance(from: source.startIndex, to: index)
                        props.append(JSProperty(key: keyNode, value: funcNode, shorthand: false, method: true, computed: isComputed, range: propStart..<propEnd))
                    } else {
                        let propEnd = source.distance(from: source.startIndex, to: index)
                        props.append(JSProperty(key: keyNode, value: keyNode, shorthand: true, method: false, computed: isComputed, range: propStart..<propEnd))
                    }
                }

                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                }

                if index == before && index < source.endIndex {
                    index = source.index(after: index)
                }
            }
            if index < source.endIndex && source[index] == "}" {
                index = source.index(after: index)
            }
            let objEnd = source.distance(from: source.startIndex, to: index)
            return JSObjectExpression(properties: props, range: objStart..<objEnd)
        }

        if ch == "[" {
            let arrStart = source.distance(from: source.startIndex, to: index)
            index = source.index(after: index)
            var elements: [JSNode] = []
            while index < source.endIndex && source[index] != "]" {
                skipWhitespaceAndComments()
                if source[index] == "]" { break }
                let before = index
                elements.append(try parseExpression())
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                }
                if index == before && index < source.endIndex {
                    index = source.index(after: index)
                }
            }
            if index < source.endIndex && source[index] == "]" {
                index = source.index(after: index)
            }
            let arrEnd = source.distance(from: source.startIndex, to: index)
            return JSArrayExpression(elements: elements, range: arrStart..<arrEnd)
        }

        if matchKeyword("function") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var name: JSIdentifier? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                name = JSIdentifier(name: scanWord())
            }
            skipWhitespaceAndComments()
            var typeParameters: String? = nil
            if index < source.endIndex && source[index] == "<" {
                typeParameters = scanTypeParameters()
            }
            skipWhitespaceAndComments()
            let params = try parseParameterList()
            skipWhitespaceAndComments()
            var returnType: String? = nil
            if index < source.endIndex && source[index] == ":" {
                returnType = scanReturnType()
            }
            skipWhitespaceAndComments()
            var body: JSBlockStatement? = nil
            if index < source.endIndex && source[index] == "{" {
                body = try parseBlockStatement()
            }
            return JSFunctionDeclaration(id: name, typeParameters: typeParameters, params: params, body: body, isAsync: false, returnType: returnType)
        }

        if matchKeyword("async") {
            let saved = index
            _ = scanWord()
            skipWhitespaceAndComments()
            if matchKeyword("function") {
                _ = scanWord()
                skipWhitespaceAndComments()
                var name: JSIdentifier? = nil
                if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                    name = JSIdentifier(name: scanWord())
                }
                skipWhitespaceAndComments()
                var typeParameters: String? = nil
                if index < source.endIndex && source[index] == "<" {
                    typeParameters = scanTypeParameters()
                }
                skipWhitespaceAndComments()
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType()
                }
                skipWhitespaceAndComments()
                var body: JSBlockStatement? = nil
                if index < source.endIndex && source[index] == "{" {
                    body = try parseBlockStatement()
                }
                return JSFunctionDeclaration(id: name, typeParameters: typeParameters, params: params, body: body, isAsync: true, returnType: returnType)
            } else if index < source.endIndex && source[index] == "(" && isArrowFunctionAhead() {
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType(isArrow: true)
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return makeArrowFunction(params: params, body: body, isAsync: true, returnType: returnType)
                }
            } else if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                let savedBeforeWord = index
                let paramWord = scanWord()
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return makeArrowFunction(params: [JSIdentifier(name: paramWord)], body: body, isAsync: true)
                }
                index = savedBeforeWord
                return JSIdentifier(name: "async")
            } else {
                index = saved
                return JSIdentifier(name: scanWord())
            }
        }

        if ch == "<" {
            let saved = index
            if let typeParams = scanTypeParameters() {
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "(" && isArrowFunctionAhead() {
                    let params = try parseParameterList()
                    skipWhitespaceAndComments()
                    var returnType: String? = nil
                    if index < source.endIndex && source[index] == ":" {
                        returnType = scanReturnType(isArrow: true)
                    }
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index...].hasPrefix("=>") {
                        index = source.index(index, offsetBy: 2)
                        skipWhitespaceAndComments()
                        let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                        return makeArrowFunction(typeParameters: typeParams, params: params, body: body, isAsync: false, returnType: returnType)
                    }
                }
            }
            index = saved
        }

        if ch == "(" {
            if isArrowFunctionAhead() {
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType(isArrow: true)
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return makeArrowFunction(params: params, body: body, isAsync: false, returnType: returnType)
                }
                return makeArrowFunction(params: params, body: JSBlockStatement(body: []))
            }

            let parenStart = source.distance(from: source.startIndex, to: index)
            index = source.index(after: index)
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
                return JSIdentifier(name: "")
            }

            var exprs: [JSNode] = []
            while index < source.endIndex && source[index] != ")" {
                skipWhitespaceAndComments()
                if source[index] == ")" { break }
                let before = index
                exprs.append(try parseExpression())
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                }
                if index == before && index < source.endIndex {
                    index = source.index(after: index)
                }
            }
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            guard let first = exprs.first else { return JSIdentifier(name: "") }
            let parenEnd = source.distance(from: source.startIndex, to: index)
            return JSParenthesizedExpression(expression: first, range: parenStart..<parenEnd)
        }

        let wordStart = source.distance(from: source.startIndex, to: index)
        let word = scanWord()
        let wordEnd = source.distance(from: source.startIndex, to: index)
        if word.isEmpty && index < source.endIndex {
            let fallbackStart = wordStart
            let fallbackChar = String(source[index])
            index = source.index(after: index)
            let fallbackEnd = source.distance(from: source.startIndex, to: index)
            return JSIdentifier(name: fallbackChar, range: fallbackStart..<fallbackEnd)
        }
        let savedAfterWord = index
        skipWhitespaceAndComments()
        if index < source.endIndex && source[index...].hasPrefix("=>") {
            index = source.index(index, offsetBy: 2)
            skipWhitespaceAndComments()
            let body = (source[index] == "{") ? try parseBlockStatement() : try parseExpression()
            return makeArrowFunction(params: [JSIdentifier(name: word, range: wordStart..<wordEnd)], body: body)
        }
        index = savedAfterWord

        return JSIdentifier(name: word, range: wordStart..<wordEnd)
    }

    private func makeArrowFunction(typeParameters: String? = nil, params: [JSNode], body: JSNode, isAsync: Bool = false, returnType: String? = nil) -> JSArrowFunctionExpression {
        if let innerArrow = body as? JSArrowFunctionExpression {
            innerArrow.isCurried = true
        }
        return JSArrowFunctionExpression(typeParameters: typeParameters, params: params, body: body, isAsync: isAsync, returnType: returnType)
    }

    private mutating func parseStringLiteral() -> JSLiteral {
        let quoteStart = index
        let quote = source[index]
        index = source.index(after: index)
        let start = index
        while index < source.endIndex && source[index] != quote {
            if source[index] == "\\" {
                index = source.index(after: index)
                if index < source.endIndex { index = source.index(after: index) }
            } else {
                index = source.index(after: index)
            }
        }
        let val = String(source[start..<index])
        if index < source.endIndex && source[index] == quote {
            index = source.index(after: index)
        }
        let startOffset = source.distance(from: source.startIndex, to: quoteStart)
        let endOffset = source.distance(from: source.startIndex, to: index)
        return JSLiteral(value: val, raw: "\(quote)\(val)\(quote)", isString: true, range: startOffset..<endOffset)
    }

    private mutating func scanWord() -> String {
        let start = index
        while index < source.endIndex {
            let ch = source[index]
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "$" {
                index = source.index(after: index)
            } else {
                break
            }
        }
        return String(source[start..<index])
    }

    private func matchKeyword(_ kw: String) -> Bool {
        guard source[index...].hasPrefix(kw) else { return false }
        let after = source.index(index, offsetBy: kw.count)
        if after == source.endIndex { return true }
        let nextCh = source[after]
        return !nextCh.isLetter && !nextCh.isNumber && nextCh != "_" && nextCh != "$"
    }

    private func isAtStatementStart(from idx: String.Index) -> Bool {
        var p = idx
        while p < source.endIndex && (source[p] == " " || source[p] == "\t" || source[p] == "\r" || source[p] == "\n") {
            p = source.index(after: p)
        }
        guard p < source.endIndex else { return true }
        if source[p...].hasPrefix("//") || source[p...].hasPrefix("/*") {
            return true
        }
        let keywords = [
            "export", "import", "function", "type", "interface", "const", "let", "var",
            "class", "default", "return", "if", "while", "for", "switch", "throw",
            "declare", "try", "break", "continue", "do", "case", "async"
        ]
        for kw in keywords {
            if source[p...].hasPrefix(kw) {
                let after = source.index(p, offsetBy: kw.count)
                if after >= source.endIndex || (!source[after].isLetter && !source[after].isNumber && source[after] != "_" && source[after] != "$") {
                    return true
                }
            }
        }
        return false
    }

    private mutating func consumeSemicolon() {
        while index < source.endIndex && (source[index] == " " || source[index] == "\t") {
            index = source.index(after: index)
        }
        if index < source.endIndex && source[index] == ";" {
            index = source.index(after: index)
        }
    }
}
