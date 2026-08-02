import 'package:flutter_test/flutter_test.dart';
import 'package:stock_trainer_flutter/main.dart';

void main() {
  testWidgets('ゲーム開始を押すとQuestion画面へ遷移する', (tester) async {
    await tester.pumpWidget(const StockTrainerApp());

    expect(find.text('ゲーム開始'), findsOneWidget);

    await tester.tap(find.text('ゲーム開始'));
    await tester.pumpAndSettle();

    expect(find.text('Question'), findsOneWidget);
    expect(find.text('株価チャートを見て、次の値動きを予測しましょう。'), findsOneWidget);
    expect(find.text('ゲーム開始'), findsNothing);
  });
}
