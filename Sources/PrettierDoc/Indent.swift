public enum IndentCommand: Sendable, Equatable {
    case indent
    case dedent
    case width(Int)
    case string(String)
}

public struct Indent: Sendable, Equatable {
    public var value: String
    public var length: Int
    public var queue: [IndentCommand]
    public var root: Box<Indent>?

    public init(
        value: String = "",
        length: Int = 0,
        queue: [IndentCommand] = [],
        root: Box<Indent>? = nil
    ) {
        self.value = value
        self.length = length
        self.queue = queue
        self.root = root
    }

    public static let root = Indent()
}

public final class Box<T: Sendable & Equatable>: @unchecked Sendable, Equatable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        lhs.value == rhs.value
    }
}

public func generateIndent(
    indent: Indent,
    command: IndentCommand,
    options: PrintOptions
) -> Indent {
    let queue: [IndentCommand]
    if command == .dedent {
        queue = indent.queue.isEmpty ? [] : Array(indent.queue.dropLast())
    } else {
        var q = indent.queue
        q.append(command)
        queue = q
    }

    var value = ""
    var length = 0
    var lastTabs = 0
    var lastSpaces = 0

    func addTabs(_ count: Int) {
        value += String(repeating: "\t", count: count)
        length += options.tabWidth * count
    }

    func addSpaces(_ count: Int) {
        value += String(repeating: " ", count: count)
        length += count
    }

    func resetLast() {
        lastTabs = 0
        lastSpaces = 0
    }

    func flushTabs() {
        if lastTabs > 0 {
            addTabs(lastTabs)
        }
        resetLast()
    }

    func flushSpaces() {
        if lastSpaces > 0 {
            addSpaces(lastSpaces)
        }
        resetLast()
    }

    func flush() {
        if options.useTabs {
            flushTabs()
        } else {
            flushSpaces()
        }
    }

    for cmd in queue {
        switch cmd {
        case .indent:
            flush()
            if options.useTabs {
                addTabs(1)
            } else {
                addSpaces(options.tabWidth)
            }
        case .string(let string):
            flush()
            value += string
            length += string.count
        case .width(let width):
            lastTabs += 1
            lastSpaces += width
        case .dedent:
            break
        }
    }

    flushSpaces()

    return Indent(
        value: value,
        length: length,
        queue: queue,
        root: indent.root
    )
}

public func makeAlign(
    indent: Indent,
    alignType: AlignType,
    options: PrintOptions
) -> Indent {
    switch alignType {
    case .root:
        var copy = indent
        copy.root = Box(indent)
        return copy
    case .toRoot:
        return indent.root?.value ?? Indent.root
    case .number(let n):
        if n < 0 {
            return generateIndent(indent: indent, command: .dedent, options: options)
        } else {
            return generateIndent(indent: indent, command: .width(n), options: options)
        }
    case .string(let str):
        return generateIndent(indent: indent, command: .string(str), options: options)
    }
}

public func makeIndent(indent: Indent, options: PrintOptions) -> Indent {
    generateIndent(indent: indent, command: .indent, options: options)
}
