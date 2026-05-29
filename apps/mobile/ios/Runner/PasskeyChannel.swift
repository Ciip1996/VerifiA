import Flutter
import AuthenticationServices
import Foundation

/// Native MethodChannel for FIDO2 Passkey registration and authentication.
///
/// Channel: com.verifia.app/passkeys
///
/// Methods:
///   isSupported    → Bool
///   register       → Map (credentialId, rawId, clientDataJSON, attestationObject)
///   authenticate   → Map (id, rawId, clientDataJSON, authenticatorData, signature, userHandle?)
///
/// Prerequisites for production use:
///   1. Backend must serve /.well-known/apple-app-site-association with webcredentials
///   2. Xcode → Runner target → Signing & Capabilities → Associated Domains:
///        webcredentials:<your-rp-id>   (e.g. webcredentials:api.verifia.dev or
///                                       webcredentials:<ngrok-subdomain>.ngrok.io)
///   3. PASSKEY_RP_ID in apps/backend/.env must match the Associated Domains entry

class PasskeyChannel: NSObject {

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.verifia.app/passkeys",
            binaryMessenger: messenger
        )
        let instance = PasskeyChannel()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            if #available(iOS 16.0, *) {
                result(true)
            } else {
                result(false)
            }

        case "register":
            guard #available(iOS 16.0, *),
                  let args = call.arguments as? [String: Any],
                  let challenge = args["challenge"] as? String,
                  let userId = args["user_id"] as? String,
                  let rpId = args["rp_id"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "register requires challenge, user_id, rp_id", details: nil))
                return
            }
            handleRegister(challenge: challenge, userId: userId, rpId: rpId, result: result)

        case "authenticate":
            guard #available(iOS 16.0, *),
                  let args = call.arguments as? [String: Any],
                  let challenge = args["challenge"] as? String,
                  let rpId = args["rp_id"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "authenticate requires challenge and rp_id", details: nil))
                return
            }
            let credentialId = args["credential_id"] as? String
            handleAuthenticate(challenge: challenge, rpId: rpId, credentialId: credentialId, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ─── Registration ────────────────────────────────────────────────────────

    @available(iOS 16.0, *)
    private func handleRegister(
        challenge: String,
        userId: String,
        rpId: String,
        result: @escaping FlutterResult
    ) {
        guard let challengeData = Data(base64Encoded: base64urlToBase64(challenge)),
              let userIdData = userId.data(using: .utf8) else {
            result(FlutterError(code: "DECODE_ERROR", message: "Invalid base64url challenge or userId", details: nil))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: userId,
            userID: userIdData
        )

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = PasskeyRegistrationDelegate(result: result)
        // Retain delegate for the duration of the authorization
        objc_setAssociatedObject(controller, &AssocKey.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    // ─── Authentication (assertion) ──────────────────────────────────────────

    @available(iOS 16.0, *)
    private func handleAuthenticate(
        challenge: String,
        rpId: String,
        credentialId: String?,
        result: @escaping FlutterResult
    ) {
        guard let challengeData = Data(base64Encoded: base64urlToBase64(challenge)) else {
            result(FlutterError(code: "DECODE_ERROR", message: "Invalid base64url challenge", details: nil))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)

        if let credId = credentialId,
           let credIdData = Data(base64Encoded: base64urlToBase64(credId)) {
            request.allowedCredentials = [ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credIdData)]
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = PasskeyAssertionDelegate(result: result)
        objc_setAssociatedObject(controller, &AssocKey.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    // ─── Base64url ↔ Base64 ──────────────────────────────────────────────────

    private func base64urlToBase64(_ value: String) -> String {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        return base64
    }
}

// ─── AssociatedObject key storage ────────────────────────────────────────────
private enum AssocKey {
    static var delegateKey: UInt8 = 0
}

// ─── Registration delegate ────────────────────────────────────────────────────

@available(iOS 16.0, *)
private class PasskeyRegistrationDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let result: FlutterResult

    init(result: @escaping FlutterResult) {
        self.result = result
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            result(FlutterError(code: "UNEXPECTED_CRED", message: "Unexpected credential type", details: nil))
            return
        }

        let payload: [String: Any] = [
            "credential_id": cred.credentialID.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            "raw_id": cred.credentialID.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            "client_data_json": cred.rawClientDataJSON.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
            "attestation_object": (cred.rawAttestationObject ?? Data()).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: ""),
        ]
        DispatchQueue.main.async { self.result(payload) }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let asError = error as? ASAuthorizationError
        if asError?.code == .canceled {
            DispatchQueue.main.async {
                self.result(FlutterError(code: "USER_CANCELLED", message: "Passkey registration cancelled", details: nil))
            }
        } else {
            DispatchQueue.main.async {
                self.result(FlutterError(code: "REG_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }
}

// ─── Assertion (authentication) delegate ─────────────────────────────────────

@available(iOS 16.0, *)
private class PasskeyAssertionDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let result: FlutterResult

    init(result: @escaping FlutterResult) {
        self.result = result
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            result(FlutterError(code: "UNEXPECTED_CRED", message: "Unexpected credential type", details: nil))
            return
        }

        func toBase64url(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        var payload: [String: Any] = [
            "id": toBase64url(cred.credentialID),
            "raw_id": toBase64url(cred.credentialID),
            "client_data_json": toBase64url(cred.rawClientDataJSON),
            "authenticator_data": toBase64url(cred.rawAuthenticatorData),
            "signature": toBase64url(cred.signature),
        ]
        if let handle = cred.userID {
            payload["user_handle"] = toBase64url(handle)
        }

        DispatchQueue.main.async { self.result(payload) }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let asError = error as? ASAuthorizationError
        if asError?.code == .canceled {
            DispatchQueue.main.async {
                self.result(FlutterError(code: "USER_CANCELLED", message: "Passkey authentication cancelled", details: nil))
            }
        } else {
            DispatchQueue.main.async {
                self.result(FlutterError(code: "AUTH_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }
}
