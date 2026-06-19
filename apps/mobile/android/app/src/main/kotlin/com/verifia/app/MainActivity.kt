package com.verifia.app

import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Biometrics channel — real Android BiometricPrompt
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.verifia.app/biometrics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "authenticate" -> {
                        val executor = ContextCompat.getMainExecutor(this)
                        val callback = object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(
                                authResult: BiometricPrompt.AuthenticationResult
                            ) {
                                result.success(true)
                            }

                            override fun onAuthenticationFailed() {
                                result.success(false)
                            }

                            override fun onAuthenticationError(
                                errorCode: Int,
                                errString: CharSequence
                            ) {
                                if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                                    errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON
                                ) {
                                    result.error("USER_CANCELLED", errString.toString(), null)
                                } else {
                                    result.success(false)
                                }
                            }
                        }
                        val biometricPrompt = BiometricPrompt(this, executor, callback)
                        val promptInfo = BiometricPrompt.PromptInfo.Builder()
                            .setTitle("VerifiA")
                            .setSubtitle("Confirma tu identidad")
                            .setNegativeButtonText("Cancelar")
                            .build()
                        biometricPrompt.authenticate(promptInfo)
                    }
                    "playSuccess" -> result.success(true)  // no Taptic Engine on Android
                    else -> result.notImplemented()
                }
            }

        // App Attest channel — no-op (iOS/Apple Secure Enclave only)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.verifia.app/app_attest")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(false)
                    else -> result.notImplemented()
                }
            }

        // Passkeys channel — no-op stub (iOS ASAuthorizationController only)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.verifia.app/passkeys")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(false)
                    "authenticate" -> result.success(mapOf("assertion" to "ANDROID_STUB"))
                    else -> result.notImplemented()
                }
            }

        // FaceTec channel — no-op stub (iOS native SDK only)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "verifia/facetec")
            .setMethodCallHandler { call, result ->
                result.notImplemented()
            }
    }
}
