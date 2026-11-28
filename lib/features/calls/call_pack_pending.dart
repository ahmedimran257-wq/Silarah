// A minute-pack payment Google Play has not confirmed yet (UPI, slow cards).
// Play charges once, later; the server adds the minutes when RevenueCat tells
// it. Until then the member sees "Payment pending" on the minutes sheet and
// the Calls tab card, even after reopening the app, like Play's own order
// status. Cleared when the pack balance rises or after three days.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/supabase_service.dart';

@immutable
class PendingPackPayment {
  const PendingPackPayment({required this.minutes, required this.balanceBefore, required this.at});

  final int minutes;

  /// Pack balance when the payment started: a higher balance means it landed.
  final int balanceBefore;
  final DateTime at;

  Map<String, Object> toJson() =>
      {'minutes': minutes, 'before': balanceBefore, 'at': at.toUtc().toIso8601String()};

  static PendingPackPayment? fromJson(Object? value) {
    if (value is! Map) return null;
    final minutes = value['minutes'];
    final before = value['before'];
    final at = DateTime.tryParse('${value['at']}');
    if (minutes is! int || before is! int || at == null) return null;
    return PendingPackPayment(minutes: minutes, balanceBefore: before, at: at);
  }
}

class CallPackPending {
  CallPackPending._();
  static final instance = CallPackPending._();

  /// How long a payment is shown as pending before it is forgotten.
  static const maxAge = Duration(days: 3);

  final ValueNotifier<PendingPackPayment?> current = ValueNotifier(null);

  String? get _key {
    final user = SupabaseService.isInitialized ? SupabaseService.currentUserId : null;
    return user == null ? null : 'call_pack_pending_$user';
  }

  Future<void> load() async {
    final key = _key;
    if (key == null) {
      current.value = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    PendingPackPayment? value;
    try {
      value = raw == null ? null : PendingPackPayment.fromJson(jsonDecode(raw));
    } catch (_) {
      value = null;
    }
    if (value != null && DateTime.now().difference(value.at) > maxAge) {
      await clear();
      return;
    }
    current.value = value;
  }

  Future<void> save(int minutes, int balanceBefore) async {
    final value = PendingPackPayment(minutes: minutes, balanceBefore: balanceBefore, at: DateTime.now());
    current.value = value;
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value.toJson()));
  }

  Future<void> clear() async {
    current.value = null;
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// The pack balance now: if it rose, the pending payment has landed.
  /// Returns true when it did (the caller can say "minutes added").
  Future<bool> settleWith(int packMinutes) async {
    final value = current.value;
    if (value == null || packMinutes <= value.balanceBefore) return false;
    await clear();
    return true;
  }
}
