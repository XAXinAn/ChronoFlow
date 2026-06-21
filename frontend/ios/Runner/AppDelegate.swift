import Flutter
import UIKit
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
  }
}
