// swift-tools-version: 6.3
import PackageDescription

let strict: [SwiftSetting] = [
  .enableUpcomingFeature("ApproachableConcurrency"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .strictMemorySafety(),
  .treatAllWarnings(as: .error),
  .treatWarning("StrictLanguageFeatures", as: .error),
]

let package = Package(
  name: "Meth",
  platforms: [.macOS(.v15)],
  targets: [
    .target(
      name: "Core", swiftSettings: strict + [.treatWarning("ExistentialType", as: .error)]),
    .executableTarget(
      name: "Meth", dependencies: ["Core"],
      swiftSettings: strict + [.defaultIsolation(MainActor.self)]),
    .testTarget(name: "CoreTests", dependencies: ["Core"], swiftSettings: strict),
  ],
  swiftLanguageModes: [.v6]
)
