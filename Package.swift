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
      checksum: "a5b044938a738f1be68b796a6246a1f951a2851b0fa2bbd76ec4d207e1ad4bda"),
    .binaryTarget(
      name: "MLKitBarcodeScanning",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitBarcodeScanning.xcframework.zip",
      checksum: "35128bce90ae855cecc48847f2b0f60d80464191f17841f0973b90f954ccb951"),
    .binaryTarget(
      name: "MLKitCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitCommon.xcframework.zip",
      checksum: "3fc2e551136519c872af87d6bf983d22c36c851f101d4291534e839e9c067018"),
    .binaryTarget(
      name: "MLKitFaceDetection",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitFaceDetection.xcframework.zip",
      checksum: "f88a7f79e685b09b84f8b37edba2e2dfcd8dc8495e3205109ad5aa7fba851327"),
    .binaryTarget(
      name: "MLKitVision",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitVision.xcframework.zip",
      checksum: "9044e3795620d261099d4354e2f3bafc83e39f2feef375616a953c2cccc06811"),
    .binaryTarget(
      name: "GoogleToolboxForMac",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/GoogleToolboxForMac.xcframework.zip",
      checksum: "b6de63a43319fe6c506a7d41f125be784a5229254ceb69073d424ca21953f9fd"),
    .binaryTarget(
      name: "GoogleUtilitiesComponents",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/GoogleUtilitiesComponents.xcframework.zip",
      checksum: "4ca514c93ef7a45d5add64159221d8828a3222e131b38a0a64a9b08c1e8a5f97"),
    .binaryTarget(
      name: "MLKitObjectDetection",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetection.xcframework.zip",
      checksum: "cce63b799e6fea39ba6bfe28404e1606ba9b048e37158254b1247bb2ad57f415"),
    .binaryTarget(
      name: "MLKitObjectDetectionCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetectionCommon.xcframework.zip",
      checksum: "cf9baaa94ce274a85b135456eed192388547442487f6627591ba4d3b70ba719e"),
    .binaryTarget(
      name: "MLKitObjectDetectionCustom",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitObjectDetectionCustom.xcframework.zip",
      checksum: "42643f3106650af2f88a56a258f75c49bcd5f459f8e7da8c0df120bdbb485177"),
    .binaryTarget(
      name: "MLKitTextRecognitionCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitTextRecognitionCommon.xcframework.zip",
      checksum: "b9629c55b37fc0cb0a9b9e89a534e0fcc623c4531bd2fbc0feec0ee63c078ae5"),
    .binaryTarget(
      name: "MLKitTextRecognitionJapanese",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitTextRecognitionJapanese.xcframework.zip",
      checksum: "3df8358aaadfeaf140a577631c6772e03f1e492914157b896b6a7876ab3221c6"),
    .binaryTarget(
      name: "MLKitImageLabelingCommon",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitImageLabelingCommon.xcframework.zip",
      checksum: "97fd5e4025423487049a0c719ec518cf12f4beeaa258991ac24c336865862ecc"),
    .binaryTarget(
      name: "MLKitVisionKit",
      url: "https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/v6.0.0/MLKitVisionKit.xcframework.zip",
      checksum: "ddb8e13824880a2ad291289cef6ec7bfe862c5c95987f9f9162530f871410d85"),
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
