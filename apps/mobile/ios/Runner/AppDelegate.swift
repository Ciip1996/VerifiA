import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let messenger = engineBridge.applicationRegistrar.messenger()
        BiometricsChannel.register(with: messenger)
        LivenessChannel.register(with: messenger)
        FaceTecChannel.register(with: messenger)
        if #available(iOS 14.0, *) {
            AppAttestChannel.register(with: messenger)
        }
        PasskeyChannel.register(with: messenger)
    }
}
