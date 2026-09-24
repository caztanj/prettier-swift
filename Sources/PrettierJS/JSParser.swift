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

        let program = JSProgram(body: statements, range: 0..<source.utf8.count)
        return (program, comments)
    }

    private mutating func extractComments() {
        var i = source.startIndex
        while i < source.endIndex {
            let ch = source[i]

            if ch == "\"" || ch == "'" || ch == "`" {
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

            if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "*" {
                let startIdx = i
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
                i = source.index(i, offsetBy: 2)
                if let endRange = source[i...].range(of: "*/") {
                    let fullText = String(source[startIdx..<endRange.upperBound])
                    let endUtf8 = source.utf8.distance(from: source.startIndex, to: endRange.upperBound)
                    comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                    i = endRange.upperBound
                } else {
                    let fullText = String(source[startIdx...])
                    let endUtf8 = source.utf8.count
                    comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: true))
                    i = source.endIndex
                }
                continue
            }

            if ch == "/" && source.index(after: i) < source.endIndex && source[source.index(after: i)] == "/" {
                let startIdx = i
                let startUtf8 = source.utf8.distance(from: source.startIndex, to: startIdx)
                i = source.index(i, offsetBy: 2)
                let endIdx = source[i...].firstIndex(where: { $0 == "\n" || $0 == "\r" }) ?? source.endIndex
                let fullText = String(source[startIdx..<endIdx])
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: endIdx)
                comments.append(Comment(text: fullText, range: startUtf8..<endUtf8, isBlock: false))
                i = endIdx
                continue
            }

            i = source.index(after: i)
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

        let startUtf8 = source.utf8.distance(from: source.startIndex, to: index)

        if source[index] == "{" {
            return try parseBlockStatement()
        }

        if matchKeyword("const") || matchKeyword("let") || matchKeyword("var") {
            let kind = scanWord()
            var declarators: [JSVariableDeclarator] = []
            while true {
                skipWhitespaceAndComments()
                let before = index
                let id = scanWord()
                let idNode = JSIdentifier(name: id)
                skipWhitespaceAndComments()
                var initVal: JSNode? = nil
                if index < source.endIndex && source[index] == "=" {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                    initVal = try parseExpression()
                }
                declarators.append(JSVariableDeclarator(id: idNode, initValue: initVal))
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                } else {
                    break
                }
                if index == before {
                    if index < source.endIndex { index = source.index(after: index) } else { break }
                }
            }
            consumeSemicolon()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
            if index < source.endIndex && source[index] == "<" {
                var depth = 0
                while index < source.endIndex {
                    let ch = source[index]
                    if ch == "<" { depth += 1 }
                    else if ch == ">" { depth -= 1; if depth == 0 { index = source.index(after: index); break } }
                    index = source.index(after: index)
                }
            }
            skipWhitespaceAndComments()
            let params = try parseParameterList()
            skipWhitespaceAndComments()
            var returnType: String? = nil
            if index < source.endIndex && source[index] == ":" {
                returnType = scanReturnType()
            }
            skipWhitespaceAndComments()
            var body = JSBlockStatement(body: [])
            if index < source.endIndex && source[index] == "{" {
                body = try parseBlockStatement()
            } else if index < source.endIndex && source[index] == ";" {
                index = source.index(after: index)
            }
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return JSFunctionDeclaration(id: name, params: params, body: body, isAsync: isAsync, returnType: returnType, range: startUtf8..<endUtf8)
        }

        if matchKeyword("return") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var arg: JSNode? = nil
            if index < source.endIndex && source[index] != ";" && source[index] != "}" {
                arg = try parseExpression()
            }
            consumeSemicolon()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
            skipWhitespaceAndComments()
            var alternate: JSNode? = nil
            if matchKeyword("else") {
                _ = scanWord()
                skipWhitespaceAndComments()
                alternate = try parseStatement()
            }
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return JSIfStatement(test: testExpr, consequent: consequent, alternate: alternate, range: startUtf8..<endUtf8)
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
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
                let expr = try parseExpression()
                consumeSemicolon()
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                return JSExportDefaultDeclaration(declaration: expr, range: startUtf8..<endUtf8)
            } else {
                let decl = try parseStatement()
                let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
                return JSExportNamedDeclaration(declaration: decl, range: startUtf8..<endUtf8)
            }
        }

        let expr = try parseExpression()
        consumeSemicolon()
        let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
        return JSExpressionStatement(expression: expr, range: startUtf8..<endUtf8)
    }

    private mutating func parseBlockStatement() throws -> JSBlockStatement {
        let startUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
        let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
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
                return "\(paramPart): \(typePart)"
            }
        } else if let eq = equalIndex {
            let paramPart = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            let afterEq = trimmed.index(after: eq)
            let defaultPart = String(trimmed[afterEq...]).trimmingCharacters(in: .whitespaces)
            return "\(paramPart) = \(defaultPart)"
        }

        return trimmed
    }

    private mutating func scanReturnType() -> String {
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
                if source[index...].hasPrefix("=>") {
                    break
                }
                if source[index] == ";" || source[index] == "{" || source[index] == "," || source[index] == ")" {
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
        var currentParam = ""
        var inString: Character? = nil

        while index < source.endIndex {
            let ch = source[index]

            if inString == nil && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && ch == ")" {
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

            if ch == "(" { parenDepth += 1 }
            else if ch == ")" { parenDepth = max(0, parenDepth - 1) }
            else if ch == "{" { braceDepth += 1 }
            else if ch == "}" { braceDepth = max(0, braceDepth - 1) }
            else if ch == "[" { bracketDepth += 1 }
            else if ch == "]" { bracketDepth = max(0, bracketDepth - 1) }

            if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && ch == "," {
                let formatted = formatParamString(currentParam)
                if !formatted.isEmpty {
                    params.append(JSIdentifier(name: formatted))
                }
                currentParam = ""
                index = source.index(after: index)
                continue
            }

            if ch.isWhitespace {
                if !currentParam.isEmpty && !currentParam.hasSuffix(" ") {
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
        return try parseBinaryExpression(minPrecedence: 0)
    }

    private mutating func parseBinaryExpression(minPrecedence: Int) throws -> JSNode {
        var left = try parseUnaryOrPrimary()

        while true {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }

            guard let (op, prec) = peekBinaryOperator(), prec >= minPrecedence else {
                break
            }

            index = source.index(index, offsetBy: op.count)
            skipWhitespaceAndComments()
            let right = try parseBinaryExpression(minPrecedence: prec + 1)
            left = JSBinaryExpression(operatorStr: op, left: left, right: right)
        }

        return left
    }

    private func peekBinaryOperator() -> (String, Int)? {
        let operators: [(String, Int)] = [
            ("??", 1),
            ("||", 2),
            ("&&", 3),
            ("===", 6), ("!==", 6), ("==", 6), ("!=", 6),
            ("<=", 7), (">=", 7), ("<", 7), (">", 7),
            ("+", 9), ("-", 9),
            ("*", 10), ("/", 10), ("%", 10),
            ("=", 0)
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

        let ch = source[index]
        if ch == "!" || ch == "~" || ch == "+" || ch == "-" {
            index = source.index(after: index)
            let operand = try parseUnaryOrPrimary()
            return JSUnaryExpression(operatorStr: String(ch), prefix: true, argument: operand)
        }

        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> JSNode {
        var expr = try parsePrimary()

        while index < source.endIndex {
            skipWhitespaceAndComments()
            guard index < source.endIndex else { break }

            if source[index] == "(" {
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
                expr = JSCallExpression(callee: expr, arguments: args)
            } else if source[index] == "." {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                let propName = scanWord()
                expr = JSMemberExpression(object: expr, property: JSIdentifier(name: propName), computed: false)
            } else if source[index] == "[" {
                index = source.index(after: index)
                let propExpr = try parseExpression()
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "]" {
                    index = source.index(after: index)
                }
                expr = JSMemberExpression(object: expr, property: propExpr, computed: true)
            } else {
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

        if ch == "`" {
            index = source.index(after: index)
            let start = index
            while index < source.endIndex && source[index] != "`" {
                index = source.index(after: index)
            }
            let content = String(source[start..<index])
            if index < source.endIndex && source[index] == "`" {
                index = source.index(after: index)
            }
            return JSTemplateLiteral(quasis: [content], expressions: [])
        }

        if ch.isNumber {
            let start = index
            while index < source.endIndex && (source[index].isNumber || source[index] == "." || source[index] == "x" || source[index] == "b") {
                index = source.index(after: index)
            }
            let numStr = String(source[start..<index])
            return JSLiteral(value: numStr, raw: numStr, isString: false)
        }

        if ch == "{" {
            index = source.index(after: index)
            var props: [JSProperty] = []
            while index < source.endIndex && source[index] != "}" {
                skipWhitespaceAndComments()
                if source[index] == "}" { break }
                let before = index

                if source[index...].hasPrefix("...") {
                    index = source.index(index, offsetBy: 3)
                    skipWhitespaceAndComments()
                    let spreadExpr = try parseExpression()
                    props.append(JSProperty(key: JSIdentifier(name: "..."), value: spreadExpr, shorthand: true))
                } else {
                    let keyNode: JSNode
                    if source[index] == "\"" || source[index] == "'" {
                        keyNode = parseStringLiteral()
                    } else if source[index] == "[" {
                        index = source.index(after: index)
                        skipWhitespaceAndComments()
                        let computed = try parseExpression()
                        skipWhitespaceAndComments()
                        if index < source.endIndex && source[index] == "]" {
                            index = source.index(after: index)
                        }
                        keyNode = computed
                    } else if source[index].isNumber {
                        let start = index
                        while index < source.endIndex && (source[index].isNumber || source[index] == ".") {
                            index = source.index(after: index)
                        }
                        let numStr = String(source[start..<index])
                        keyNode = JSLiteral(value: numStr, raw: numStr, isString: false)
                    } else {
                        let keyName = scanWord()
                        keyNode = JSIdentifier(name: keyName)
                    }

                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == ":" {
                        index = source.index(after: index)
                        skipWhitespaceAndComments()
                        let valNode = try parseExpression()
                        props.append(JSProperty(key: keyNode, value: valNode, shorthand: false))
                    } else {
                        props.append(JSProperty(key: keyNode, value: keyNode, shorthand: true))
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
            return JSObjectExpression(properties: props)
        }

        if ch == "[" {
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
            return JSArrayExpression(elements: elements)
        }

        if matchKeyword("function") {
            _ = scanWord()
            skipWhitespaceAndComments()
            var name: JSIdentifier? = nil
            if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                name = JSIdentifier(name: scanWord())
            }
            skipWhitespaceAndComments()
            let params = try parseParameterList()
            skipWhitespaceAndComments()
            var returnType: String? = nil
            if index < source.endIndex && source[index] == ":" {
                returnType = scanReturnType()
            }
            skipWhitespaceAndComments()
            var body = JSBlockStatement(body: [])
            if index < source.endIndex && source[index] == "{" {
                body = try parseBlockStatement()
            }
            return JSFunctionDeclaration(id: name, params: params, body: body, isAsync: false, returnType: returnType)
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
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType()
                }
                skipWhitespaceAndComments()
                var body = JSBlockStatement(body: [])
                if index < source.endIndex && source[index] == "{" {
                    body = try parseBlockStatement()
                }
                return JSFunctionDeclaration(id: name, params: params, body: body, isAsync: true, returnType: returnType)
            } else if index < source.endIndex && source[index] == "(" && isArrowFunctionAhead() {
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType()
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return JSArrowFunctionExpression(params: params, body: body, isAsync: true, returnType: returnType)
                }
            } else if index < source.endIndex && (source[index].isLetter || source[index] == "_" || source[index] == "$") {
                let savedBeforeWord = index
                let paramWord = scanWord()
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return JSArrowFunctionExpression(params: [JSIdentifier(name: paramWord)], body: body, isAsync: true)
                }
                index = savedBeforeWord
                return JSIdentifier(name: "async")
            } else {
                index = saved
                return JSIdentifier(name: scanWord())
            }
        }

        if ch == "(" {
            if isArrowFunctionAhead() {
                let params = try parseParameterList()
                skipWhitespaceAndComments()
                var returnType: String? = nil
                if index < source.endIndex && source[index] == ":" {
                    returnType = scanReturnType()
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return JSArrowFunctionExpression(params: params, body: body, isAsync: false, returnType: returnType)
                }
                return JSArrowFunctionExpression(params: params, body: JSBlockStatement(body: []))
            }

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
            return exprs.first ?? JSIdentifier(name: "")
        }

        let word = scanWord()
        if word.isEmpty && index < source.endIndex {
            let fallbackChar = String(source[index])
            index = source.index(after: index)
            return JSIdentifier(name: fallbackChar)
        }
        skipWhitespaceAndComments()
        if index < source.endIndex && source[index...].hasPrefix("=>") {
            index = source.index(index, offsetBy: 2)
            skipWhitespaceAndComments()
            let body = (source[index] == "{") ? try parseBlockStatement() : try parseExpression()
            return JSArrowFunctionExpression(params: [JSIdentifier(name: word)], body: body)
        }

        return JSIdentifier(name: word)
    }

    private mutating func parseStringLiteral() -> JSLiteral {
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
        return JSLiteral(value: val, raw: "\(quote)\(val)\(quote)", isString: true)
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

    private mutating func consumeSemicolon() {
        skipWhitespaceAndComments()
        if index < source.endIndex && source[index] == ";" {
            index = source.index(after: index)
        }
    }
}
