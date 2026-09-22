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
            let params = try parseParameterList()
            skipWhitespaceAndComments()
            let body = try parseBlockStatement()
            let endUtf8 = source.utf8.distance(from: source.startIndex, to: index)
            return JSFunctionDeclaration(id: name, params: params, body: body, isAsync: isAsync, range: startUtf8..<endUtf8)
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
            var specifiers: [JSImportSpecifier] = []
            if index < source.endIndex && source[index] == "{" {
                index = source.index(after: index)
                while index < source.endIndex && source[index] != "}" {
                    skipWhitespaceAndComments()
                    if source[index] == "}" { break }
                    let name = scanWord()
                    let id = JSIdentifier(name: name)
                    specifiers.append(JSImportSpecifier(imported: id, local: id))
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "," {
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
            return JSImportDeclaration(specifiers: specifiers, source: sourceLit, range: startUtf8..<endUtf8)
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

    private mutating func parseParameterList() throws -> [JSNode] {
        if index < source.endIndex && source[index] == "(" {
            index = source.index(after: index)
        }
        var params: [JSNode] = []
        while index < source.endIndex && source[index] != ")" {
            skipWhitespaceAndComments()
            if source[index] == ")" { break }
            let name = scanWord()
            params.append(JSIdentifier(name: name))
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == "," {
                index = source.index(after: index)
            }
        }
        if index < source.endIndex && source[index] == ")" {
            index = source.index(after: index)
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
        if ch == "!" || ch == "-" || ch == "+" || ch == "~" {
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
                    args.append(try parseExpression())
                    skipWhitespaceAndComments()
                    if index < source.endIndex && source[index] == "," {
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
                let keyName = scanWord()
                let keyNode = JSIdentifier(name: keyName)
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == ":" {
                    index = source.index(after: index)
                    skipWhitespaceAndComments()
                    let valNode = try parseExpression()
                    props.append(JSProperty(key: keyNode, value: valNode, shorthand: false))
                } else {
                    props.append(JSProperty(key: keyNode, value: keyNode, shorthand: true))
                }
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
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
                elements.append(try parseExpression())
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                }
            }
            if index < source.endIndex && source[index] == "]" {
                index = source.index(after: index)
            }
            return JSArrayExpression(elements: elements)
        }

        if ch == "(" {
            index = source.index(after: index)
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index...].hasPrefix("=>") {
                    index = source.index(index, offsetBy: 2)
                    skipWhitespaceAndComments()
                    let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                    return JSArrowFunctionExpression(params: [], body: body)
                }
                return JSIdentifier(name: "")
            }

            var exprs: [JSNode] = []
            while index < source.endIndex && source[index] != ")" {
                skipWhitespaceAndComments()
                if source[index] == ")" { break }
                exprs.append(try parseExpression())
                skipWhitespaceAndComments()
                if index < source.endIndex && source[index] == "," {
                    index = source.index(after: index)
                }
            }
            if index < source.endIndex && source[index] == ")" {
                index = source.index(after: index)
            }
            skipWhitespaceAndComments()
            if index < source.endIndex && source[index...].hasPrefix("=>") {
                index = source.index(index, offsetBy: 2)
                skipWhitespaceAndComments()
                let body = (index < source.endIndex && source[index] == "{") ? try parseBlockStatement() : try parseExpression()
                return JSArrowFunctionExpression(params: exprs, body: body)
            }
            return exprs.first ?? JSIdentifier(name: "")
        }

        let word = scanWord()
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
