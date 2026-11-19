// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "phoneframes",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/tetratorus/lightpinky.git",
             revision: "740baed77058ae3d9bdff6ea6c31359223b59e7e"),
  ],
  targets: [
    .executableTarget(
      name: "phoneframes",
      dependencies: [.product(name: "LightpinkyCore", package: "lightpinky")]
    ),
    .testTarget(name: "phoneframesTests", dependencies: ["phoneframes"]),
  ]
)
