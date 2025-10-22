// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "skip-qrcode",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkipQRCode", type: .dynamic, targets: ["SkipQRCode"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.27"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "SkipQRCode", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipQRCodeTests", dependencies: [
            "SkipQRCode",
            .product(name: "SkipTest", package: "skip")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
