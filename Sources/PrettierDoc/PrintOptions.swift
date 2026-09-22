public enum EndOfLine: String, Sendable, Equatable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"
}

public struct PrintOptions: Sendable, Equatable {
    public var printWidth: Int
    public var tabWidth: Int
    public var useTabs: Bool
    public var endOfLine: EndOfLine
    public var semi: Bool
    public var singleQuote: Bool
    public var bracketSpacing: Bool

    public init(
        printWidth: Int = 80,
        tabWidth: Int = 2,
        useTabs: Bool = false,
        endOfLine: EndOfLine = .lf,
        semi: Bool = true,
        singleQuote: Bool = false,
        bracketSpacing: Bool = true
    ) {
        self.printWidth = printWidth
        self.tabWidth = tabWidth
        self.useTabs = useTabs
        self.endOfLine = endOfLine
        self.semi = semi
        self.singleQuote = singleQuote
        self.bracketSpacing = bracketSpacing
    }
}

public struct DocPrintOutput: Sendable, Equatable {
    public let formatted: String
    public let cursorNodeStart: Int?
    public let cursorNodeText: String?

    public init(
        formatted: String,
        cursorNodeStart: Int? = nil,
        cursorNodeText: String? = nil
    ) {
        self.formatted = formatted
        self.cursorNodeStart = cursorNodeStart
        self.cursorNodeText = cursorNodeText
    }
}

public enum DocPrinterError: Error, Equatable, CustomStringConvertible {
    case tooManyCursors

    public var description: String {
        switch self {
        case .tooManyCursors:
            return "There are too many 'cursor' in doc."
        }
    }
}
