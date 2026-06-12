import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Singleton service that polls for incoming verification requests.
///
/// Consumers:
///   - [HomeScreen] — badge count + in-app banner
///   - [IncomingValidationsScreen] — live list
class InboxService extends ChangeNotifier {
  InboxService._();
  static final InboxService instance = InboxService._();

  final _api = ApiService();
  Timer? _timer;

  List<IncomingChallenge> _items = [];
  Set<String> _seenNonces = {};
  int _unseenCount = 0;

  /// True while consecutive poll attempts are failing due to network errors.
  bool isOffline = false;

  /// The most recently arrived challenge (cleared after [consumeLatestNew]).
  IncomingChallenge? _latestNew;

  List<IncomingChallenge> get items => _items;
  int get unseenCount => _unseenCount;

  /// Optimistically removes a challenge from the local list (e.g. after rejection).
  void removeItem(String nonce) {
    _items = _items.where((c) => c.nonce != nonce).toList();
    notifyListeners();
  }

  /// Returns and clears the newest unseen challenge (for showing the banner).
  IncomingChallenge? consumeLatestNew() {
    final c = _latestNew;
    _latestNew = null;
    return c;
  }

  /// Start polling. Safe to call multiple times.
  void start() {
    if (_timer != null) return;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call when the user navigates to the inbox tab — resets badge.
  void markAllSeen() {
    _seenNonces = _items.map((c) => c.nonce).toSet();
    _unseenCount = 0;
    notifyListeners();
  }

  Future<void> refresh() => _poll();

  Future<void> _poll() async {
    try {
      final fresh = await _api.getIncomingChallenges();
      final prevNonces = _items.map((c) => c.nonce).toSet();
      final newItems = fresh.where((c) => !prevNonces.contains(c.nonce)).toList();

      _items = fresh;
      _unseenCount = fresh.where((c) => !_seenNonces.contains(c.nonce)).length;

      if (newItems.isNotEmpty) {
        _latestNew = newItems.first;
      }

      if (isOffline) isOffline = false; // back online
      notifyListeners();
    } catch (e) {
      if (e is NetworkException && e.isNetwork) {
        isOffline = true;
        notifyListeners();
      }
      // Other errors (e.g. auth) fail silently.
    }
  }
}
