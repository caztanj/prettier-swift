public final class AstPath: @unchecked Sendable {
    public private(set) var stack: [Any]

    public init(_ root: Any) {
        self.stack = [root]
    }

    public var node: Any {
        stack[stack.count - 1]
    }

    public func node<T>(as type: T.Type = T.self) -> T? {
        node as? T
    }

    public var parent: Any? {
        getNode(1)
    }

    public func parent<T>(as type: T.Type = T.self) -> T? {
        parent as? T
    }

    public var grandparent: Any? {
        getNode(2)
    }

    public func grandparent<T>(as type: T.Type = T.self) -> T? {
        grandparent as? T
    }

    public var root: Any {
        stack[0]
    }

    public func root<T>(as type: T.Type = T.self) -> T? {
        root as? T
    }

    public var isRoot: Bool {
        stack.count == 1
    }

    public var isInArray: Bool {
        siblings != nil
    }

    public var siblings: [Any]? {
        guard stack.count >= 3 else { return nil }
        return stack[stack.count - 3] as? [Any]
    }

    public var index: Int? {
        guard siblings != nil, stack.count >= 2 else { return nil }
        return stack[stack.count - 2] as? Int
    }

    public var key: String? {
        if siblings == nil {
            guard stack.count >= 2 else { return nil }
            return stack[stack.count - 2] as? String
        } else {
            guard stack.count >= 4 else { return nil }
            return stack[stack.count - 4] as? String
        }
    }

    public var isFirst: Bool {
        index == 0
    }

    public var isLast: Bool {
        guard let siblings, let index else { return false }
        return index == siblings.count - 1
    }

    public var next: Any? {
        guard let siblings, let index, index + 1 < siblings.count else { return nil }
        return siblings[index + 1]
    }

    public var previous: Any? {
        guard let siblings, let index, index > 0 else { return nil }
        return siblings[index - 1]
    }

    public var ancestors: [Any] {
        var result: [Any] = []
        var idx = stack.count - 3
        while idx >= 0 {
            let val = stack[idx]
            if !(val is [Any]) {
                result.append(val)
            }
            idx -= 2
        }
        return result
    }

    public func getNode(_ count: Int = 0) -> Any? {
        let stackIndex = getNodeStackIndex(count)
        guard stackIndex >= 0 && stackIndex < stack.count else { return nil }
        return stack[stackIndex]
    }

    public func getParentNode(_ count: Int = 0) -> Any? {
        getNode(count + 1)
    }

    public func getValue() -> Any {
        node
    }

    public func getName() -> Any? {
        guard stack.count > 1 else { return nil }
        return stack[stack.count - 2]
    }

    private func getNodeStackIndex(_ count: Int) -> Int {
        var remaining = count
        var i = stack.count - 1
        while i >= 0 {
            if !(stack[i] is [Any]) {
                remaining -= 1
                if remaining < 0 {
                    return i
                }
            }
            i -= 2
        }
        return -1
    }

    @discardableResult
    public func call<R>(
        key: String? = nil,
        _ child: Any? = nil,
        _ callback: (AstPath) throws -> R
    ) rethrows -> R {
        let originalLength = stack.count
        let propertyName = key ?? ""
        let childValue: Any

        if let child {
            childValue = child
        } else if let dict = node as? [String: Any], let key {
            childValue = dict[key] as Any
        } else {
            childValue = ()
        }

        stack.append(propertyName)
        stack.append(childValue)
        defer {
            stack.removeLast(stack.count - originalLength)
        }
        return try callback(self)
    }

    @discardableResult
    public func call<R>(
        _ names: [String],
        _ callback: (AstPath) throws -> R
    ) rethrows -> R {
        let originalLength = stack.count
        var current: Any? = node
        for name in names {
            if let dict = current as? [String: Any] {
                current = dict[name]
            } else {
                current = nil
            }
            stack.append(name)
            stack.append(current as Any)
        }
        defer {
            stack.removeLast(stack.count - originalLength)
        }
        return try callback(self)
    }

    @discardableResult
    public func callParent<R>(
        count: Int = 0,
        _ callback: (AstPath) throws -> R
    ) rethrows -> R {
        let stackIndex = getNodeStackIndex(count + 1)
        guard stackIndex >= 0 else {
            return try callback(self)
        }
        let originalCount = stack.count
        let removed = Array(stack[(stackIndex + 1)...])
        stack.removeSubrange((stackIndex + 1)...)
        defer {
            stack.append(contentsOf: removed)
            assert(stack.count == originalCount)
        }
        return try callback(self)
    }

    public func each(
        key: String,
        _ array: [Any]? = nil,
        _ callback: (AstPath, Int, [Any]) throws -> Void
    ) rethrows {
        let elements: [Any]
        if let array {
            elements = array
        } else if let dict = node as? [String: Any], let arr = dict[key] as? [Any] {
            elements = arr
        } else {
            elements = []
        }

        let originalLength = stack.count
        stack.append(key)
        stack.append(elements)
        defer {
            stack.removeLast(stack.count - originalLength)
        }

        for i in 0..<elements.count {
            stack.append(i)
            stack.append(elements[i])
            try callback(self, i, elements)
            stack.removeLast(2)
        }
    }

    public func map<R>(
        key: String,
        _ array: [Any]? = nil,
        _ callback: (AstPath, Int, [Any]) throws -> R
    ) rethrows -> [R] {
        var results: [R] = []
        try each(key: key, array) { path, index, list in
            let res = try callback(path, index, list)
            results.append(res)
        }
        return results
    }

    public func findAncestor(_ predicate: (Any) -> Bool) -> Any? {
        for node in ancestors {
            if predicate(node) {
                return node
            }
        }
        return nil
    }

    public func hasAncestor(_ predicate: (Any) -> Bool) -> Bool {
        findAncestor(predicate) != nil
    }
}
