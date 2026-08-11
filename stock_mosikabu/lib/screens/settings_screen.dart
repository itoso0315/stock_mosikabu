import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/answer_notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.notificationEnabled,
    required this.notificationPermission,
    required this.onNotificationChanged,
    required this.onOpenNotificationSettings,
    required this.onResetAllRecords,
    this.onMakeLatestReady,
    this.onMakeAllReady,
    this.onResetOverrides,
  });

  final bool notificationEnabled;
  final NotificationPermissionState notificationPermission;
  final Future<NotificationPermissionState> Function(bool enabled)
  onNotificationChanged;
  final Future<bool> Function() onOpenNotificationSettings;
  final Future<void> Function() onResetAllRecords;
  final Future<int> Function()? onMakeLatestReady;
  final Future<int> Function()? onMakeAllReady;
  final Future<void> Function()? onResetOverrides;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationEnabled = widget.notificationEnabled;
  late NotificationPermissionState _notificationPermission =
      widget.notificationPermission;
  bool _isRunning = false;

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRunning) {
      _notificationEnabled = widget.notificationEnabled;
      _notificationPermission = widget.notificationPermission;
    }
  }

  Future<void> _toggleNotification(bool enabled) async {
    if (_isRunning) return;
    if (enabled &&
        _notificationPermission == NotificationPermissionState.notRequested) {
      final proceed = await _showNotificationExplanation();
      if (!proceed || !mounted) return;
    }
    setState(() => _isRunning = true);
    final result = await widget.onNotificationChanged(enabled);
    if (!mounted) return;
    setState(() {
      _notificationEnabled =
          enabled && result == NotificationPermissionState.granted;
      _notificationPermission = result;
      _isRunning = false;
    });
    if (enabled && result == NotificationPermissionState.denied) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('端末の通知権限が許可されていません')));
    }
  }

  Future<bool> _showNotificationExplanation() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('答え合わせの日にお知らせしますか？'),
          content: const Text('見送った株の答え合わせができる日に、もし株から通知します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('あとで'),
            ),
            FilledButton(
              key: const ValueKey('request-notification-permission'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('通知を受け取る'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての記録を削除しますか？'),
        content: const Text('見送り記録と答え合わせ結果がすべて削除されます。\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const ValueKey('confirm-reset-all-records'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('すべて削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isRunning = true);
    try {
      await widget.onResetAllRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべての記録を削除しました')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を削除できませんでした。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _runDeveloper(
    Future<int> Function() operation,
    String success,
  ) async {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    try {
      final count = await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count == 0 ? '対象となる未答え合わせ記録がありません' : success)),
      );
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _resetOverrides() async {
    await widget.onResetOverrides!();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テスト用変更をリセットしました')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('設定'),
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _SettingsCard(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('answer-notification-switch'),
                  value: _notificationEnabled,
                  onChanged: _isRunning ? null : _toggleNotification,
                  title: const Text('答え合わせ通知'),
                  subtitle: Text(_notificationSubtitle),
                  secondary: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (_notificationPermission ==
                    NotificationPermissionState.denied) ...[
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('notification-permission-denied'),
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.mutedText,
                    ),
                    title: const Text('端末の設定で通知がオフになっています'),
                    trailing: TextButton(
                      key: const ValueKey('open-notification-settings'),
                      onPressed: widget.onOpenNotificationSettings,
                      child: const Text('設定を開く'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('データ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _SettingsCard(
            child: ListTile(
              key: const ValueKey('reset-all-records'),
              onTap: _isRunning ? null : _confirmResetAll,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade600,
              ),
              title: Text(
                'すべての記録をリセット',
                style: TextStyle(color: Colors.red.shade700),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          if (kDebugMode && widget.onMakeLatestReady != null) ...[
            const SizedBox(height: 28),
            Text('開発者メニュー', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Debug Build限定の答え合わせ状態確認ツールです。',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            _DeveloperTile(
              key: const ValueKey('make-latest-answer-ready'),
              label: '最新の記録を答え合わせ可能にする',
              onTap: () => _runDeveloper(
                widget.onMakeLatestReady!,
                '最新の記録を答え合わせ可能にしました',
              ),
            ),
            const SizedBox(height: 10),
            _DeveloperTile(
              key: const ValueKey('make-all-answers-ready'),
              label: '未答え合わせ記録をすべて答え合わせ可能にする',
              onTap: () =>
                  _runDeveloper(widget.onMakeAllReady!, '未答え合わせ記録をすべて変更しました'),
            ),
            const SizedBox(height: 10),
            _DeveloperTile(
              key: const ValueKey('reset-answer-overrides'),
              label: 'テスト用変更をリセット',
              onTap: _resetOverrides,
            ),
          ],
        ],
      ),
    ),
  );

  String get _notificationSubtitle => switch (_notificationPermission) {
    NotificationPermissionState.notRequested => '通知をONにすると、目的をご案内します',
    NotificationPermissionState.granted => '答え合わせ日の17:00ごろにお知らせします',
    NotificationPermissionState.denied => '端末側で通知が許可されていません',
    NotificationPermissionState.unavailable => 'この端末では通知状態を確認できません',
  };
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.outline),
    ),
    child: child,
  );
}

class _DeveloperTile extends StatelessWidget {
  const _DeveloperTile({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _SettingsCard(
    child: ListTile(
      onTap: onTap,
      leading: const Icon(
        Icons.build_circle_outlined,
        color: AppColors.primaryDark,
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
