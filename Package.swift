// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "phoneframes",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/tetratorus/lightpinky.git",
             revision: "81e1e1cce5fd5b14939072b965d7bb6ac26d18e6"),
  ],
  targets: [
    .executableTarget(
      name: "phoneframes",
      dependencies: [.product(name: "LightpinkyCore", package: "lightpinky")]
    ),
    .testTarget(name: "phoneframesTests", dependencies: ["phoneframes"]),
  ]
)
