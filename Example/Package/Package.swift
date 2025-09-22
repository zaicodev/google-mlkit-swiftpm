// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Example",
  platforms: [.iOS(.v15)],
  products: [
    .library(
      name: "Camera",
      targets: ["Camera"])
  ],
  dependencies: [
    .package(path: "../../"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
  ],
  targets: [
    .target(
      name: "Camera",
      dependencies: [
        .product(name: "MLKitBarcodeScanning", package: "GoogleMLKitSwiftPM"),
        .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
      ]),
    .testTarget(
      name: "CameraTests",
      dependencies: ["Camera"]),
  ]
)
