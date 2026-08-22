import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/widgets/stock_icon.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/screens/stock_search_screen.dart';

void main() {
  group('StockIconの表示文字', () {
    test('日本語会社名の先頭文字を使う', () {
      expect(_character('トヨタ自動車'), 'ト');
      expect(_character('任天堂'), '任');
      expect(_character('ソニーグループ'), 'ソ');
      expect(_character('三菱UFJフィナンシャル・グループ'), '三');
    });

    test('英字を大文字にし会社種別表記を除去する', () {
      expect(_character('NTT'), 'N');
      expect(_character('ntt'), 'N');
      expect(_character('株式会社トヨタ自動車'), 'ト');
      expect(_character('（株）任天堂'), '任');
      expect(_character('(株) ZOZO'), 'Z');
      expect(_character('㈱ ソニーグループ'), 'ソ');
    });

    test('空の会社名は銘柄コード、両方空なら疑問符へフォールバックする', () {
      expect(_character('', stockCode: '7203'), '7');
      expect(_character('株式会社', stockCode: '8306'), '8');
      expect(_character('   ', stockCode: '   '), '?');
    });
  });

  testWidgets('共通Widgetが指定サイズで表示文字を中央に描画する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StockIcon(
            companyName: '株式会社トヨタ自動車',
            stockCode: '7203',
            size: 44,
          ),
        ),
      ),
    );

    expect(find.text('ト'), findsOneWidget);
    expect(tester.getSize(find.byType(StockIcon)), const Size.square(44));
  });

  testWidgets('検索結果も銘柄コードではなく会社名の頭文字を表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StockSearchScreen(
          candidates: [
            StockCandidate(code: '3116', name: 'トヨタ紡織'),
            StockCandidate(code: '7203', name: 'トヨタ自動車'),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'トヨタ');
    await tester.pump();

    expect(find.byType(StockIcon), findsNWidgets(2));
    expect(find.text('ト'), findsNWidgets(2));
    expect(find.text('3'), findsNothing);
    expect(find.text('7'), findsNothing);
  });
}

String _character(String companyName, {String stockCode = ''}) =>
    StockIcon.displayCharacter(companyName: companyName, stockCode: stockCode);
