// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ThrottleNet",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "ThrottleNet",
      targets: ["ThrottleNet"]
    ),
    .library(
      name: "ThrottleNetCore",
      targets: ["ThrottleNetCore"]
    ),
    .executable(
      name: "ThrottleNetTestsRunner",
      targets: ["ThrottleNetTestsRunner"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "ThrottleNetCore",
      dependencies: [],
      path: "Sources/ThrottleNetCore"
    ),
    .executableTarget(
      name: "ThrottleNet",
      dependencies: ["ThrottleNetCore"],
      path: "Sources/ThrottleNetApp"
    ),
    .executableTarget(
      name: "ThrottleNetTestsRunner",
      dependencies: ["ThrottleNetCore"],
      path: "Sources/ThrottleNetTestsRunner"
    ),
  ]
)
