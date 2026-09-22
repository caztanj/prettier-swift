public func indent(_ contents: Doc) -> Doc {
    .indent(contents)
}

public func align(_ alignType: AlignType, _ contents: Doc) -> Doc {
    .align(alignType, contents)
}

public func align(_ n: Int, _ contents: Doc) -> Doc {
    .align(.number(n), contents)
}

public func align(_ string: String, _ contents: Doc) -> Doc {
    .align(.string(string), contents)
}

public func dedent(_ contents: Doc) -> Doc {
    .align(.number(-1), contents)
}

public func dedentToRoot(_ contents: Doc) -> Doc {
    .align(.toRoot, contents)
}

public func markAsRoot(_ contents: Doc) -> Doc {
    .align(.root, contents)
}

public func addAlignmentToDoc(_ doc: Doc, size: Int, tabWidth: Int) -> Doc {
    var aligned = doc
    if size > 0 {
        for _ in 0..<(size / tabWidth) {
            aligned = .indent(aligned)
        }
        aligned = .align(.number(size % tabWidth), aligned)
        aligned = .align(.toRoot, aligned)
    }
    return aligned
}

public func group(
    _ contents: Doc,
    id: GroupId? = nil,
    shouldBreak: Bool = false,
    expandedStates: [Doc]? = nil
) -> Doc {
    .group(
        contents: contents,
        id: id,
        shouldBreak: shouldBreak,
        expandedStates: expandedStates
    )
}

public func conditionalGroup(
    _ states: [Doc],
    id: GroupId? = nil,
    shouldBreak: Bool = false
) -> Doc {
    guard let first = states.first else {
        return .empty
    }
    return .group(
        contents: first,
        id: id,
        shouldBreak: shouldBreak,
        expandedStates: states
    )
}

public func ifBreak(
    _ breakContents: Doc,
    _ flatContents: Doc = .empty,
    groupId: GroupId? = nil
) -> Doc {
    .ifBreak(breakContents: breakContents, flatContents: flatContents, groupId: groupId)
}

public func indentIfBreak(_ contents: Doc, groupId: GroupId, negate: Bool = false) -> Doc {
    .indentIfBreak(contents, groupId: groupId, negate: negate)
}

public func fill(_ parts: [Doc]) -> Doc {
    .fill(parts)
}

public func join(separator: Doc, _ docs: [Doc]) -> [Doc] {
    var parts: [Doc] = []
    parts.reserveCapacity(max(0, docs.count * 2 - 1))
    for (index, doc) in docs.enumerated() {
        if index != 0 {
            parts.append(separator)
        }
        parts.append(doc)
    }
    return parts
}

public func lineSuffix(_ contents: Doc) -> Doc {
    .lineSuffix(contents)
}

public func label(_ label: String?, _ contents: Doc) -> Doc {
    guard let label, !label.isEmpty else {
        return contents
    }
    return .label(label, contents)
}

public let line: Doc = .line
public let softline: Doc = .softline
public let hardlineWithoutBreakParent: Doc = .hardlineWithoutBreakParent
public let literallineWithoutBreakParent: Doc = .literallineWithoutBreakParent
public let hardline: Doc = .hardline
public let literalline: Doc = .literalline
public let breakParent: Doc = .breakParent
public let lineSuffixBoundary: Doc = .lineSuffixBoundary
public let trim: Doc = .trim
public let cursor: Doc = .cursor
