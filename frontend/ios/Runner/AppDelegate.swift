import Flutter
import UIKit
import ImageIO
import AliyunFaceAuthFacade

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Aliyun Face Auth SDK at app launch
    AliyunFaceAuthFacade.initSDK()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Standard plugins
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Custom face verification plugin
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "com.chronoflow/face_verify")
    FaceVerifyPlugin.register(with: registrar!)

    // Image utility: convert HEIC -> JPEG so ML Kit can read iOS photos
    let imgRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "com.chronoflow/image_util")
    let imgChannel = FlutterMethodChannel(
      name: "com.chronoflow/image_util",
      binaryMessenger: imgRegistrar!.messenger()
    )
    imgChannel.setMethodCallHandler { call, result in
      guard call.method == "toJpeg",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      // Decode off the main thread.
      // IMPORTANT: on failure we return "" (NOT the original path) so Dart skips the
      // image instead of feeding an unreadable HEIC to ML Kit, which throws a native
      // MLKInvalidImage NSException ("Input image must not be nil.") and crashes the app.
      DispatchQueue.global(qos: .userInitiated).async {
        let outPath = Self.normalizeToJpeg(srcPath: path)
        DispatchQueue.main.async { result(outPath ?? "") }
      }
    }
  }

  /// Decode any source image (incl. 10-bit HDR HEIC from iPhone Pro) and re-encode
  /// as a baseline 8-bit JPEG that ML Kit / CGImageSource can read.
  /// Returns the new file path, or nil if the image truly cannot be decoded.
  private static func normalizeToJpeg(srcPath: String) -> String? {
    let url = URL(fileURLWithPath: srcPath)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    // Force-redraw into a standard 8-bit sRGB context. This strips 10-bit / wide-gamut /
    // unusual pixel layouts that CGImageSource and ML Kit choke on.
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
    guard let ctx = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      return nil
    }

    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let redrawn = ctx.makeImage() else { return nil }

    let uiImage = UIImage(cgImage: redrawn)
    guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else { return nil }

    let outPath = (NSTemporaryDirectory() as NSString)
      .appendingPathComponent("ocr_\(UUID().uuidString).jpg")
    do {
      try jpegData.write(to: URL(fileURLWithPath: outPath))
      return outPath
    } catch {
      return nil
    }
  }
}
