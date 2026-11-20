// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "phoneframes",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/tetratorus/lightpinky.git",
             revision: "560742ba03cea5d6e4b8e416152acb4c585a9f46"),
  ],
  targets: [
    .executableTarget(
      name: "phoneframes",
      dependencies: [.product(name: "LightpinkyCore", package: "lightpinky")]
    ),
    .testTarget(name: "phoneframesTests", dependencies: ["phoneframes"]),
  ]
)
