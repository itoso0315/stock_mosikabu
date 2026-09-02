import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/services/backend_warmup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('STARTを押すまで開始画面に留まり、押すとホームへ進む', (tester) async {
    final warmup = _PendingWarmupService();

    await tester.pumpWidget(
      MoshiKabuApp(showStartScreen: true, backendWarmupService: warmup),
    );
    await tester.pump();

    expect(find.text('投資の答え合わせを、未来の自分と。'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('今日は気になる株あった？'), findsNothing);
    expect(warmup.calls, 1);

    final screenCenterX = tester.getSize(find.byType(Scaffold)).width / 2;
    for (final label in ['もし株', '投資の答え合わせを、未来の自分と。', 'START']) {
      expect(tester.getCenter(find.text(label)).dx, screenCenterX);
    }

    await tester.tap(find.byKey(const ValueKey('start-button')));
    await tester.pump();

    expect(find.text('START'), findsNothing);
    expect(find.text('今日は気になる株あった？'), findsOneWidget);
    expect(warmup.calls, 1);

    warmup.complete();
  });
}

class _PendingWarmupService implements BackendWarmupService {
  final _completer = Completer<void>();
  int calls = 0;

  @override
  Future<void> warmUp() {
    calls++;
    return _completer.future;
  }

  void complete() => _completer.complete();
}
