import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'api_service.dart';

/// Centralized wrapper for all OneSignal SDK interactions.
///
/// Rules:
/// - No direct OneSignal SDK calls outside this class.
/// - Initialize once via [initialize] before [runApp].
/// - Call [login] / [logout] alongside account auth events.
/// - Call [setupSubscriptionVerification] from the first screen with a
///   [BuildContext] to show the one-time integration confirmation dialog.
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();
  factory OneSignalService() => instance;

  static const _appId = 'e52ba803-c6b7-4291-af25-2bbf663d3f30';

  bool _isInitialized = false;

  // ── Initialization ────────────────────────────────────────────────────────

  void initialize() {
    if (_isInitialized) return;
    // Verbose logging for development; remove for production builds.
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_appId);
    _isInitialized = true;
    _registerBackendTokenOnChange();
  }

  // ── Token registration ────────────────────────────────────────────────────

  /// Registers the push subscription's server-assigned *Subscription ID*
  /// (formerly called "Player ID") with the VerifiA backend — NOT
  /// `pushSubscription.token`, which is the raw platform APNs/FCM token and
  /// is a different value. The backend's OneSignal REST call targets
  /// recipients via `include_subscription_ids`, which requires the
  /// Subscription ID; sending the raw device token there silently matches
  /// nobody.
  ///
  /// Runs both right now (if an ID is already assigned — e.g. the OneSignal
  /// SDK restored a subscription that predates this app launch, such as
  /// after a reinstall) and on every future change. Relying solely on the
  /// observer misses the current value: `addObserver` only fires on
  /// transitions, so if the ID is already set by the time we attach it (no
  /// "change" occurs), the backend never learns about it.
  void _registerBackendTokenOnChange() {
    _maybeRegisterSubscription(OneSignal.User.pushSubscription.id);
    OneSignal.User.pushSubscription.addObserver((state) {
      _maybeRegisterSubscription(state.current.id);
    });
  }

  void _maybeRegisterSubscription(String? subscriptionId) {
    if (!_isServerAssigned(subscriptionId)) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    ApiService().registerDeviceToken(subscriptionId!, platform);
  }

  /// Re-attempts registering whatever Subscription ID is currently assigned.
  ///
  /// [initialize] is called during onboarding (`PermissionsWizardScreen`),
  /// before an account/session exists — at that point `registerDeviceToken`
  /// silently 401s because the backend requires auth, and since it's only
  /// wired to fire on the push subscription's *observer* (a one-time event
  /// per ID value), it never gets a second chance once the device already
  /// has an ID. Call this once an authenticated session is guaranteed to
  /// exist (e.g. `HomeScreen.initState`) so the ID actually reaches the
  /// backend. Safe to call repeatedly — the backend upserts by token.
  void syncDeviceToken() {
    _maybeRegisterSubscription(OneSignal.User.pushSubscription.id);
  }

  // ── User identity ─────────────────────────────────────────────────────────

  /// Associates the device with an account after login.
  /// [externalId] should be the account's stable unique ID.
  void login(String externalId) {
    OneSignal.login(externalId);
  }

  /// Disassociates the device from the account on logout.
  /// Also unregisters the push subscription from the VerifiA backend.
  Future<void> logout() async {
    final subscriptionId = OneSignal.User.pushSubscription.id;
    if (_isServerAssigned(subscriptionId)) {
      await ApiService().unregisterDeviceToken(subscriptionId!);
    }
    OneSignal.logout();
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────

  void setEmail(String email) {
    OneSignal.User.addEmail(email);
  }

  void removeEmail(String email) {
    OneSignal.User.removeEmail(email);
  }

  // ── Tags ──────────────────────────────────────────────────────────────────

  void setTag(String key, String value) {
    OneSignal.User.addTagWithKey(key, value);
  }

  // ── Notification listeners ────────────────────────────────────────────────

  void addClickListener(void Function(OSNotificationClickEvent) handler) {
    OneSignal.Notifications.addClickListener(handler);
  }

  void addForegroundListener(
      void Function(OSNotificationWillDisplayEvent) handler) {
    OneSignal.Notifications.addForegroundWillDisplayListener(handler);
  }

  // ── Push Subscription Verification Dialog ────────────────────────────────

  static bool _verificationDialogShown = false;

  /// Returns true if [id] is a real server-assigned subscription ID
  /// (non-empty and not the local-* placeholder the SDK assigns before registration).
  static bool _isServerAssigned(String? id) =>
      id != null && id.isNotEmpty && !id.startsWith('local-');

  /// Call this once from the first screen that has a [BuildContext]
  /// (e.g. [HomeScreen.initState] via [WidgetsBinding.addPostFrameCallback]).
  ///
  /// Shows a one-time dialog confirming the OneSignal integration is working,
  /// and only requests push permission when the user taps "Got it".
  void setupSubscriptionVerification(BuildContext context) {
    // Observe future changes to the subscription ID
    OneSignal.User.pushSubscription.addObserver((state) {
      _maybeShowVerificationDialog(context, state.current.id);
    });

    // The ID may already be server-assigned before the observer attaches
    _maybeShowVerificationDialog(
        context, OneSignal.User.pushSubscription.id);
  }

  void _maybeShowVerificationDialog(BuildContext context, String? id) {
    if (!_isServerAssigned(id) || _verificationDialogShown) return;
    _verificationDialogShown = true;

    // Use addPostFrameCallback to avoid showing dialogs during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Your OneSignal SDK integration is complete!'),
          content: const Text(
            'You can now send Push Notifications & In-App Messages through OneSignal. '
            'Tap below to enable push notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                OneSignal.Notifications.requestPermission(true);
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    });
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  void setLogLevel(OSLogLevel level) {
    OneSignal.Debug.setLogLevel(level);
  }
}
