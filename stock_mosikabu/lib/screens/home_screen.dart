import 'package:flutter/material.dart';

import '../models/home_view_data.dart';
import '../theme/app_theme.dart';
import '../widgets/cat_placeholder.dart';
import '../widgets/home_bottom_navigation.dart';
import 'stock_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.data = const HomeViewData(),
    this.onAnswersTap,
    this.searchScreenBuilder,
    this.answersScreenBuilder,
    this.developerMenuBuilder,
  });

  final HomeViewData data;
  final VoidCallback? onAnswersTap;
  final WidgetBuilder? searchScreenBuilder;
  final WidgetBuilder? answersScreenBuilder;
  final WidgetBuilder? developerMenuBuilder;

  @override
  Widget build(BuildContext context) {
    void openAnswers() {
      final callback = onAnswersTap;
      if (callback != null) {
        callback();
        return;
      }
      final builder = answersScreenBuilder;
      if (builder != null) {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
      }
    }

    final answersTap = onAnswersTap != null || answersScreenBuilder != null
        ? openAnswers
        : null;
    return Scaffold(
      bottomNavigationBar: HomeBottomNavigation(
        onSettingsTap: developerMenuBuilder == null
            ? null
            : () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: developerMenuBuilder!)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(
                answerReadyCount: data.answerReadyCount,
                onAnswersTap: answersTap,
              ),
              const SizedBox(height: 20),
              _GuideArea(
                message: data.guideMessage,
                onTap: data.hasAnswersReady ? answersTap : null,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          searchScreenBuilder ??
                          (_) => const StockSearchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('もし株を記録する'),
              ),
              const SizedBox(height: 30),
              _RecentStocksCard(stocks: data.recentStocks),
              const SizedBox(height: 20),
              const _DecisionTrendCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionTrendCard extends StatelessWidget {
  const _DecisionTrendCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'あなたの見送り傾向',
      icon: Icons.bar_chart_rounded,
      child: _EmptyMessage('見送りデータがたまると、あなたの判断傾向を振り返れます'),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.answerReadyCount,
    required this.onAnswersTap,
  });

  final int answerReadyCount;
  final VoidCallback? onAnswersTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('もし株', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 5),
                const Icon(
                  Icons.pets_rounded,
                  key: ValueKey('home-title-paw'),
                  size: 16,
                  color: AppColors.primaryDark,
                  semanticLabel: '肉球',
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '買わなかった株の答え合わせアプリ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: _NotificationBell(
            count: answerReadyCount,
            onTap: onAnswersTap,
          ),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IconButton(
              tooltip: '通知',
              onPressed: onTap,
              icon: const Icon(Icons.notifications_none_rounded),
              color: AppColors.text,
              disabledColor: AppColors.text,
              iconSize: 25,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (count > 0)
            Positioned(
              key: const ValueKey('answer-count-badge'),
              right: 1,
              top: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE66F83),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentStocksCard extends StatelessWidget {
  const _RecentStocksCard({required this.stocks});

  final List<RecentMoshiStock> stocks;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '最近のもし株',
      icon: Icons.history_rounded,
      child: stocks.isEmpty
          ? const _EmptyMessage('記録したもし株がここに表示されます')
          : Column(
              children: [
                for (var index = 0; index < stocks.length; index++) ...[
                  _RecentStockRow(stock: stocks[index]),
                  if (index != stocks.length - 1)
                    const Divider(height: 25, color: AppColors.outline),
                ],
              ],
            ),
    );
  }
}

class _RecentStockRow extends StatelessWidget {
  const _RecentStockRow({required this.stock});

  final RecentMoshiStock stock;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.warmAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stock.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    stock.recordedPrice,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stock.recordedAt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideArea extends StatelessWidget {
  const _GuideArea({required this.message, required this.onTap});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const CatPlaceholder(),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(28),
                child: CustomPaint(
                  painter: const _SpeechBubblePainter(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 18, 18),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  const _SpeechBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 28.0;
    final tailCenter = size.height / 2;
    final bubble = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, tailCenter + 6)
      ..quadraticBezierTo(-3, tailCenter + 3, -8, tailCenter)
      ..quadraticBezierTo(-3, tailCenter - 3, 0, tailCenter - 6)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
    canvas.drawShadow(bubble, const Color(0x12473C30), 4, false);
    canvas.drawPath(
      bubble,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..color = AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D473C30),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 22),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
    );
  }
}
