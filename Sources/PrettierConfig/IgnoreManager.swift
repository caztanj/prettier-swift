import Foundation

public struct IgnorePattern: Sendable {
    public let raw: String
    public let isNegated: Bool
    public let isDirectoryOnly: Bool
    private let regex: NSRegularExpression?

    public init(pattern: String) {
        var str = pattern.trimmingCharacters(in: .whitespaces)
        self.raw = str

        if str.hasPrefix("!") {
            self.isNegated = true
            str.removeFirst()
        } else {
            self.isNegated = false
        }

        if str.hasSuffix("/") {
            self.isDirectoryOnly = true
            str.removeLast()
        } else {
            self.isDirectoryOnly = false
        }

        let regexStr = IgnorePattern.globToRegex(str)
        self.regex = try? NSRegularExpression(pattern: regexStr, options: [.caseInsensitive])
    }

    public func matches(relativePath: String) -> Bool {
        guard let regex else { return false }
        let range = NSRange(location: 0, length: relativePath.utf16.count)
        return regex.firstMatch(in: relativePath, options: [], range: range) != nil
    }

    private static func globToRegex(_ glob: String) -> String {
        var regex = "^"
        let isAnchored = glob.hasPrefix("/")
        let str = isAnchored ? String(glob.dropFirst()) : glob

        if !isAnchored && !str.contains("/") {
            regex += "(?:^|.*/)"
        }

        var idx = str.startIndex
        while idx < str.endIndex {
            let ch = str[idx]
            if ch == "*" {
                let nextIdx = str.index(after: idx)
                if nextIdx < str.endIndex && str[nextIdx] == "*" {
                    let afterNext = str.index(after: nextIdx)
                    if afterNext < str.endIndex && str[afterNext] == "/" {
                        regex += "(?:.*/)?"
                        idx = str.index(after: afterNext)
                        continue
                    } else {
                        regex += ".*"
                        idx = afterNext
                        continue
                    }
                } else {
                    regex += "[^/]*"
                    idx = nextIdx
                    continue
                }
            } else if ch == "?" {
                regex += "[^/]"
            } else if ch == "." || ch == "+" || ch == "(" || ch == ")" || ch == "[" || ch == "]" || ch == "{" || ch == "}" || ch == "^" || ch == "$" || ch == "|" || ch == "\\" {
                regex += "\\\(ch)"
            } else {
                regex += String(ch)
            }
            idx = str.index(after: idx)
        }

        regex += "(?:/.*)?$"
        return regex
    }
}

public struct IgnoreManager: Sendable {
    public let rootPath: String
    public let patterns: [IgnorePattern]

    public static let defaultIgnored = [
        "**/.git",
        "**/.svn",
        "**/.hg",
        "**/node_modules",
        "**/.build",
        "**/dist",
        "**/build",
        "**/.next",
        "**/.nuxt",
        "**/.cache",
        "**/coverage"
    ]

    public init(patterns: [String] = [], rootPath: String = FileManager.default.currentDirectoryPath) {
        self.rootPath = URL(fileURLWithPath: rootPath).standardized.path
        let allPatterns = IgnoreManager.defaultIgnored + patterns
        self.patterns = allPatterns
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { IgnorePattern(pattern: $0) }
    }

    public static func load(from filePath: String? = nil, rootPath: String = FileManager.default.currentDirectoryPath) -> IgnoreManager {
        let fileManager = FileManager.default
        let ignoreFilePath: String?

        if let filePath {
            ignoreFilePath = filePath
        } else {
            let candidate = URL(fileURLWithPath: rootPath).appendingPathComponent(".prettierignore").path
            ignoreFilePath = fileManager.fileExists(atPath: candidate) ? candidate : nil
        }

        guard let targetPath = ignoreFilePath,
              let content = try? String(contentsOfFile: targetPath, encoding: .utf8) else {
            return IgnoreManager(rootPath: rootPath)
        }

        let lines = content.components(separatedBy: "\n")
        return IgnoreManager(patterns: lines, rootPath: rootPath)
    }

    public func isIgnored(filePath: String) -> Bool {
        let fullPath = URL(fileURLWithPath: filePath).standardized.path

        var relativePath: String
        if fullPath.hasPrefix(rootPath) {
            relativePath = String(fullPath.dropFirst(rootPath.count))
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }
        } else {
            relativePath = fullPath
        }

        var ignored = false
        for pattern in patterns {
            if pattern.matches(relativePath: relativePath) {
                ignored = !pattern.isNegated
            }
        }
        return ignored
    }
}
