// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "GoogleMLKitSwiftPM",
  platforms: [.iOS(.v15)],
  products: [
    .library(
      name: "MLKitBarcodeScanning",
      targets: ["MLKitBarcodeScanning", "MLImage", "MLKitVision", "Common"]),
    .library(
      name: "MLKitFaceDetection",
      targets: ["MLKitFaceDetection", "MLImage", "MLKitVision", "Common"]),
    .library(
      name: "MLKitObjectDetection",
      targets: ["MLKitObjectDetection", "MLKitObjectDetectionCommon", "MLKitImageLabelingCommon", "MLImage", "MLKitVision", "Common"]),
    .library(
      name: "MLKitObjectDetectionCustom",
      targets: ["MLKitObjectDetectionCustom", "MLKitObjectDetectionCommon", "MLKitImageLabelingCommon", "MLImage", "MLKitVision", "Common"]),
    .library(
      name: "MLKitTextRecognitionJapanese",
      targets: ["MLKitTextRecognitionJapanese", "MLKitTextRecognitionCommon", "MLImage", "MLKitVision", "MLKitVisionKit", "Common"]),
    .library(
      name: "MLKitCommon",
      targets: ["MLKitCommon", "GoogleToolboxForMac", "GoogleUtilitiesComponents"]),
  ],
  dependencies: [
    .package(url: "https://github.com/google/promises.git", exact: "2.4.0"),
    .package(url: "https://github.com/google/GoogleDataTransport.git", exact: "9.4.0"),
    .package(url: "https://github.com/google/GoogleUtilities.git", exact: "7.13.2"),
    .package(url: "https://github.com/google/gtm-session-fetcher.git", exact: "3.4.1"),
    .package(url: "https://github.com/firebase/nanopb.git", exact: "2.30910.0"),
  ],
  targets: [
    .binaryTarget(
      name: "MLImage",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLImage.xcframework.zip",
      checksum: "ba2bd6c83ea242d202629f712df8b28dcfab05247fe141c5e72fba1cd45bdab3"),
    .binaryTarget(
      name: "MLKitBarcodeScanning",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitBarcodeScanning.xcframework.zip",
      checksum: "fce1aeab0b73bccf625bae9f11417f24c5873590581027a1b34594e30468e39c"),
    .binaryTarget(
      name: "MLKitCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitCommon.xcframework.zip",
      checksum: "2311f378725ecd8cdbb2b5f574cd314eb9f7a80b1dd882433853ea413fd630dc"),
    .binaryTarget(
      name: "MLKitFaceDetection",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitFaceDetection.xcframework.zip",
      checksum: "44f1b78489dfd82d09c9356c6dc90dc538b62795892a01820c38dde90bb28f83"),
    .binaryTarget(
      name: "MLKitVision",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitVision.xcframework.zip",
      checksum: "4d1a4a98f39742bceb58557a75e36ee50df1fe2b48f3690e5c692a8dbd2e9ad5"),
    .binaryTarget(
      name: "GoogleToolboxForMac",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/GoogleToolboxForMac.xcframework.zip",
      checksum: "c3a5ae7592d943c15747e60d9472e51052108497e7135517d5a149ff66324607"),
    .binaryTarget(
      name: "GoogleUtilitiesComponents",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/GoogleUtilitiesComponents.xcframework.zip",
      checksum: "0cf6024fb98ea5cd4248e36f2fbed8a49ad58fec06dcd938efa30ea21a160421"),
    .binaryTarget(
      name: "MLKitObjectDetection",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetection.xcframework.zip",
      checksum: "ed739d045298226d865baeee31c3503426c834c0b97ddf592d0658f3297f81f6"),
    .binaryTarget(
      name: "MLKitObjectDetectionCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetectionCommon.xcframework.zip",
      checksum: "e83220c875b1ac915f5a73dffe2a1f5bf10315ec899cea53664f65f5f2c84cda"),
    .binaryTarget(
      name: "MLKitObjectDetectionCustom",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetectionCustom.xcframework.zip",
      checksum: "1cf48ca2921c82de2ad89dbfc8afedb949974ef9aa52a672022617faff57c7a5"),
    .binaryTarget(
      name: "MLKitTextRecognitionCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitTextRecognitionCommon.xcframework.zip",
      checksum: "7d33c220771d972e006e4d61eddaa6bffca10a647ff5fdcce97944e1c23c39fd"),
    .binaryTarget(
      name: "MLKitTextRecognitionJapanese",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitTextRecognitionJapanese.xcframework.zip",
      checksum: "735fc517fd351ba6c12c745c46d4c813058d3c9b8e5641795b6a244a1015f153"),
    .binaryTarget(
      name: "MLKitImageLabelingCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitImageLabelingCommon.xcframework.zip",
      checksum: "e67bc2c28228ea5130ef69d8c014f0b9ac3e18270d42b1fcd7d5497b043bb805"),
    .binaryTarget(
      name: "MLKitVisionKit",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitVisionKit.xcframework.zip",
      checksum: "8fba5dea0c34c465a923a74ba2579e0f5ad25c0eb3779abbd12fe4c96384839e"),
    .target(
      name: "Common",
      dependencies: [
        "MLKitCommon",
        "GoogleToolboxForMac",
        "GoogleUtilitiesComponents",
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULISASwizzler", package: "GoogleUtilities"),
        .product(name: "GULLogger", package: "GoogleUtilities"),
        .product(name: "GULMethodSwizzler", package: "GoogleUtilities"),
        .product(name: "GULNSData", package: "GoogleUtilities"),
        .product(name: "GULNetwork", package: "GoogleUtilities"),
        .product(name: "GULReachability", package: "GoogleUtilities"),
        .product(name: "GULUserDefaults", package: "GoogleUtilities"),
        .product(name: "GTMSessionFetcher", package: "gtm-session-fetcher"),
        .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
        .product(name: "nanopb", package: "nanopb"),
        .product(name: "FBLPromises", package: "promises"),
      ],
      path: "Sources/Common"),
  ]
)
