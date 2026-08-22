import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../models/skip_record.dart';
import 'provisional_answer_ready_service.dart';

enum NotificationPermissionState { notRequested, granted, denied, unavailable }

abstract interface class AnswerNotificationService {
  Future<void> initialize(ValueChanged<String?> onNotificationTap);
  Future<bool> isEnabled();
  Future<NotificationPermissionState> permissionState();
  Future<bool> shouldShowFirstRecordPrompt();
  Future<void> markFirstRecordPromptShown();
  Future<NotificationPermissionState> setEnabled(bool enabled);
  Future<bool> openSystemNotificationSettings();
  Future<void> rebuild(
    Iterable<SkipRecord> records,
    ProvisionalAnswerReadyService answerReadyService,
  );
  Future<void> cancelRecord(String recordId);
  Future<void> cancelAll();
}

class LocalAnswerNotificationService implements AnswerNotificationService {
  factory LocalAnswerNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    SharedPreferences? preferences,
  }) => LocalAnswerNotificationService._(
    plugin ?? FlutterLocalNotificationsPlugin(),
    preferences,
  );

  LocalAnswerNotificationService._(this._plugin, this._preferences);

  static const _enabledKey = 'answer_notifications_enabled_v1';
  static const _permissionRequestedKey =
      'answer_notifications_permission_requested_v1';
  static const _firstRecordPromptShownKey =
      'answer_notifications_first_record_prompt_shown_v1';
  static const _channelId = 'answer_ready';
  static const _channelName = '答え合わせ通知';
  static const _payload = 'answer-list';

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences? _preferences;
  bool _initialized = false;

  Future<SharedPreferences> get _store async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<void> initialize(ValueChanged<String?> onNotificationTap) async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTap(response.payload);
        },
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        onNotificationTap(launchDetails?.notificationResponse?.payload);
      }
      _initialized = true;
    } on Object {
      // Unit/widget tests and unsupported desktop hosts have no platform plugin.
      _initialized = false;
    }
  }

  @override
  Future<bool> isEnabled() async => (await _store).getBool(_enabledKey) ?? true;

  @override
  Future<NotificationPermissionState> permissionState() async {
    if (kIsWeb || !_initialized) {
      return NotificationPermissionState.unavailable;
    }
    try {
      final granted = await _notificationsAreEnabled();
      if (granted == true) {
        await (await _store).setBool(_permissionRequestedKey, true);
        return NotificationPermissionState.granted;
      }
      final requested =
          (await _store).getBool(_permissionRequestedKey) ?? false;
      return requested
          ? NotificationPermissionState.denied
          : NotificationPermissionState.notRequested;
    } on Object {
      return NotificationPermissionState.unavailable;
    }
  }

  @override
  Future<bool> shouldShowFirstRecordPrompt() async {
    final shown = (await _store).getBool(_firstRecordPromptShownKey) ?? false;
    return !shown &&
        await permissionState() == NotificationPermissionState.notRequested;
  }

  @override
  Future<void> markFirstRecordPromptShown() async {
    await (await _store).setBool(_firstRecordPromptShownKey, true);
  }

  @override
  Future<NotificationPermissionState> setEnabled(bool enabled) async {
    if (!enabled) {
      await (await _store).setBool(_enabledKey, false);
      await cancelAll();
      return permissionState();
    }
    var permission = await permissionState();
    if (permission == NotificationPermissionState.notRequested) {
      permission = await _requestPermission();
    }
    // Keep the user's in-app intent even when iOS permission is denied. The
    // switch is still rendered OFF until OS permission becomes granted, and a
    // foreground refresh can then safely restore scheduling.
    await (await _store).setBool(_enabledKey, true);
    return permission;
  }

  Future<NotificationPermissionState> _requestPermission() async {
    if (kIsWeb) return NotificationPermissionState.unavailable;
    try {
      await (await _store).setBool(_permissionRequestedKey, true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        return granted == false
            ? NotificationPermissionState.denied
            : NotificationPermissionState.granted;
      }
      return NotificationPermissionState.unavailable;
    } on Object {
      return NotificationPermissionState.denied;
    }
  }

  Future<bool?> _notificationsAreEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    }
    return null;
  }

  @override
  Future<bool> openSystemNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return launchUrl(Uri.parse('app-settings:'));
    } on Object {
      return false;
    }
  }

  @override
  Future<void> rebuild(
    Iterable<SkipRecord> records,
    ProvisionalAnswerReadyService answerReadyService,
  ) async {
    if (!await isEnabled() || kIsWeb || !_initialized) return;
    if (await permissionState() != NotificationPermissionState.granted) {
      await cancelAll();
      return;
    }
    await cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final record in records) {
      if (record.answerCheckStatus == AnswerCheckStatus.completed) continue;
      final date = answerReadyService.answerDate(record);
      final scheduled = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        17,
      );
      if (!scheduled.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _notificationId(record.id),
        title: 'もし株の答え合わせができるよ',
        body: '${record.stockName}の答え合わせを見てみよう',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '答え合わせ可能になった見送り記録をお知らせします',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload,
      );
    }
  }

  @override
  Future<void> cancelRecord(String recordId) => _initialized
      ? _plugin.cancel(id: _notificationId(recordId))
      : Future.value();

  @override
  Future<void> cancelAll() =>
      _initialized ? _plugin.cancelAll() : Future.value();

  static int _notificationId(String value) {
    var hash = 0x811C9DC5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}
