source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'

install! 'cocoapods', integrate_targets: false

target 'MLKit' do
  use_frameworks!
  pod 'GoogleMLKit/BarcodeScanning', '~> 6.0.0'
  pod 'GoogleMLKit/FaceDetection', '~> 6.0.0'
  pod 'GoogleMLKit/ObjectDetection', '~> 6.0.0'
  pod 'GoogleMLKit/ObjectDetectionCustom', '~> 6.0.0'
  pod 'GoogleMLKit/TextRecognitionJapanese', '~> 6.0.0'
end

# Workaround for Xcode 14 beta
# post_install do |installer|
#   installer.pods_project.targets.each do |target|
#     if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
#       target.build_configurations.each do |config|
#           config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
#       end
#     end
#   end
# end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete('ARCHS')
    end
  end
end
