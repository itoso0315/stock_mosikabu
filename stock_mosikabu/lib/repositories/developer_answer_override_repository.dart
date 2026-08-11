import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DeveloperAnswerOverrideRepository {
  Future<Map<String, DateTime>> getAll();
  Future<void> replaceAll(Map<String, DateTime> overrides);
  Future<void> clear();
}

class SharedPreferencesDeveloperAnswerOverrideRepository
    implements DeveloperAnswerOverrideRepository {
  SharedPreferencesDeveloperAnswerOverrideRepository({this.preferences});

  static const _key = 'debug_answer_date_overrides_v1';
  final SharedPreferences? preferences;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<Map<String, DateTime>> getAll() async {
    final source = (await _store).getString(_key);
    if (source == null) return const {};
    final values = jsonDecode(source) as Map<String, dynamic>;
    return values.map(
      (id, value) => MapEntry(id, DateTime.parse(value as String)),
    );
  }

  @override
  Future<void> replaceAll(Map<String, DateTime> overrides) async {
    final encoded = overrides.map(
      (id, date) => MapEntry(id, date.toIso8601String()),
    );
    final didSave = await (await _store).setString(_key, jsonEncode(encoded));
    if (!didSave) throw const DeveloperOverrideException();
  }

  @override
  Future<void> clear() async {
    await (await _store).remove(_key);
  }
}

class DeveloperOverrideException implements Exception {
  const DeveloperOverrideException();
}
