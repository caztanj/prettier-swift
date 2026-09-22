private func isControlCharacter(_ scalarValue: UInt32) -> Bool {
    scalarValue <= 0x1f || (scalarValue >= 0x7f && scalarValue <= 0x9f)
}

private func isFullWidthCharacter(_ scalarValue: UInt32) -> Bool {
    (scalarValue >= 0x1100 && scalarValue <= 0x115f) ||
    scalarValue == 0x2329 || scalarValue == 0x232a ||
    (scalarValue >= 0x2e80 && scalarValue <= 0xa4cf && scalarValue != 0x303f) ||
    (scalarValue >= 0xac00 && scalarValue <= 0xd7a3) ||
    (scalarValue >= 0xf900 && scalarValue <= 0xfaff) ||
    (scalarValue >= 0xfe10 && scalarValue <= 0xfe19) ||
    (scalarValue >= 0xfe30 && scalarValue <= 0xfe6f) ||
    (scalarValue >= 0xff00 && scalarValue <= 0xff60) ||
    (scalarValue >= 0xffe0 && scalarValue <= 0xffe6) ||
    (scalarValue >= 0x20000 && scalarValue <= 0x2fffd) ||
    (scalarValue >= 0x30000 && scalarValue <= 0x3fffd)
}

public func getStringWidth(_ text: String) -> Int {
    if text.isEmpty { return 0 }
    if text.allSatisfy({ $0.isASCII }) {
        return text.count
    }
    var width = 0
    for char in text {
        if let scalar = char.unicodeScalars.first {
            let val = scalar.value
            if isControlCharacter(val) {
                continue
            }
            if isFullWidthCharacter(val) {
                width += 2
                continue
            }
        }
        width += 1
    }
    return width
}
