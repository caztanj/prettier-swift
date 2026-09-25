// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prettier",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "prettier-swift", targets: ["prettier-swift"]),
        .library(name: "Prettier", targets: ["Prettier"]),
        .library(name: "PrettierStatic", type: .static, targets: ["Prettier"]),
        .library(name: "PrettierDynamic", type: .dynamic, targets: ["Prettier"]),
        .library(name: "PrettierDoc", targets: ["PrettierDoc"]),
        .library(name: "PrettierCore", targets: ["PrettierCore"]),
        .library(name: "PrettierJSON", targets: ["PrettierJSON"]),
        .library(name: "PrettierYAML", targets: ["PrettierYAML"]),
        .library(name: "PrettierMarkdown", targets: ["PrettierMarkdown"]),
        .library(name: "PrettierCSS", targets: ["PrettierCSS"]),
        .library(name: "PrettierHTML", targets: ["PrettierHTML"]),
        .library(name: "PrettierJS", targets: ["PrettierJS"]),
        .library(name: "PrettierGraphQL", targets: ["PrettierGraphQL"]),
        .library(name: "PrettierConfig", targets: ["PrettierConfig"]),
    ],
    targets: [
        .target(
            name: "PrettierDoc",
            path: "Sources/PrettierDoc"
        ),
        .target(
            name: "PrettierCore",
            dependencies: ["PrettierDoc"],
            path: "Sources/PrettierCore"
        ),
        .target(
            name: "PrettierJSON",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierJSON"
        ),
        .target(
            name: "PrettierYAML",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierYAML"
        ),
        .target(
            name: "PrettierMarkdown",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierMarkdown"
        ),
        .target(
            name: "PrettierCSS",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierCSS"
        ),
        .target(
            name: "PrettierHTML",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierHTML"
        ),
        .target(
            name: "PrettierJS",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierJS"
        ),
        .target(
            name: "PrettierGraphQL",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "Sources/PrettierGraphQL"
        ),
        .target(
            name: "PrettierConfig",
            dependencies: ["PrettierCore", "PrettierDoc", "PrettierJSON", "PrettierYAML"],
            path: "Sources/PrettierConfig"
        ),
        .target(
            name: "Prettier",
            dependencies: [
                "PrettierCore",
                "PrettierDoc",
                "PrettierJSON",
                "PrettierYAML",
                "PrettierMarkdown",
                "PrettierCSS",
                "PrettierHTML",
                "PrettierJS",
                "PrettierGraphQL",
                "PrettierConfig",
            ],
            path: "Sources/Prettier"
        ),
        .executableTarget(
            name: "prettier-swift",
            dependencies: ["Prettier"],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "PrettierDocTests",
            dependencies: ["PrettierDoc"],
            path: "SwiftTests/PrettierDocTests"
        ),
        .testTarget(
            name: "PrettierCoreTests",
            dependencies: ["PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierCoreTests"
        ),
        .testTarget(
            name: "PrettierJSONTests",
            dependencies: ["PrettierJSON", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierJSONTests"
        ),
        .testTarget(
            name: "PrettierYAMLTests",
            dependencies: ["PrettierYAML", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierYAMLTests"
        ),
        .testTarget(
            name: "PrettierMarkdownTests",
            dependencies: ["PrettierMarkdown", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierMarkdownTests"
        ),
        .testTarget(
            name: "PrettierCSSTests",
            dependencies: ["PrettierCSS", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierCSSTests"
        ),
        .testTarget(
            name: "PrettierHTMLTests",
            dependencies: ["PrettierHTML", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierHTMLTests"
        ),
        .testTarget(
            name: "PrettierJSTests",
            dependencies: ["PrettierJS", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierJSTests"
        ),
        .testTarget(
            name: "PrettierGraphQLTests",
            dependencies: ["PrettierGraphQL", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierGraphQLTests"
        ),
        .testTarget(
            name: "PrettierConfigTests",
            dependencies: ["PrettierConfig", "PrettierCore", "PrettierDoc"],
            path: "SwiftTests/PrettierConfigTests"
        ),
        .testTarget(
            name: "PrettierTests",
            dependencies: ["Prettier"],
            path: "SwiftTests/PrettierTests"
        ),
    ]
)
