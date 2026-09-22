import PrettierDoc

public struct CommentPrinter {
    public static func printLeading(
        comments: [Comment],
        sourceText: String
    ) -> [Doc] {
        var docs: [Doc] = []
        let leading = comments.filter { $0.leading && !$0.printed }

        for comment in leading {
            comment.printed = true
            var parts: [Doc] = [Doc.text(comment.text)]

            if comment.isBlock {
                let hasNewlineBefore = hasLineBreakBefore(offset: comment.range.lowerBound, in: sourceText)
                let hasNewlineAfter = hasLineBreakAfter(offset: comment.range.upperBound, in: sourceText)
                if hasNewlineAfter {
                    parts.append(hasNewlineBefore ? .hardline : .line)
                } else {
                    parts.append(" ")
                }
            } else {
                parts.append(.hardline)
            }

            if hasEmptyLineAfter(offset: comment.range.upperBound, in: sourceText) {
                parts.append(.hardline)
            }

            docs.append(.concat(parts))
        }

        return docs
    }

    public static func printTrailing(
        comments: [Comment],
        sourceText: String
    ) -> [Doc] {
        var docs: [Doc] = []
        let trailing = comments.filter { $0.trailing && !$0.printed }

        for comment in trailing {
            comment.printed = true
            let printed = Doc.text(comment.text)

            let isOwnLine = hasLineBreakBefore(offset: comment.range.lowerBound, in: sourceText)
            if isOwnLine {
                let isLineBeforeEmpty = hasEmptyLineBefore(offset: comment.range.lowerBound, in: sourceText)
                let inner: [Doc] = [
                    .hardline,
                    isLineBeforeEmpty ? .hardline : .empty,
                    printed
                ]
                docs.append(.lineSuffix(.concat(inner)))
            } else {
                docs.append(.concat([.lineSuffix([" ", printed]), .breakParent]))
            }
        }

        return docs
    }

    public static func printDangling(
        comments: [Comment],
        indent: Bool = false
    ) -> Doc {
        let dangling = comments.filter { !$0.leading && !$0.trailing && !$0.printed }
        guard !dangling.isEmpty else { return .empty }

        for comment in dangling {
            comment.printed = true
        }

        let parts = dangling.map { Doc.text($0.text) }
        let joined = Doc.concat(join(separator: .hardline, parts))
        return indent ? .indent([.hardline, joined]) : joined
    }

    public static func wrapWithComments(
        doc: Doc,
        node: any CommentAttachable,
        sourceText: String
    ) -> Doc {
        let leading = printLeading(comments: node.comments, sourceText: sourceText)
        let trailing = printTrailing(comments: node.comments, sourceText: sourceText)

        if leading.isEmpty && trailing.isEmpty {
            return doc
        }

        var parts: [Doc] = []
        parts.append(contentsOf: leading)
        parts.append(doc)
        parts.append(contentsOf: trailing)
        return .concat(parts)
    }

    private static func hasLineBreakBefore(offset: Int, in text: String) -> Bool {
        var pos = offset - 1
        while pos >= 0 {
            let ch = text[text.index(text.startIndex, offsetBy: pos)]
            if ch == "\n" || ch == "\r" { return true }
            if !ch.isWhitespace { return false }
            pos -= 1
        }
        return true
    }

    private static func hasLineBreakAfter(offset: Int, in text: String) -> Bool {
        var pos = offset
        let count = text.count
        while pos < count {
            let ch = text[text.index(text.startIndex, offsetBy: pos)]
            if ch == "\n" || ch == "\r" { return true }
            if !ch.isWhitespace { return false }
            pos += 1
        }
        return true
    }

    private static func hasEmptyLineAfter(offset: Int, in text: String) -> Bool {
        var pos = offset
        let count = text.count
        var newlineCount = 0
        while pos < count {
            let ch = text[text.index(text.startIndex, offsetBy: pos)]
            if ch == "\n" {
                newlineCount += 1
                if newlineCount >= 2 { return true }
            } else if !ch.isWhitespace && ch != "\r" {
                return false
            }
            pos += 1
        }
        return false
    }

    private static func hasEmptyLineBefore(offset: Int, in text: String) -> Bool {
        var pos = offset - 1
        var newlineCount = 0
        while pos >= 0 {
            let ch = text[text.index(text.startIndex, offsetBy: pos)]
            if ch == "\n" {
                newlineCount += 1
                if newlineCount >= 2 { return true }
            } else if !ch.isWhitespace && ch != "\r" {
                return false
            }
            pos -= 1
        }
        return false
    }
}
