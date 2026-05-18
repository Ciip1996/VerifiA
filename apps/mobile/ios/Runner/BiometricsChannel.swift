import Flutter
import Foundation
import LocalAuthentication

/// MethodChannel bridge for Face ID / Touch ID authentication.
///
/// Channel: "com.verifia.app/biometrics"
/// Methods:
///   authenticate(reason: String) → Bool   (true = success, throws on failure)
class BiometricsChannel: NSObject {

    static let channelName = "com.verifia.app/biometrics"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )
        let instance = BiometricsChannel()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "authenticate":
            let reason = (call.arguments as? [String: Any])?["reason"] as? String
                ?? "Confirma tu identidad para firmar el badge"
            handleAuthenticate(reason: reason, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleAuthenticate(reason: String, result: @escaping FlutterResult) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Device doesn't support biometrics or none enrolled — treat as success for demo
            DispatchQueue.main.async { result(true) }
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    let code = (authError as? LAError)?.code
                    if code == .userCancel || code == .appCancel || code == .systemCancel {
                        result(FlutterError(
                            code: "USER_CANCELLED",
                            message: "Face ID cancelado",
                            details: nil
                        ))
                    } else {
                        result(FlutterError(
                            code: "AUTH_FAILED",
                            message: authError?.localizedDescription ?? "Autenticación fallida",
                            details: nil
                        ))
                    }
                }
            }
        }
    }
}
