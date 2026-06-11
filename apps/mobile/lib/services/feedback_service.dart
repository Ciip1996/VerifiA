import 'package:flutter/services.dart';

/// Thin wrapper around the BiometricsChannel to play contextual sounds + haptics.
///
/// All calls are fire-and-forget; errors are silently swallowed so they never
/// interrupt the main flow.
class FeedbackService {
  static const _channel = MethodChannel('com.verifia.app/biometrics');

  /// Play when a new incoming verification request arrives.
  /// iOS: "ReceivedMessage" chime + warning haptic pattern.
  static Future<void> incoming() async {
    try {
      await _channel.invokeMethod<bool>('playIncoming');
    } catch (_) {}
  }

  /// Play when the user successfully sends a QR / verification request.
  /// iOS: "Tink" click + light impact haptic.
  static Future<void> sent() async {
    try {
      await _channel.invokeMethod<bool>('playSent');
    } catch (_) {}
  }

  /// Play when a verification badge is issued (existing behaviour, exposed here
  /// for completeness).
  static Future<void> success() async {
    try {
      await _channel.invokeMethod<bool>('playSuccess');
    } catch (_) {}
  }
}
