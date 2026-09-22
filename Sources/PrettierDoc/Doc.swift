public enum AlignType: Sendable, Equatable {
    case number(Int)
    case string(String)
    case root
    case toRoot
}

public struct LineKind: Sendable, Equatable {
    public let isSoft: Bool
    public let isHard: Bool
    public let isLiteral: Bool

    public init(isSoft: Bool = false, isHard: Bool = false, isLiteral: Bool = false) {
        self.isSoft = isSoft
        self.isHard = isHard
        self.isLiteral = isLiteral
    }

    public static let normal = LineKind()
    public static let soft = LineKind(isSoft: true)
    public static let hardWithoutBreakParent = LineKind(isHard: true)
    public static let literalWithoutBreakParent = LineKind(isHard: true, isLiteral: true)
}

public enum Doc: Sendable, Equatable {
    case text(String)
    case concat([Doc])
    indirect case indent(Doc)
    indirect case align(AlignType, Doc)
    indirect case group(
        contents: Doc,
        id: GroupId? = nil,
        shouldBreak: Bool = false,
        expandedStates: [Doc]? = nil
    )
    indirect case ifBreak(
        breakContents: Doc,
        flatContents: Doc = .text(""),
        groupId: GroupId? = nil
    )
    case line(LineKind)
    case breakParent
    indirect case lineSuffix(Doc)
    case lineSuffixBoundary
    case trim
    case fill([Doc], offset: Int = 0)
    indirect case indentIfBreak(Doc, groupId: GroupId, negate: Bool = false)
    indirect case label(String, Doc)
    case cursor

    public static let empty = Doc.text("")
    public static let line = Doc.line(.normal)
    public static let softline = Doc.line(.soft)
    public static let hardlineWithoutBreakParent = Doc.line(.hardWithoutBreakParent)
    public static let literallineWithoutBreakParent = Doc.line(.literalWithoutBreakParent)
    public static let hardline = Doc.concat([.line(.hardWithoutBreakParent), .breakParent])
    public static let literalline = Doc.concat([.line(.literalWithoutBreakParent), .breakParent])
}

extension Doc: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension Doc: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Doc...) {
        self = .concat(elements)
    }
}
