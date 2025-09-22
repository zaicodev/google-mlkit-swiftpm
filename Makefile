PROJECT_ROOT=$(cd $(dirname $0); cd ..; pwd)
PODS_ROOT="./Pods"
PODS_PROJECT="$(PODS_ROOT)/Pods.xcodeproj"
SYMROOT="$(PODS_ROOT)/Build"
IPHONEOS_DEPLOYMENT_TARGET = 15.0

# フレームワーク形式判別とXCFramework作成のヘルパー
define create_xcframework_with_fallback
	@echo "📦 $(1) XCFramework作成中..."; \
	framework_path="$(2)"; \
	if [ -f "$$framework_path/$(1)" ]; then \
		if file "$$framework_path/$(1)" | grep -q "ar archive"; then \
			xcframework-maker/.build/release/make-xcframework \
				-ios "$$framework_path" \
				-output XCFrameworks >/dev/null 2>&1; \
		else \
			xcframework-maker/.build/release/make-xcframework \
				-ios "$$framework_path" \
				-arm64sim \
				-output XCFrameworks >/dev/null 2>&1; \
		fi; \
	fi
endef

bootstrap-cocoapods:
	@echo "🔄 CocoaPods依存関係をインストール中..."
	@pod install --silent 2>&1 | grep -v "^/" | grep -v "^[[:space:]]*$$" || true

bootstrap-builder:
	@cd xcframework-maker && swift build -c release

build-cocoapods: bootstrap-cocoapods
	@echo "🔨 iOS用フレームワークをビルド中..."
	@xcodebuild -project "$(PODS_PROJECT)" \
	-sdk iphoneos \
	-configuration Release -alltargets \
	-quiet \
  ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
  CLANG_ENABLE_MODULE_DEBUGGING=NO \
  DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING=YES \
	IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" 2>&1 | grep -E '(error:|\*\* BUILD)' || true
	@echo "🔨 シミュレータ用フレームワークをビルド中..."
	@xcodebuild -project "$(PODS_PROJECT)" \
	-sdk iphonesimulator \
	-configuration Release -alltargets \
	-quiet \
  ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
  CLANG_ENABLE_MODULE_DEBUGGING=NO \
  DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING=YES \
  VALID_ARCHS="x86_64 arm64" ARCHS="x86_64 arm64" \
  EXCLUDED_ARCHS="" \
	IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" 2>&1 | grep -E '(error:|\*\* BUILD)' || true

# copy-resource-bundle:
# 	@cp -rf "./Pods/Pods/Build/Release-iphoneos/MLKitFaceDetection/GoogleMVFaceDetectorResources.bundle" "./Sources/FaceDetection/GoogleMVFaceDetectorResources.bundle"
prepare-info-plist:
	@cp -rf "./Resources/MLKitCommon-Info.plist" "./Pods/MLKitCommon/Frameworks/MLKitCommon.framework/Info.plist"
	@cp -rf "./Resources/MLKitBarcodeScanning-Info.plist" "./Pods/MLKitBarcodeScanning/Frameworks/MLKitBarcodeScanning.framework/Info.plist"
	@cp -rf "./Resources/MLKitFaceDetection-Info.plist" "./Pods/MLKitFaceDetection/Frameworks/MLKitFaceDetection.framework/Info.plist"
	@cp -rf "./Resources/MLKitVision-Info.plist" "./Pods/MLKitVision/Frameworks/MLKitVision.framework/Info.plist"
	@cp -rf "./Resources/MLImage-Info.plist" "./Pods/MLImage/Frameworks/MLImage.framework/Info.plist"
	@cp -rf "./Resources/MLKitObjectDetection-Info.plist" "./Pods/MLKitObjectDetection/Frameworks/MLKitObjectDetection.framework/Info.plist"
	@cp -rf "./Resources/MLKitObjectDetectionCommon-Info.plist" "./Pods/MLKitObjectDetectionCommon/Frameworks/MLKitObjectDetectionCommon.framework/Info.plist"
	@cp -rf "./Resources/MLKitObjectDetectionCustom-Info.plist" "./Pods/MLKitObjectDetectionCustom/Frameworks/MLKitObjectDetectionCustom.framework/Info.plist"
	@cp -rf "./Resources/MLKitTextRecognitionCommon-Info.plist" "./Pods/MLKitTextRecognitionCommon/Frameworks/MLKitTextRecognitionCommon.framework/Info.plist"
	@cp -rf "./Resources/MLKitTextRecognitionJapanese-Info.plist" "./Pods/MLKitTextRecognitionJapanese/Frameworks/MLKitTextRecognitionJapanese.framework/Info.plist"
	@cp -rf "./Resources/MLKitImageLabelingCommon-Info.plist" "./Pods/MLKitImageLabelingCommon/Frameworks/MLKitImageLabelingCommon.framework/Info.plist"
	@cp -rf "./Resources/MLKitVisionKit-Info.plist" "./Pods/MLKitVisionKit/Frameworks/MLKitVisionKit.framework/Info.plist"
