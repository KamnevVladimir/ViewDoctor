// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ViewDoctor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "viewdoctor", targets: ["ViewDoctorCLI"]),
        .library(name: "ViewDoctorCore", targets: ["ViewDoctorCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        .target(name: "ViewDoctorCore"),
        .target(
            name: "ViewDoctorGraph",
            dependencies: [
                "ViewDoctorCore",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(name: "ViewDoctorDiscovery", dependencies: ["ViewDoctorCore", "ViewDoctorGraph"]),
        .target(
            name: "ViewDoctorSyntax",
            dependencies: [
                "ViewDoctorCore",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "ViewDoctorRules",
            dependencies: ["ViewDoctorCore", "ViewDoctorSyntax"]
        ),
        .executableTarget(
            name: "ViewDoctorCLI",
            dependencies: [
                "ViewDoctorCore",
                "ViewDoctorDiscovery",
                "ViewDoctorGraph",
                "ViewDoctorRules",
                "ViewDoctorSyntax",
            ]
        ),
        .testTarget(
            name: "ViewDoctorTests",
            dependencies: [
                "ViewDoctorCore",
                "ViewDoctorDiscovery",
                "ViewDoctorGraph",
                "ViewDoctorRules",
                "ViewDoctorSyntax",
            ]
        ),
    ]
)
