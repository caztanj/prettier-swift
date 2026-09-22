import PrettierCore

public enum JSONParserError: Error, Equatable {
    case unexpectedCharacter(Character, at: Int)
    case unexpectedEOF
    case invalidEscapeSequence(at: Int)
    case custom(String)
}

public final class JSONParser {
    private let source: String
    private let chars: [Character]
    private var index: Int = 0
    private var comments: [Comment] = []

    public init(_ source: String) {
        self.source = source
        self.chars = Array(source)
    }

    public static func parse(_ source: String) throws -> (root: JSONRoot, comments: [Comment]) {
        let parser = JSONParser(source)
        let root = try parser.parseRoot()
        return (root, parser.comments)
    }

    private func parseRoot() throws -> JSONRoot {
        skipWhitespaceAndComments()
        let start = index
        let value = try parseValue()
        skipWhitespaceAndComments()
        let end = index
        return JSONRoot(value: value, range: start..<end)
    }

    private func parseValue() throws -> JSONNode {
        skipWhitespaceAndComments()
        guard let ch = peek() else {
            throw JSONParserError.unexpectedEOF
        }

        switch ch {
        case "{":
            return try parseObject()
        case "[":
            return try parseArray()
        case "\"", "'":
            return try parseString()
        case "t", "f":
            return try parseBoolean()
        case "n":
            return try parseNull()
        case "-", "+", "0"..."9":
            return try parseNumber()
        default:
            if ch.isLetter || ch == "_" || ch == "$" {
                return try parseIdentifier()
            }
            throw JSONParserError.unexpectedCharacter(ch, at: index)
        }
    }

    private func parseObject() throws -> JSONObject {
        let start = index
        try consume("{")
        var properties: [JSONProperty] = []

        while true {
            skipWhitespaceAndComments()
            if let ch = peek(), ch == "}" {
                break
            }
            if properties.isEmpty == false {
                if peek() == "," {
                    advance()
                    skipWhitespaceAndComments()
                    if peek() == "}" {
                        break
                    }
                }
            }

            let propStart = index
            let key = try parseObjectKey()
            skipWhitespaceAndComments()
            try consume(":")
            skipWhitespaceAndComments()
            let value = try parseValue()
            let propEnd = value.sourceRange.upperBound
            properties.append(JSONProperty(key: key, value: value, range: propStart..<propEnd))
            skipWhitespaceAndComments()
        }

        try consume("}")
        return JSONObject(properties: properties, range: start..<index)
    }

    private func parseObjectKey() throws -> JSONNode {
        skipWhitespaceAndComments()
        guard let ch = peek() else { throw JSONParserError.unexpectedEOF }
        if ch == "\"" || ch == "'" {
            return try parseString()
        }
        if ch.isLetter || ch == "_" || ch == "$" {
            return try parseIdentifier()
        }
        if ch.isNumber {
            return try parseNumber()
        }
        throw JSONParserError.unexpectedCharacter(ch, at: index)
    }

    private func parseArray() throws -> JSONArray {
        let start = index
        try consume("[")
        var elements: [JSONNode] = []

        while true {
            skipWhitespaceAndComments()
            if let ch = peek(), ch == "]" {
                break
            }
            if elements.isEmpty == false {
                if peek() == "," {
                    advance()
                    skipWhitespaceAndComments()
                    if peek() == "]" {
                        break
                    }
                }
            }

            let elem = try parseValue()
            elements.append(elem)
            skipWhitespaceAndComments()
        }

        try consume("]")
        return JSONArray(elements: elements, range: start..<index)
    }

    private func parseString() throws -> JSONString {
        let start = index
        guard let quote = peek(), quote == "\"" || quote == "'" else {
            throw JSONParserError.unexpectedEOF
        }
        advance()

        var value = ""
        while let ch = peek() {
            if ch == quote {
                advance()
                let raw = String(chars[start..<index])
                return JSONString(value: value, raw: raw, range: start..<index)
            }
            if ch == "\\" {
                advance()
                guard let escaped = peek() else { throw JSONParserError.unexpectedEOF }
                advance()
                switch escaped {
                case "\"": value.append("\"")
                case "'": value.append("'")
                case "\\": value.append("\\")
                case "/": value.append("/")
                case "b": value.append("\u{0008}")
                case "f": value.append("\u{000c}")
                case "n": value.append("\n")
                case "r": value.append("\r")
                case "t": value.append("\t")
                case "u":
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = peek() else { throw JSONParserError.unexpectedEOF }
                        advance()
                        hex.append(h)
                    }
                    if let code = UInt32(hex, radix: 16), let scalar = UnicodeScalar(code) {
                        value.append(Character(scalar))
                    }
                default:
                    value.append(escaped)
                }
            } else {
                value.append(ch)
                advance()
            }
        }
        throw JSONParserError.unexpectedEOF
    }

    private func parseNumber() throws -> JSONNumber {
        let start = index
        while let ch = peek(), ch.isNumber || ch == "." || ch == "-" || ch == "+" || ch == "e" || ch == "E" {
            advance()
        }
        let raw = String(chars[start..<index])
        return JSONNumber(raw: raw, range: start..<index)
    }

    private func parseBoolean() throws -> JSONBoolean {
        let start = index
        if matchWord("true") {
            return JSONBoolean(value: true, range: start..<index)
        }
        if matchWord("false") {
            return JSONBoolean(value: false, range: start..<index)
        }
        throw JSONParserError.unexpectedCharacter(peek() ?? " ", at: index)
    }

    private func parseNull() throws -> JSONNull {
        let start = index
        if matchWord("null") {
            return JSONNull(sourceRange: start..<index)
        }
        throw JSONParserError.unexpectedCharacter(peek() ?? " ", at: index)
    }

    private func parseIdentifier() throws -> JSONIdentifier {
        let start = index
        while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" || ch == "$" {
            advance()
        }
        let name = String(chars[start..<index])
        return JSONIdentifier(name: name, range: start..<index)
    }

    private func skipWhitespaceAndComments() {
        while let ch = peek() {
            if ch.isWhitespace {
                advance()
            } else if ch == "/" && peek(1) == "/" {
                let start = index
                advance()
                advance()
                while let c = peek(), c != "\n" && c != "\r" {
                    advance()
                }
                let end = index
                let text = String(chars[start..<end])
                comments.append(Comment(text: text, range: start..<end, isBlock: false))
            } else if ch == "/" && peek(1) == "*" {
                let start = index
                advance()
                advance()
                while let c = peek() {
                    if c == "*" && peek(1) == "/" {
                        advance()
                        advance()
                        break
                    }
                    advance()
                }
                let end = index
                let text = String(chars[start..<end])
                comments.append(Comment(text: text, range: start..<end, isBlock: true))
            } else {
                break
            }
        }
    }

    private func peek(_ offset: Int = 0) -> Character? {
        let target = index + offset
        guard target < chars.count else { return nil }
        return chars[target]
    }

    private func advance() {
        if index < chars.count {
            index += 1
        }
    }

    private func consume(_ expected: Character) throws {
        guard let ch = peek() else { throw JSONParserError.unexpectedEOF }
        if ch == expected {
            advance()
        } else {
            throw JSONParserError.unexpectedCharacter(ch, at: index)
        }
    }

    private func matchWord(_ word: String) -> Bool {
        if index + word.count <= chars.count {
            var i = 0
            for c in word {
                if chars[index + i] != c { return false }
                i += 1
            }
            index += word.count
            return true
        }
        return false
    }
}
