# Patches mobile_scanner iOS sources for Xcode 26 / iOS 15+ (run from Podfile post_install).
def patch_mobile_scanner_sources!
  candidates = [
    File.expand_path('.symlinks/plugins/mobile_scanner/darwin/mobile_scanner/Sources/mobile_scanner', __dir__),
    Dir.glob(File.expand_path('~/.pub-cache/hosted/pub.dev/mobile_scanner-*/darwin/mobile_scanner/Sources/mobile_scanner')).max,
  ].compact

  root = candidates.find { |path| File.directory?(path) }
  return unless root

  patch_barcode_type_detector(File.join(root, 'BarcodeTypeDetector.swift'))
  patch_camera_selector(File.join(root, 'MobileScannerCameraSelector.swift'))
  patch_plugin(File.join(root, 'MobileScannerPlugin.swift'))
end

def patch_barcode_type_detector(path)
  return unless File.exist?(path)

  content = File.read(path)
  return unless content.include?('do {')

  updated = content.sub(
    "    func detectBarcodeType() -> Int {\n        do {\n            let trimmed",
    "    func detectBarcodeType() -> Int {\n            let trimmed"
  ).sub(
    "            return 7 // BarcodeType.text\n        } catch {\n            return 0 // BarcodeType.unknown\n        }\n    }",
    "            return 7 // BarcodeType.text\n    }"
  )

  File.write(path, updated) if updated != content
end

def patch_camera_selector(path)
  return unless File.exist?(path)

  content = File.read(path)
  return unless content.include?('AVCaptureDevice.devices(for:')

  updated = content.gsub(
    %r{
        \n        // Only use legacy fallbacks for non-specific lens requests
        \n        if isSpecificLensRequest \{
        \n            return nil
        \n        \}
        \n
        \n        // Legacy fallback for older OS versions: filter by position
        \n        if let device = AVCaptureDevice\.devices\(for: \.video\)\.filter\(\{ \$0\.position == position \}\)\.first \{
        \n            return device
        \n        \}
        \n
        \n        // Ultimate fallback: any available video device
    }x,
    "\n        // Ultimate fallback: any available video device (iOS 15+ minimum)"
  )
  File.write(path, updated) if updated != content
end

def patch_plugin(path)
  return unless File.exist?(path)

  content = File.read(path)
  updated = content.gsub(
    'if let zoomScale = change?[.newKey] as? CGFloat,
               let device = object as? AVCaptureDevice {',
    'if let zoomScale = change?[.newKey] as? CGFloat,
               object is AVCaptureDevice {'
  )

  File.write(path, updated) if updated != content
end
