// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bloret",
    platforms: [
        .iOS(.v16),     // 设置最低支持 iOS 16
        .macOS(.v13)    // 设置最低支持 macOS 13 (如果你也想在 Mac 上跑)
    ],
    products: [
        .executable(name: "Bloret", targets: ["Bloret"])
    ],
    targets: [
        .executableTarget(
            name: "Bloret",
            path: ".", // 假设你的 swift 文件都在根目录
            exclude: ["Package.swift"] // 排除配置文件本身
        )
    ]
)
