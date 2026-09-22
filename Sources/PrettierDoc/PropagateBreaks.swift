public func propagateBreaks(_ doc: Doc) -> Doc {
    propagateBreaksHelper(doc).doc
}

private func propagateBreaksHelper(_ doc: Doc) -> (doc: Doc, containsBreak: Bool) {
    switch doc {
    case .breakParent:
        return (doc, true)

    case .concat(let parts):
        var newParts: [Doc] = []
        newParts.reserveCapacity(parts.count)
        var anyBreak = false
        for part in parts {
            let (newPart, hasBreak) = propagateBreaksHelper(part)
            newParts.append(newPart)
            if hasBreak {
                anyBreak = true
            }
        }
        return (.concat(newParts), anyBreak)

    case .group(let contents, let id, let shouldBreak, let expandedStates):
        if let expandedStates {
            var newStates: [Doc] = []
            for state in expandedStates {
                let (newState, _) = propagateBreaksHelper(state)
                newStates.append(newState)
            }
            let newDoc = Doc.group(
                contents: newStates.first ?? contents,
                id: id,
                shouldBreak: shouldBreak,
                expandedStates: newStates
            )
            return (newDoc, false)
        } else {
            let (newContents, childBreak) = propagateBreaksHelper(contents)
            let breaks = shouldBreak || childBreak
            let newDoc = Doc.group(
                contents: newContents,
                id: id,
                shouldBreak: breaks,
                expandedStates: nil
            )
            return (newDoc, breaks)
        }

    case .indent(let contents):
        let (newContents, childBreak) = propagateBreaksHelper(contents)
        return (.indent(newContents), childBreak)

    case .align(let alignType, let contents):
        let (newContents, childBreak) = propagateBreaksHelper(contents)
        return (.align(alignType, newContents), childBreak)

    case .ifBreak(let breakContents, let flatContents, let groupId):
        let (newBreak, breakHasBreak) = propagateBreaksHelper(breakContents)
        let (newFlat, _) = propagateBreaksHelper(flatContents)
        return (.ifBreak(breakContents: newBreak, flatContents: newFlat, groupId: groupId), breakHasBreak)

    case .fill(let parts, let offset):
        var newParts: [Doc] = []
        newParts.reserveCapacity(parts.count)
        var anyBreak = false
        for part in parts {
            let (newPart, hasBreak) = propagateBreaksHelper(part)
            newParts.append(newPart)
            if hasBreak {
                anyBreak = true
            }
        }
        return (.fill(newParts, offset: offset), anyBreak)

    case .indentIfBreak(let contents, let groupId, let negate):
        let (newContents, childBreak) = propagateBreaksHelper(contents)
        return (.indentIfBreak(newContents, groupId: groupId, negate: negate), childBreak)

    case .label(let label, let contents):
        let (newContents, childBreak) = propagateBreaksHelper(contents)
        return (.label(label, newContents), childBreak)

    case .lineSuffix(let contents):
        let (newContents, childBreak) = propagateBreaksHelper(contents)
        return (.lineSuffix(newContents), childBreak)

    case .text, .line, .lineSuffixBoundary, .trim, .cursor:
        return (doc, false)
    }
}
