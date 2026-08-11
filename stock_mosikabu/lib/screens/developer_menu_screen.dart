import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DeveloperMenuScreen extends StatefulWidget {
  const DeveloperMenuScreen({
    super.key,
    required this.onMakeLatestReady,
    required this.onMakeAllReady,
    required this.onReset,
  });

  final Future<int> Function() onMakeLatestReady;
  final Future<int> Function() onMakeAllReady;
  final Future<void> Function() onReset;

  @override
  State<DeveloperMenuScreen> createState() => _DeveloperMenuScreenState();
}

class _DeveloperMenuScreenState extends State<DeveloperMenuScreen> {
  bool _isRunning = false;

  Future<void> _run(Future<int> Function() operation, String success) async {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    try {
      final count = await operation();
      if (!mounted) return;
      final message = count == 0 ? '対象となる未答え合わせ記録がありません' : success;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テスト状態を変更できませんでした')));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _reset() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    try {
      await widget.onReset();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テスト用変更をリセットしました')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テスト状態を変更できませんでした')));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Text('開発者メニュー', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Debug Build限定の答え合わせ状態確認ツールです。',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            _DeveloperActionCard(
              key: const ValueKey('make-latest-answer-ready'),
              icon: Icons.schedule_send_rounded,
              title: '最新の記録を答え合わせ可能にする',
              onTap: _isRunning
                  ? null
                  : () => _run(widget.onMakeLatestReady, '最新の記録を答え合わせ可能にしました'),
            ),
            const SizedBox(height: 12),
            _DeveloperActionCard(
              key: const ValueKey('make-all-answers-ready'),
              icon: Icons.done_all_rounded,
              title: '未答え合わせ記録をすべて答え合わせ可能にする',
              onTap: _isRunning
                  ? null
                  : () => _run(widget.onMakeAllReady, '未答え合わせ記録をすべて変更しました'),
            ),
            const SizedBox(height: 12),
            _DeveloperActionCard(
              key: const ValueKey('reset-answer-overrides'),
              icon: Icons.restart_alt_rounded,
              title: 'テスト用変更をリセット',
              onTap: _isRunning ? null : _reset,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperActionCard extends StatelessWidget {
  const _DeveloperActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(icon, color: AppColors.primaryDark),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