create-xcframework: bootstrap-builder build-cocoapods prepare-info-plist
	@echo "🧹 既存のXCFrameworksをクリーンアップ中..."
	@rm -rf XCFrameworks
	@mkdir -p XCFrameworks
	@rm -rf GoogleMLKit
	@xcodebuild -create-xcframework \
		-framework Pods/Pods/Build/Release-iphonesimulator/GoogleToolboxForMac/GoogleToolboxForMac.framework \
		-framework Pods/Pods/Build/Release-iphoneos/GoogleToolboxForMac/GoogleToolboxForMac.framework \
		-output XCFrameworks/GoogleToolboxForMac.xcframework
	@xcodebuild -create-xcframework \
		-framework Pods/Pods/Build/Release-iphonesimulator/GoogleUtilitiesComponents/GoogleUtilitiesComponents.framework \
		-framework Pods/Pods/Build/Release-iphoneos/GoogleUtilitiesComponents/GoogleUtilitiesComponents.framework \
		-output XCFrameworks/GoogleUtilitiesComponents.xcframework
	# MLKitフレームワーク（静的/動的自動判別）
	$(call create_xcframework_with_fallback,MLImage,./Pods/MLImage/Frameworks/MLImage.framework)
	$(call create_xcframework_with_fallback,MLKitCommon,./Pods/MLKitCommon/Frameworks/MLKitCommon.framework)
	$(call create_xcframework_with_fallback,MLKitVision,./Pods/MLKitVision/Frameworks/MLKitVision.framework)
	$(call create_xcframework_with_fallback,MLKitObjectDetection,./Pods/MLKitObjectDetection/Frameworks/MLKitObjectDetection.framework)
	$(call create_xcframework_with_fallback,MLKitObjectDetectionCommon,./Pods/MLKitObjectDetectionCommon/Frameworks/MLKitObjectDetectionCommon.framework)
	$(call create_xcframework_with_fallback,MLKitObjectDetectionCustom,./Pods/MLKitObjectDetectionCustom/Frameworks/MLKitObjectDetectionCustom.framework)
	$(call create_xcframework_with_fallback,MLKitTextRecognitionJapanese,./Pods/MLKitTextRecognitionJapanese/Frameworks/MLKitTextRecognitionJapanese.framework)
	$(call create_xcframework_with_fallback,MLKitImageLabelingCommon,./Pods/MLKitImageLabelingCommon/Frameworks/MLKitImageLabelingCommon.framework)
	$(call create_xcframework_with_fallback,MLKitBarcodeScanning,./Pods/MLKitBarcodeScanning/Frameworks/MLKitBarcodeScanning.framework)
	$(call create_xcframework_with_fallback,MLKitFaceDetection,./Pods/MLKitFaceDetection/Frameworks/MLKitFaceDetection.framework)
	$(call create_xcframework_with_fallback,MLKitTextRecognitionCommon,./Pods/MLKitTextRecognitionCommon/Frameworks/MLKitTextRecognitionCommon.framework)
	$(call create_xcframework_with_fallback,MLKitVisionKit,./Pods/MLKitVisionKit/Frameworks/MLKitVisionKit.framework)
	@echo "📋 リソースバンドルをコピー中..."
	# MLKitTextRecognitionJapanese - JapaneseOCRResources (.bundle形式で直下に配置)
	@if [ -d "Pods/MLKitTextRecognitionJapanese/Resources/JapaneseOCRResources" ]; then \
		echo "  → JapaneseOCRResources.bundle を MLKitTextRecognitionJapanese.xcframework 直下にコピー"; \
		cp -R "Pods/MLKitTextRecognitionJapanese/Resources/JapaneseOCRResources" "XCFrameworks/MLKitTextRecognitionJapanese.xcframework/ios-arm64/MLKitTextRecognitionJapanese.framework/JapaneseOCRResources.bundle" 2>/dev/null || true; \
		cp -R "Pods/MLKitTextRecognitionJapanese/Resources/JapaneseOCRResources" "XCFrameworks/MLKitTextRecognitionJapanese.xcframework/ios-x86_64-simulator/MLKitTextRecognitionJapanese.framework/JapaneseOCRResources.bundle" 2>/dev/null || true; \
	fi
	# MLKitFaceDetection - GoogleMVFaceDetectorResources (通常はFramework内に既に存在)
	@if [ -d "Pods/MLKitFaceDetection/Resources/GoogleMVFaceDetectorResources" ] && [ ! -d "XCFrameworks/MLKitFaceDetection.xcframework/ios-arm64/MLKitFaceDetection.framework/GoogleMVFaceDetectorResources.bundle" ]; then \
		echo "  → GoogleMVFaceDetectorResources を MLKitFaceDetection.xcframework にコピー"; \
		cp -R "Pods/MLKitFaceDetection/Resources/GoogleMVFaceDetectorResources" "XCFrameworks/MLKitFaceDetection.xcframework/ios-arm64/MLKitFaceDetection.framework/" 2>/dev/null || true; \
		cp -R "Pods/MLKitFaceDetection/Resources/GoogleMVFaceDetectorResources" "XCFrameworks/MLKitFaceDetection.xcframework/ios-arm64_x86_64-simulator/MLKitFaceDetection.framework/" 2>/dev/null || true; \
	fi
	# MLKitObjectDetection - MLKitObjectDetectionResources (通常はFramework内に既に存在)
	@if [ -d "Pods/MLKitObjectDetection/Resources/MLKitObjectDetectionResources" ] && [ ! -d "XCFrameworks/MLKitObjectDetection.xcframework/ios-arm64/MLKitObjectDetection.framework/MLKitObjectDetectionResources.bundle" ]; then \
		echo "  → MLKitObjectDetectionResources を MLKitObjectDetection.xcframework にコピー"; \
		cp -R "Pods/MLKitObjectDetection/Resources/MLKitObjectDetectionResources" "XCFrameworks/MLKitObjectDetection.xcframework/ios-arm64/MLKitObjectDetection.framework/" 2>/dev/null || true; \
		cp -R "Pods/MLKitObjectDetection/Resources/MLKitObjectDetectionResources" "XCFrameworks/MLKitObjectDetection.xcframework/ios-x86_64-simulator/MLKitObjectDetection.framework/" 2>/dev/null || true; \
	fi
	@echo "✅ XCFrameworks created successfully"

