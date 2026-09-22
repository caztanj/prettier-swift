public enum PrintMode: Sendable, Equatable {
    case `break`
    case flat
}

public struct PrintCommand: Sendable {
    public let indent: Indent
    public let mode: PrintMode
    public let doc: Doc

    public init(indent: Indent, mode: PrintMode, doc: Doc) {
        self.indent = indent
        self.mode = mode
        self.doc = doc
    }
}

public struct FitCommand: Sendable {
    public let mode: PrintMode
    public let doc: Doc

    public init(mode: PrintMode, doc: Doc) {
        self.mode = mode
        self.doc = doc
    }
}

public func fits(
    next: PrintCommand,
    restCommands: [PrintCommand],
    remainingWidth: Int,
    hasLineSuffix: Bool,
    groupModeMap: [GroupId: PrintMode],
    mustBeFlat: Bool = false
) -> Bool {
    var remainingWidth = remainingWidth
    if remainingWidth >= Int.max / 2 {
        return true
    }

    var restCommandsIndex = restCommands.count
    var hasPendingSpace = false
    var hasLineSuffix = hasLineSuffix
    var commands: [FitCommand] = [FitCommand(mode: next.mode, doc: next.doc)]
    var trailingSpaces = 0

    while remainingWidth >= 0 {
        guard let current = commands.popLast() else {
            if restCommandsIndex == 0 {
                return true
            }
            restCommandsIndex -= 1
            let rest = restCommands[restCommandsIndex]
            commands.append(FitCommand(mode: rest.mode, doc: rest.doc))
            continue
        }

        let mode = current.mode
        let doc = current.doc

        switch doc {
        case .text(let str):
            if !str.isEmpty {
                if hasPendingSpace {
                    remainingWidth -= 1
                    trailingSpaces += 1
                    hasPendingSpace = false
                }
                remainingWidth -= getStringWidth(str)
                var spaces = 0
                for c in str.reversed() {
                    if c == " " || c == "\t" {
                        spaces += 1
                    } else {
                        break
                    }
                }
                if spaces == str.count {
                    trailingSpaces += spaces
                } else {
                    trailingSpaces = spaces
                }
            }

        case .concat(let parts):
            for part in parts.reversed() {
                commands.append(FitCommand(mode: mode, doc: part))
            }

        case .fill(let parts, let offset):
            if offset < parts.count {
                for index in stride(from: parts.count - 1, through: offset, by: -1) {
                    commands.append(FitCommand(mode: mode, doc: parts[index]))
                }
            }

        case .indent(let contents),
             .align(_, let contents),
             .indentIfBreak(let contents, _, _),
             .label(_, let contents):
            commands.append(FitCommand(mode: mode, doc: contents))

        case .trim:
            remainingWidth += trailingSpaces
            trailingSpaces = 0

        case .group(let contents, _, let shouldBreak, let expandedStates):
            if mustBeFlat && shouldBreak {
                return false
            }
            let groupMode: PrintMode = shouldBreak ? .break : mode
            let target = (expandedStates != nil && groupMode == .break)
                ? (expandedStates!.last ?? contents)
                : contents
            commands.append(FitCommand(mode: groupMode, doc: target))

        case .ifBreak(let breakContents, let flatContents, let groupId):
            let groupMode = groupId.flatMap { groupModeMap[$0] } ?? mode
            let target = groupMode == .break ? breakContents : flatContents
            if target != .empty {
                commands.append(FitCommand(mode: mode, doc: target))
            }

        case .line(let lineKind):
            if mode == .break || lineKind.isHard {
                return true
            }
            if !lineKind.isSoft {
                hasPendingSpace = true
            }

        case .lineSuffix:
            hasLineSuffix = true

        case .lineSuffixBoundary:
            if hasLineSuffix {
                return false
            }

        case .breakParent, .cursor:
            break
        }
    }

    return false
}

