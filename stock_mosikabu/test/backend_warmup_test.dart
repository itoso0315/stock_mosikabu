import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/services/backend_warmup_service.dart';

void main() {
  testWidgets('ウォームアップ失敗を待たずホーム画面を表示する', (tester) async {
    final service = _FailingWarmupService();

    await tester.pumpWidget(MoshiKabuApp(backendWarmupService: service));
    await tester.pump();

    expect(find.text('今日は気になる株あった？'), findsOneWidget);
    expect(service.calls, 1);
  });
}

class _FailingWarmupService implements BackendWarmupService {
  int calls = 0;

  @override
  Future<void> warmUp() async {
    calls++;
    throw StateError('offline');
  }
}
