import Synchronization

public struct GroupId: Hashable, Sendable, CustomStringConvertible {
    private static let counter = Atomic<UInt>(0)

    public let id: UInt
    public let name: String?

    public init(name: String? = nil) {
        self.id = Self.counter.wrappingAdd(1, ordering: .relaxed).newValue
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
