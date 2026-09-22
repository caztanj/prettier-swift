public func trimIndentation(_ text: String) -> (text: String, count: Int) {
    var count = 0
    for char in text.reversed() {
        if char == " " || char == "\t" {
            count += 1
        } else {
            break
        }
    }
    if count == 0 {
        return (text, 0)
    }
    let trimmed = String(text.dropLast(count))
    return (trimmed, count)
}

final class PrintResult {
    private var settledTexts: [String] = []
    private var unsettledText: String = ""
    private var settledTextLength: Int = 0
    private var settledPositions: [Int] = []
    private var unsettledPositions: [Int] = []

    func markPosition() throws {
        if settledPositions.count + unsettledPositions.count >= 2 {
            throw DocPrinterError.tooManyCursors
        }
        unsettledPositions.append(settledTextLength + unsettledText.count)
    }

    func write(_ text: String) {
        unsettledText += text
    }

    private func settle() {
        if !unsettledText.isEmpty {
            settledTexts.append(unsettledText)
            settledTextLength += unsettledText.count
            unsettledText = ""
        }
        for pos in unsettledPositions {
            settledPositions.append(min(pos, settledTextLength))
        }
        unsettledPositions.removeAll()
    }

    @discardableResult
    func trim() -> Int {
        let (trimmed, count) = trimIndentation(unsettledText)
        unsettledText = trimmed
        settle()
        return count
    }

    func finish() -> (text: String, positions: [Int]) {
        settle()
        return (settledTexts.joined(), settledPositions)
    }
}
