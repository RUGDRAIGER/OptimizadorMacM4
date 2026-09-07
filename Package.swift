// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OptimizadorMacM4",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OptimizadorMacM4", targets: ["OptimizadorMacM4"])
    ],
    targets: [
        .executableTarget(
            name: "OptimizadorMacM4",
            path: "OptimizadorMacM4",
            exclude: ["OptimizadorMacM4.entitlements"]
        ),
        .testTarget(
            name: "OptimizadorMacM4Tests",
            dependencies: ["OptimizadorMacM4"],
            path: "OptimizadorMacM4Tests"
        )
    ]
)
