// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "phoneframes",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/tetratorus/lightpinky.git",
             revision: "8dceaccee80c1370f26b36aaec3e97b394d0b9eb"),
  ],
  targets: [
    .executableTarget(
      name: "phoneframes",
      dependencies: [.product(name: "LightpinkyCore", package: "lightpinky")]
    ),
    .testTarget(name: "phoneframesTests", dependencies: ["phoneframes"]),
  ]
)
