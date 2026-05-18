import Flutter
import Foundation
import DeviceCheck
import CryptoKit

/// MethodChannel bridge for Apple App Attest (DCAppAttestService).
///
/// Channel name: "com.verifia.app/app_attest"
///
/// Methods exposed to Flutter/Dart:
///   - generateKey()       → String (keyId)
///   - attestKey(keyId, challenge) → String (base64url attestation object)
///   - generateAssertion(keyId, challenge) → String (base64url assertion)
///   - isSupported()       → Bool
///
/// Integration in AppDelegate.swift:
///   AppAttestChannel.register(with: registrar)
///
/// References:
///   https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity
@available(iOS 14.0, *)
class AppAttestChannel: NSObject {

    static let channelName = "com.verifia.app/app_attest"

    static func register(with registrar: FlutterPluginRegistrar) {
        register(with: registrar.messenger())
    }

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )
        let instance = AppAttestChannel()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            handleIsSupported(result: result)
        case "generateKey":
            handleGenerateKey(result: result)
        case "attestKey":
            handleAttestKey(call: call, result: result)
        case "generateAssertion":
            handleGenerateAssertion(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - isSupported

    private func handleIsSupported(result: @escaping FlutterResult) {
        result(DCAppAttestService.shared.isSupported)
    }

    // MARK: - generateKey

    /// Generates a new App Attest key pair in the Secure Enclave.
    /// Returns the key identifier (SHA256 of the public key, base64url encoded).
    private func handleGenerateKey(result: @escaping FlutterResult) {
        guard DCAppAttestService.shared.isSupported else {
            result(FlutterError(
                code: "ATTEST_NOT_SUPPORTED",
                message: "App Attest not supported on this device (simulator?)",
                details: nil
            ))
            return
        }

        DCAppAttestService.shared.generateKey { keyId, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "GENERATE_KEY_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                result(keyId)
            }
        }
    }

    // MARK: - attestKey

    /// Attests the key with Apple's servers.
    ///
    /// Args: { "key_id": String, "challenge": String (hex) }
    /// Returns: base64url-encoded CBOR attestation object
    ///
    /// The challenge must be SHA256-hashed before passing to attestKey.
    /// Per Apple docs: clientDataHash = SHA256(challenge_data)
    private func handleAttestKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyId = args["key_id"] as? String,
              let challengeHex = args["challenge"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing key_id or challenge", details: nil))
            return
        }

        // Convert hex nonce to Data and hash it
        guard let challengeData = Data(hexString: challengeHex) else {
            result(FlutterError(code: "INVALID_CHALLENGE", message: "challenge must be a valid hex string", details: nil))
            return
        }
        let clientDataHash = Data(SHA256.hash(data: challengeData))

        DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "ATTEST_KEY_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                guard let attestation = attestation else {
                    result(FlutterError(code: "ATTEST_NIL", message: "Attestation object was nil", details: nil))
                    return
                }
                result(attestation.base64URLEncodedString())
            }
        }
    }

    // MARK: - generateAssertion

    /// Generates a per-request assertion proving this is the same key.
    ///
    /// Args: { "key_id": String, "challenge": String (hex) }
    /// Returns: base64url-encoded CBOR assertion
    ///
    /// Called on every token issuance request for replay protection.
    private func handleGenerateAssertion(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyId = args["key_id"] as? String,
              let challengeHex = args["challenge"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing key_id or challenge", details: nil))
            return
        }

        guard let challengeData = Data(hexString: challengeHex) else {
            result(FlutterError(code: "INVALID_CHALLENGE", message: "challenge must be a valid hex string", details: nil))
            return
        }
        let clientDataHash = Data(SHA256.hash(data: challengeData))

        DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "ASSERTION_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                guard let assertion = assertion else {
                    result(FlutterError(code: "ASSERTION_NIL", message: "Assertion was nil", details: nil))
                    return
                }
                result(assertion.base64URLEncodedString())
            }
        }
    }
}

// MARK: - Data extensions

private extension Data {
    /// Initialize from hex string (e.g. "a3f8c2...")
    init?(hexString: String) {
        let hex = hexString.lowercased()
        guard hex.count % 2 == 0 else { return nil }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }

    /// Base64URL encoding (no padding, URL-safe alphabet)
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
