import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/repositories/stock_master_repository.dart';
import 'package:moshi_kabu/screens/stock_search_screen.dart';
import 'package:moshi_kabu/services/stock_price_service.dart';
import 'package:moshi_kabu/services/stock_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JPXローカルマスタから内国株式を読み込める', () async {
    const repository = AssetStockMasterRepository();
    final stocks = await repository.load();

    expect(stocks.length, greaterThan(3000));
    expect(
      stocks.any(
        (stock) => stock.code == '285A' && stock.name == 'キオクシアホールディングス',
      ),
      isTrue,
    );
    expect(
      stocks.any((stock) => stock.code == '9432' && stock.name == 'NTT'),
      isTrue,
    );
  });

  test('会社名・コードを正規化して部分一致し最大10件に制限する', () async {
    final stocks = await const AssetStockMasterRepository().load();
    const service = StockSearchService();

    expect(service.search(stocks, 'ソニー').first.code, '6758');
    expect(service.search(stocks, '8306').first.name, contains('三菱UFJ'));
    expect(
      service.search(stocks, '83').any((stock) => stock.code == '8306'),
      isTrue,
    );
    expect(service.search(stocks, '285a').first.code, '285A');
    expect(service.search(stocks, '２８５Ａ').first.code, '285A');
    expect(service.search(stocks, 'フジ').length, greaterThan(1));
    expect(service.search(stocks, '1').length, 10);
    expect(service.search(stocks, '   '), isEmpty);
  });

  testWidgets('空入力と0件時に案内を表示し、入力中に候補を更新する', (tester) async {
    const candidates = [
      StockCandidate(code: '5803', name: 'フジクラ'),
      StockCandidate(code: '4676', name: 'フジ・メディア・ホールディングス'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: StockSearchScreen(candidates: candidates)),
    );

    expect(find.text('会社名または銘柄コードを入力してください'), findsOneWidget);
    expect(find.text('フジクラ'), findsNothing);

    await tester.enterText(find.byType(TextField), 'フジ');
    await tester.pump();
    expect(find.text('フジクラ'), findsOneWidget);
    expect(find.text('フジ・メディア・ホールディングス'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '存在しない銘柄');
    await tester.pump();
    expect(find.text('該当する銘柄が見つかりませんでした'), findsOneWidget);
  });

  testWidgets('候補選択後に既存の株価取得・記録画面へ進む', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StockSearchScreen(
          candidates: [StockCandidate(code: '285A', name: 'キオクシアホールディングス')],
          stockPriceService: _PriceService(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '285a');
    await tester.pump();
    await tester.tap(find.text('キオクシアホールディングス'));
    await tester.pumpAndSettle();

    expect(find.text('迷った株を記録'), findsOneWidget);
    expect(find.text('285A'), findsOneWidget);
    expect(find.text('キオクシアホールディングス'), findsOneWidget);
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.byKey(const ValueKey('yahoo-finance-link')), findsOneWidget);
  });
}

class _PriceService implements StockPriceService {
  const _PriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async => StockQuote(
    code: stock.code,
    name: stock.name,
    price: 1234,
    fetchedAt: DateTime(2026, 8, 11),
  );
}
