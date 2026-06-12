import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Represents a status change detected on a previously-PENDING sent challenge.
class SentStatusChange {
  final SentChallenge challenge;
  final String newStatus; // 'REJECTED' | 'CANCELLED' | 'USED'

  const SentStatusChange({required this.challenge, required this.newStatus});
}

/// Singleton service that polls sent challenges and fires notifications when
/// a PENDING challenge transitions to REJECTED or CANCELLED.
///
/// Consumed by [HomeScreen] to show in-app banners.
/// Consumed by [_SentTab] to keep the list live.
class SentChallengesService extends ChangeNotifier {
  SentChallengesService._();
  static final SentChallengesService instance = SentChallengesService._();

  final _api = ApiService();
  Timer? _timer;

  List<SentChallenge> _items = [];

  /// True while consecutive poll attempts are failing due to network errors.
  bool isOffline = false;

  /// Statuses we last saw for each nonce (tracked to detect transitions).
  final Map<String, String> _lastStatus = {};

  /// The latest status change event (cleared after [consumeLatestChange]).
  SentStatusChange? _latestChange;

  List<SentChallenge> get items => _items;

  SentStatusChange? consumeLatestChange() {
    final c = _latestChange;
    _latestChange = null;
    return c;
  }

  /// Optimistically update a challenge's status in the local list.
  void updateStatus(String nonce, String status) {
    _items = [
      for (final c in _items)
        if (c.nonce == nonce) _withStatus(c, status) else c,
    ];
    _lastStatus[nonce] = status;
    notifyListeners();
  }

  /// Start polling every 8 seconds. Safe to call multiple times.
  void start() {
    if (_timer != null) return;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _poll();

  Future<void> _poll() async {
    try {
      final fresh = await _api.getSentChallenges();
      _detectTransitions(fresh);
      _items = fresh;
      if (isOffline) isOffline = false; // back online
      notifyListeners();
    } catch (e) {
      if (e is NetworkException && e.isNetwork) {
        isOffline = true;
        notifyListeners();
      }
    }
  }

  void _detectTransitions(List<SentChallenge> fresh) {
    for (final c in fresh) {
      final prev = _lastStatus[c.nonce];
      _lastStatus[c.nonce] = c.status;

      // Fire notification only on PENDING → REJECTED or PENDING → CANCELLED
      if (prev == 'PENDING' && (c.status == 'REJECTED' || c.status == 'CANCELLED')) {
        _latestChange = SentStatusChange(challenge: c, newStatus: c.status);
      }
    }
  }

  // Creates a copy of a SentChallenge with a different status.
  SentChallenge _withStatus(SentChallenge c, String status) => SentChallenge(
        nonce: c.nonce,
        status: status,
        targetEmail: c.targetEmail,
        createdAt: c.createdAt,
        expiresAt: c.expiresAt,
        subjectFullName: c.subjectFullName,
        subjectPhoto: c.subjectPhoto,
        subjectIdType: c.subjectIdType,
        subjectIdFrontPhoto: c.subjectIdFrontPhoto,
        validatedAt: c.validatedAt,
        livenessMatchScore: c.livenessMatchScore,
        livenessSnapshot: c.livenessSnapshot,
      );
}
