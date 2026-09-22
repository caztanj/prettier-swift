import Foundation

public struct CommentDecoration {
    public let enclosingNode: any CommentAttachable
    public let precedingNode: (any CommentAttachable)?
    public let followingNode: (any CommentAttachable)?
}

public func decorateComment(
    node: any CommentAttachable,
    comment: Comment
) -> CommentDecoration {
    let commentStart = comment.range.lowerBound
    let commentEnd = comment.range.upperBound

    let sortedChildren = node.childNodes.sorted {
        $0.sourceRange.lowerBound < $1.sourceRange.lowerBound
    }

    var precedingNode: (any CommentAttachable)?
    var followingNode: (any CommentAttachable)?

    var left = 0
    var right = sortedChildren.count

    while left < right {
        let middle = (left + right) / 2
        let child = sortedChildren[middle]
        let start = child.sourceRange.lowerBound
        let end = child.sourceRange.upperBound

        if start <= commentStart && commentEnd <= end {
            return decorateComment(node: child, comment: comment)
        }

        if end <= commentStart {
            precedingNode = child
            left = middle + 1
            continue
        }

        if commentEnd <= start {
            followingNode = child
            right = middle
            continue
        }

        break
    }

    return CommentDecoration(
        enclosingNode: node,
        precedingNode: precedingNode,
        followingNode: followingNode
    )
}

public func attachComments(
    root: any CommentAttachable,
    comments: [Comment],
    sourceText: String
) {
    guard !comments.isEmpty else { return }

    struct DecoratedContext {
        let comment: Comment
        let enclosingNode: any CommentAttachable
        var precedingNode: (any CommentAttachable)?
        var followingNode: (any CommentAttachable)?
    }

    var decoratedList: [DecoratedContext] = []
    for comment in comments {
        let decoration = decorateComment(node: root, comment: comment)
        decoratedList.append(DecoratedContext(
            comment: comment,
            enclosingNode: decoration.enclosingNode,
            precedingNode: decoration.precedingNode,
            followingNode: decoration.followingNode
        ))
    }

    var tiesToBreak: [DecoratedContext] = []

    func flushTies() {
        guard !tiesToBreak.isEmpty else { return }
        let first = tiesToBreak[0]
        guard let preceding = first.precedingNode,
              let following = first.followingNode else {
            tiesToBreak.removeAll()
            return
        }

        var gapEndPos = following.sourceRange.lowerBound
        var indexOfFirstLeading = tiesToBreak.count

        for i in stride(from: tiesToBreak.count - 1, through: 0, by: -1) {
            let item = tiesToBreak[i]
            let commentEnd = item.comment.range.upperBound
            if commentEnd <= gapEndPos {
                let startIdx = sourceText.index(sourceText.startIndex, offsetBy: commentEnd)
                let endIdx = sourceText.index(sourceText.startIndex, offsetBy: gapEndPos)
                let gap = String(sourceText[startIdx..<endIdx])
                let isOnlyWhitespaceOrOpenParen = gap.allSatisfy { $0.isWhitespace || $0 == "(" }
                if isOnlyWhitespaceOrOpenParen {
                    gapEndPos = item.comment.range.lowerBound
                    indexOfFirstLeading = i
                } else {
                    break
                }
            }
        }

        for (index, item) in tiesToBreak.enumerated() {
            if index < indexOfFirstLeading {
                item.comment.leading = false
                item.comment.trailing = true
                preceding.comments.append(item.comment)
            } else {
                item.comment.leading = true
                item.comment.trailing = false
                following.comments.append(item.comment)
            }
        }
        tiesToBreak.removeAll()
    }

    for (index, context) in decoratedList.enumerated() {
        let comment = context.comment
        let placement = determinePlacement(
            comment: comment,
            index: index,
            decoratedList: decoratedList,
            sourceText: sourceText
        )
        comment.placement = placement

        switch placement {
        case .ownLine:
            if let following = context.followingNode {
                comment.leading = true
                comment.trailing = false
                following.comments.append(comment)
            } else if let preceding = context.precedingNode {
                comment.leading = false
                comment.trailing = true
                preceding.comments.append(comment)
            } else {
                comment.leading = false
                comment.trailing = false
                context.enclosingNode.comments.append(comment)
            }

        case .endOfLine:
            if let preceding = context.precedingNode {
                comment.leading = false
                comment.trailing = true
                preceding.comments.append(comment)
            } else if let following = context.followingNode {
                comment.leading = true
                comment.trailing = false
                following.comments.append(comment)
            } else {
                comment.leading = false
                comment.trailing = false
                context.enclosingNode.comments.append(comment)
            }

        case .remaining:
            if context.precedingNode != nil,
               let following = context.followingNode {
                if !tiesToBreak.isEmpty && tiesToBreak.last?.followingNode !== following {
                    flushTies()
                }
                tiesToBreak.append(context)
            } else if let preceding = context.precedingNode {
                comment.leading = false
                comment.trailing = true
                preceding.comments.append(comment)
            } else if let following = context.followingNode {
                comment.leading = true
                comment.trailing = false
                following.comments.append(comment)
            } else {
                comment.leading = false
                comment.trailing = false
                context.enclosingNode.comments.append(comment)
            }
        }
    }

    flushTies()

    func sortComments(on node: any CommentAttachable) {
        node.comments.sort { $0.range.lowerBound < $1.range.lowerBound }
        for child in node.childNodes {
            sortComments(on: child)
        }
    }
    sortComments(on: root)
}

private func determinePlacement(
    comment: Comment,
    index: Int,
    decoratedList: [CommentDecorationRef],
    sourceText: String
) -> CommentPlacement {
    let commentStart = comment.range.lowerBound
    let commentEnd = comment.range.upperBound

    let hasNewlineBefore: Bool = {
        var pos = commentStart - 1
        while pos >= 0 {
            let ch = sourceText[sourceText.index(sourceText.startIndex, offsetBy: pos)]
            if ch == "\n" || ch == "\r" {
                return true
            }
            if !ch.isWhitespace {
                return false
            }
            pos -= 1
        }
        return true
    }()

    if hasNewlineBefore {
        return .ownLine
    }

    let hasNewlineAfter: Bool = {
        var pos = commentEnd
        let count = sourceText.count
        while pos < count {
            let ch = sourceText[sourceText.index(sourceText.startIndex, offsetBy: pos)]
            if ch == "\n" || ch == "\r" {
                return true
            }
            if !ch.isWhitespace {
                return false
            }
            pos += 1
        }
        return true
    }()

    if hasNewlineAfter {
        return .endOfLine
    }

    return .remaining
}

private typealias CommentDecorationRef = Any
