class RecentMoshiStock {
  const RecentMoshiStock({
    required this.name,
    required this.recordedPrice,
    required this.recordedAt,
  });

  final String name;
  final String recordedPrice;
  final String recordedAt;
}

class HomeViewData {
  const HomeViewData({this.answerReadyCount = 0, this.recentStocks = const []});

  final int answerReadyCount;
  final List<RecentMoshiStock> recentStocks;

  bool get hasAnswersReady => answerReadyCount > 0;

  String get guideMessage =>
      hasAnswersReady ? '$answerReadyCount件、答え合わせできるよ！' : '今日は気になる株あった？';

  static const demo = HomeViewData(
    answerReadyCount: 3,
    recentStocks: [
      RecentMoshiStock(
        name: '三菱UFJフィナンシャル・グループ',
        recordedPrice: '2,135円',
        recordedAt: '8/11 09:42',
      ),
      RecentMoshiStock(
        name: 'キオクシアHD',
        recordedPrice: '8,000円',
        recordedAt: '8/10 14:21',
      ),
      RecentMoshiStock(
        name: 'オリエンタルランド',
        recordedPrice: '4,580円',
        recordedAt: '8/9 10:15',
      ),
    ],
  );
}
