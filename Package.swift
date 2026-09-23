// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameLab",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FrameLabCore",
            targets: ["FrameLabCore"]
        ),
        .executable(
            name: "FrameLabMac",
            targets: ["FrameLabMac"]
        ),
        .executable(
            name: "FrameLabTests",
            targets: ["FrameLabTests"]
        )
    ],
    targets: [
        .target(
            name: "FrameLabC",
            path: "C/FrameLabC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "FrameLabObjC",
            dependencies: ["FrameLabC"],
            path: "ObjectiveC/FrameLabObjC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "FrameLabCore",
            dependencies: ["FrameLabC", "FrameLabObjC"],
            path: "Packages/FrameLabCore/Sources/FrameLabCore"
        ),
        .executableTarget(
            name: "FrameLabMac",
            dependencies: ["FrameLabCore"],
            path: "Apps/FrameLabMac"
        ),
        .executableTarget(
            name: "FrameLabTests",
            dependencies: ["FrameLabCore"],
            path: "Tests/FrameLabTestsRunner"
        )
    ]
)
