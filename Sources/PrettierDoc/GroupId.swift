import os

public struct GroupId: Hashable, Sendable, CustomStringConvertible {
    private static let counter = OSAllocatedUnfairLock(initialState: UInt(0))

    public let id: UInt
    public let name: String?

    public init(name: String? = nil) {
        self.id = Self.counter.withLock { count in
            count &+= 1
            return count
        }
        self.name = name
    }

    public var description: String {
        if let name {
            return "GroupId(\(id), name: \(name))"
        }
        return "GroupId(\(id))"
    }

    public static func == (lhs: GroupId, rhs: GroupId) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