archive:
	@echo "📦 Creating zip archives for distribution..."
	@cd ./XCFrameworks \
	 && zip -qr MLKitBarcodeScanning.xcframework.zip MLKitBarcodeScanning.xcframework \
	 && zip -qr MLKitFaceDetection.xcframework.zip MLKitFaceDetection.xcframework \
	 && zip -qr GoogleToolboxForMac.xcframework.zip GoogleToolboxForMac.xcframework \
	 && zip -qr GoogleUtilitiesComponents.xcframework.zip GoogleUtilitiesComponents.xcframework \
	 && zip -qr MLImage.xcframework.zip MLImage.xcframework \
	 && zip -qr MLKitCommon.xcframework.zip MLKitCommon.xcframework \
	 && zip -qr MLKitVision.xcframework.zip MLKitVision.xcframework \
	 && zip -qr MLKitObjectDetection.xcframework.zip MLKitObjectDetection.xcframework \
	 && zip -qr MLKitObjectDetectionCommon.xcframework.zip MLKitObjectDetectionCommon.xcframework \
	 && zip -qr MLKitObjectDetectionCustom.xcframework.zip MLKitObjectDetectionCustom.xcframework \
	 && zip -qr MLKitTextRecognitionCommon.xcframework.zip MLKitTextRecognitionCommon.xcframework \
	 && zip -qr MLKitTextRecognitionJapanese.xcframework.zip MLKitTextRecognitionJapanese.xcframework \
	 && zip -qr MLKitImageLabelingCommon.xcframework.zip MLKitImageLabelingCommon.xcframework \
	 && zip -qr MLKitVisionKit.xcframework.zip MLKitVisionKit.xcframework
	@echo "✅ Archive creation completed"

.PHONY:
run: bootstrap-cocoapods build-cocoapods create-xcframework
	@echo "✅ XCFrameworks created successfully"
