class RecentMoshiStock {
  const RecentMoshiStock({
    this.id = '',
    required this.name,
    this.stockCode = '',
    required this.recordedPrice,
    required this.recordedAt,
  });

  final String id;
  final String name;
  final String stockCode;
  final String recordedPrice;
  final String recordedAt;
}

class HomeViewData {
  const HomeViewData({
    this.answerReadyCount = 0,
    this.recentStocks = const [],
    this.trendInsight = '見送りデータがたまると、あなたの判断傾向を振り返れます',
  });

  final int answerReadyCount;
  final List<RecentMoshiStock> recentStocks;
  final String trendInsight;

  bool get hasAnswersReady => answerReadyCount > 0;

  String get guideMessage =>
      hasAnswersReady ? '$answerReadyCount件、答え合わせできるよ！' : '今日は気になる株あった？';

  static const demo = HomeViewData(
    answerReadyCount: 3,
    recentStocks: [
      RecentMoshiStock(
        name: '三菱UFJフィナンシャル・グループ',
        stockCode: '8306',
        recordedPrice: '2,135円',
        recordedAt: '8/11 09:42',
      ),
      RecentMoshiStock(
        name: 'キオクシアHD',
        stockCode: '285A',
        recordedPrice: '8,000円',
        recordedAt: '8/10 14:21',
      ),
      RecentMoshiStock(
        name: 'オリエンタルランド',
        stockCode: '4661',
        recordedPrice: '4,580円',
        recordedAt: '8/9 10:15',
      ),
    ],
  );
}