public func printDocToString(
    _ doc: Doc,
    options: PrintOptions = PrintOptions()
) throws -> DocPrintOutput {
    var groupModeMap: [GroupId: PrintMode] = [:]
    let width = options.printWidth
    let newLine = options.endOfLine.rawValue
    var position = 0
    var shouldRemeasure = false
    var lineSuffix: [PrintCommand] = []

    let result = PrintResult()
    let preparedDoc = propagateBreaks(doc)

    var commands: [PrintCommand] = [
        PrintCommand(indent: .root, mode: .break, doc: preparedDoc)
    ]

    while let current = commands.popLast() {
        let indent = current.indent
        let mode = current.mode
        let doc = current.doc

        switch doc {
        case .text(let str):
            let formatted = newLine != "\n"
                ? str.replacing("\n", with: newLine)
                : str
            if !formatted.isEmpty {
                result.write(formatted)
                if !commands.isEmpty {
                    position += getStringWidth(formatted)
                }
            }

        case .concat(let parts):
            for part in parts.reversed() {
                commands.append(PrintCommand(indent: indent, mode: mode, doc: part))
            }

        case .cursor:
            try result.markPosition()

        case .indent(let contents):
            commands.append(PrintCommand(
                indent: makeIndent(indent: indent, options: options),
                mode: mode,
                doc: contents
            ))

        case .align(let alignType, let contents):
            commands.append(PrintCommand(
                indent: makeAlign(indent: indent, alignType: alignType, options: options),
                mode: mode,
                doc: contents
            ))

        case .trim:
            position -= result.trim()

        case .group(let contents, let id, let shouldBreak, let expandedStates):
            let groupCommand: PrintCommand = {
                if mode == .flat && !shouldRemeasure {
                    return PrintCommand(
                        indent: indent,
                        mode: shouldBreak ? .break : .flat,
                        doc: contents
                    )
                }

                shouldRemeasure = false
                let remainingWidth = width - position
                let hasLineSuffix = !lineSuffix.isEmpty

                let flatCommand = PrintCommand(indent: indent, mode: .flat, doc: contents)
                if !shouldBreak && fits(
                    next: flatCommand,
                    restCommands: commands,
                    remainingWidth: remainingWidth,
                    hasLineSuffix: hasLineSuffix,
                    groupModeMap: groupModeMap
                ) {
                    return flatCommand
                }

                if let states = expandedStates {
                    if !shouldBreak && states.count > 2 {
                        for index in 1..<(states.count - 1) {
                            let candidate = PrintCommand(
                                indent: indent,
                                mode: .flat,
                                doc: states[index]
                            )
                            if fits(
                                next: candidate,
                                restCommands: commands,
                                remainingWidth: remainingWidth,
                                hasLineSuffix: hasLineSuffix,
                                groupModeMap: groupModeMap
                            ) {
                                return candidate
                            }
                        }
                    }
                    return PrintCommand(
                        indent: indent,
                        mode: .break,
                        doc: states.last ?? contents
                    )
                }

                return PrintCommand(indent: indent, mode: .break, doc: contents)
            }()

            commands.append(groupCommand)
            if let id {
                groupModeMap[id] = groupCommand.mode
            }

        case .fill(let parts, let offset):
            let remainingWidth = width - position
            let length = parts.count - offset
            if length <= 0 {
                break
            }

            let content = parts[offset + 0]
            let contentFlat = PrintCommand(indent: indent, mode: .flat, doc: content)
            let contentBreak = PrintCommand(indent: indent, mode: .break, doc: content)
            let contentFits = fits(
                next: contentFlat,
                restCommands: [],
                remainingWidth: remainingWidth,
                hasLineSuffix: !lineSuffix.isEmpty,
                groupModeMap: groupModeMap,
                mustBeFlat: true
            )

            if length == 1 {
                commands.append(contentFits ? contentFlat : contentBreak)
                break
            }

            let whitespace = parts[offset + 1]
            let wsFlat = PrintCommand(indent: indent, mode: .flat, doc: whitespace)
            let wsBreak = PrintCommand(indent: indent, mode: .break, doc: whitespace)

            if length == 2 {
                if contentFits {
                    commands.append(wsFlat)
                    commands.append(contentFlat)
                } else {
                    commands.append(wsBreak)
                    commands.append(contentBreak)
                }
                break
            }

            let secondContent = parts[offset + 2]
            let remainingCommand = PrintCommand(
                indent: indent,
                mode: mode,
                doc: .fill(parts, offset: offset + 2)
            )

            let firstAndSecondFlat = PrintCommand(
                indent: indent,
                mode: .flat,
                doc: .concat([content, whitespace, secondContent])
            )
            let firstAndSecondFits = fits(
                next: firstAndSecondFlat,
                restCommands: [],
                remainingWidth: remainingWidth,
                hasLineSuffix: !lineSuffix.isEmpty,
                groupModeMap: groupModeMap,
                mustBeFlat: true
            )

            commands.append(remainingCommand)

            if firstAndSecondFits {
                commands.append(wsFlat)
                commands.append(contentFlat)
            } else if contentFits {
                commands.append(wsBreak)
                commands.append(contentFlat)
            } else {
                commands.append(wsBreak)
                commands.append(contentBreak)
            }

        case .ifBreak(let breakContents, let flatContents, let groupId):
            let groupMode = groupId.flatMap { groupModeMap[$0] } ?? mode
            if groupMode == .break && breakContents != .empty {
                commands.append(PrintCommand(indent: indent, mode: mode, doc: breakContents))
            } else if groupMode == .flat && flatContents != .empty {
                commands.append(PrintCommand(indent: indent, mode: mode, doc: flatContents))
            }

        case .indentIfBreak(let contents, let groupId, let negate):
            let groupMode = groupModeMap[groupId] ?? mode
            if groupMode == .break {
                let docToPush: Doc = negate ? contents : .indent(contents)
                commands.append(PrintCommand(indent: indent, mode: mode, doc: docToPush))
            } else if groupMode == .flat {
                let docToPush: Doc = negate ? .indent(contents) : contents
                commands.append(PrintCommand(indent: indent, mode: mode, doc: docToPush))
            }

        case .lineSuffix(let contents):
            lineSuffix.append(PrintCommand(indent: indent, mode: mode, doc: contents))

        case .lineSuffixBoundary:
            if !lineSuffix.isEmpty {
                commands.append(PrintCommand(
                    indent: indent,
                    mode: mode,
                    doc: .line(.hardWithoutBreakParent)
                ))
            }

        case .line(let lineKind):
            switch mode {
            case .flat:
                if !lineKind.isHard {
                    if !lineKind.isSoft {
                        result.write(" ")
                        position += 1
                    }
                    break
                }
                shouldRemeasure = true
                fallthrough

            case .break:
                if !lineSuffix.isEmpty {
                    commands.append(PrintCommand(indent: indent, mode: mode, doc: doc))
                    for s in lineSuffix.reversed() {
                        commands.append(s)
                    }
                    lineSuffix.removeAll()
                    break
                }

                if lineKind.isLiteral {
                    result.write(newLine)
                    position = 0
                    if let rootVal = indent.root?.value.value, !rootVal.isEmpty {
                        result.write(rootVal)
                        position = indent.root?.value.length ?? 0
                    }
                } else {
                    result.trim()
                    result.write(newLine + indent.value)
                    position = indent.length
                }
            }

        case .label(_, let contents):
            commands.append(PrintCommand(indent: indent, mode: mode, doc: contents))

        case .breakParent:
            break
        }

        if commands.isEmpty && !lineSuffix.isEmpty {
            for s in lineSuffix.reversed() {
                commands.append(s)
            }
            lineSuffix.removeAll()
        }
    }

    let (formatted, cursorPositions) = result.finish()

    if cursorPositions.count != 2 {
        return DocPrintOutput(formatted: formatted)
    }

    let start = cursorPositions[0]
    let end = cursorPositions[1]
    let startIdx = formatted.index(formatted.startIndex, offsetBy: start)
    let endIdx = formatted.index(formatted.startIndex, offsetBy: end)
    let cursorText = String(formatted[startIdx..<endIdx])

    return DocPrintOutput(
        formatted: formatted,
        cursorNodeStart: start,
        cursorNodeText: cursorText
    )
}
