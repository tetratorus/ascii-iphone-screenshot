// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "phoneframes",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/tetratorus/lightpinky.git",
             revision: "326efa6209ddb6655a3ea59d4b4ab3bd90106c2f"),
  ],
  targets: [
    .executableTarget(
      name: "phoneframes",
      dependencies: [.product(name: "LightpinkyCore", package: "lightpinky")]
    ),
    .testTarget(name: "phoneframesTests", dependencies: ["phoneframes"]),
  ]
)
