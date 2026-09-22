import Testing
@testable import PrettierCore

@Suite("PrettierCore AstPath Tests")
struct AstPathTests {
    struct DummyError: Error, Equatable {}

    @Test("AstPath basic navigation and call")
    func basicCall() {
        let ast: [String: Any] = [
            "property": [
                "deep": ["name": "deep"]
            ],
            "children": [
                ["index": 0],
                ["index": 1]
            ]
        ]

        let path = AstPath(ast)
        #expect(path.isRoot)
        #expect(path.stack.count == 1)

        path.call(key: "property") { path in
            #expect(!path.isRoot)
            #expect(path.key == "property")
            #expect(path.parent != nil)

            path.call(key: "deep") { path in
                #expect(path.key == "deep")
                let val = path.node as? [String: String]
                #expect(val?["name"] == "deep")
                #expect(path.parent != nil)
                #expect(path.grandparent != nil)
            }
        }

        #expect(path.isRoot)
        #expect(path.stack.count == 1)
    }

    @Test("AstPath callParent restoration")
    func callParent() {
        let ast: [String: Any] = [
            "property": [
                "deep": ["name": "deep"]
            ]
        ]

        let path = AstPath(ast)
        path.call(key: "property") { path in
            path.call(key: "deep") { path in
                let parentVal = path.callParent { p -> [String: Any]? in
                    p.node as? [String: Any]
                }
                #expect(parentVal?["deep"] != nil)
            }
        }
        #expect(path.stack.count == 1)
    }

    @Test("AstPath each and map with array siblings")
    func eachAndMap() {
        let ast: [String: Any] = [
            "children": ["first", "second", "third"]
        ]

        let path = AstPath(ast)

        var seen: [String] = []
        path.each(key: "children") { path, index, list in
            #expect(path.isInArray)
            #expect(path.index == index)
            #expect(path.key == "children")
            if index == 0 {
                #expect(path.isFirst)
                #expect(!path.isLast)
                #expect((path.next as? String) == "second")
                #expect(path.previous == nil)
            } else if index == 2 {
                #expect(!path.isFirst)
                #expect(path.isLast)
                #expect(path.next == nil)
                #expect((path.previous as? String) == "second")
            }
            if let str = path.node as? String {
                seen.append(str)
            }
        }
        #expect(seen == ["first", "second", "third"])
        #expect(path.stack.count == 1)

        let mapped = path.map(key: "children") { path, index, _ in
            "\(index): \(path.node)"
        }
        #expect(mapped == ["0: first", "1: second", "2: third"])
        #expect(path.stack.count == 1)
    }

    @Test("AstPath restores stack on throw")
    func restoreOnThrow() {
        let ast: [String: Any] = ["key": "value"]
        let path = AstPath(ast)

        #expect(throws: DummyError.self) {
            try path.call(key: "key") { _ in
                throw DummyError()
            }
        }
        #expect(path.stack.count == 1)
    }
}
