import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/repositories/developer_answer_override_repository.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('デバッグ用予定日上書きを端末保存して再読込できる', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstRepository = SharedPreferencesDeveloperAnswerOverrideRepository(
      preferences: preferences,
    );
    final date = DateTime(2026, 8, 11, 11, 59);
    await firstRepository.replaceAll({'record-id': date});

    final restartedRepository =
        SharedPreferencesDeveloperAnswerOverrideRepository(
          preferences: preferences,
        );
    expect((await restartedRepository.getAll())['record-id'], date);
  });

  testWidgets('debugメニューで最新記録を答え合わせ可能にしてホームと一覧へ反映する', (tester) async {
    final record = _record('latest', DateTime(2026, 8, 10));
    final overrideRepository = _MemoryOverrideRepository();
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRecordRepository([
          _record('older', DateTime(2026, 8, 9)),
          record,
        ]),
        developerOverrideRepository: overrideRepository,
        clock: () => DateTime(2026, 8, 11, 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('開発者メニュー'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('make-latest-answer-ready')));
    await tester.pumpAndSettle();
    expect(overrideRepository.values.keys, ['latest']);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1件、答え合わせできるよ！'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-count-badge')), findsOneWidget);

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    expect(find.text('開発テスト銘柄'), findsOneWidget);
    expect(find.text('2026/08/04'), findsOneWidget);
    expect(record.stockName, '開発テスト銘柄');
    expect(record.answerCheckSetting.period, AnswerCheckPeriod.oneMonth);
  });

  testWidgets('全件変更とリセットを反映できる', (tester) async {
    final overrideRepository = _MemoryOverrideRepository();
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRecordRepository([
          _record('first', DateTime(2026, 8, 9)),
          _record('second', DateTime(2026, 8, 10)),
        ]),
        developerOverrideRepository: overrideRepository,
        clock: () => DateTime(2026, 8, 11),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('make-all-answers-ready')));
    await tester.pumpAndSettle();
    expect(overrideRepository.values.length, 2);

    await tester.tap(find.byKey(const ValueKey('reset-answer-overrides')));
    await tester.pumpAndSettle();
    expect(overrideRepository.values, isEmpty);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
  });

  testWidgets('release相当では開発者メニューへ進めない', (tester) async {
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRecordRepository(const []),
        developerOverrideRepository: _MemoryOverrideRepository(),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('開発者メニュー'), findsNothing);
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
  });
}

SkipRecord _record(String id, DateTime date) => SkipRecord(
  id: id,
  stockCode: '9432',
  stockName: '開発テスト銘柄',
  skippedPrice: 1234,
  recordedAt: date,
  reason: SkipReason.priceTooHigh,
  reasonLabel: '高いと思った',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

class _MemoryRecordRepository implements SkipRecordRepository {
  _MemoryRecordRepository(this.records);

  final List<SkipRecord> records;

  @override
  Future<List<SkipRecord>> getAll() async => records;

  @override
  Future<SkipRecord> save(SkipRecordDraft draft) => throw UnimplementedError();

  @override
  Future<SkipRecord> update(SkipRecord record) async => record;
}

class _MemoryOverrideRepository implements DeveloperAnswerOverrideRepository {
  Map<String, DateTime> values = {};

  @override
  Future<void> clear() async => values = {};

  @override
  Future<Map<String, DateTime>> getAll() async => {...values};

  @override
  Future<void> replaceAll(Map<String, DateTime> overrides) async {
    values = {...overrides};
  }
}
