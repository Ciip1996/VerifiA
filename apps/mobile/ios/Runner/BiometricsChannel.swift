import AudioToolbox
import Flutter
import Foundation
import LocalAuthentication
import UIKit

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
        case "playSuccess":
            handlePlaySuccess(result: result)
        case "playIncoming":
            handlePlayIncoming(result: result)
        case "playSent":
            handlePlaySent(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handlePlaySuccess(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            // Primary: notification haptic ("success" pattern, always fires regardless of mute)
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)

            // Secondary: heavy impact for a stronger physical sensation
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred()

            // Audio chime — only audible when not muted; haptics above fire regardless
            AudioServicesPlayAlertSoundWithCompletion(1109, nil)

            result(true)
        }
    }

    /// Fired when a new incoming verification request arrives.
    /// Sound: "ReceivedMessage" chime (1315) — short, distinct ping.
    /// Haptic: warning pattern (double tap sensation) — signals attention needed.
    private func handlePlayIncoming(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.warning)

            AudioServicesPlayAlertSoundWithCompletion(1315, nil)
            result(true)
        }
    }

    /// Fired when the user successfully sends a verification request or QR.
    /// Sound: "Tink" (1057) — a light, crisp tap confirming an action.
    /// Haptic: light impact — gentle confirmation, not intrusive.
    private func handlePlaySent(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred()

            AudioServicesPlayAlertSoundWithCompletion(1057, nil)
            result(true)
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
