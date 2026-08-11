import 'skip_record_draft.dart';

enum AnswerCheckStatus { pending, completed }

class SkipRecord {
  const SkipRecord({
    required this.id,
    required this.stockCode,
    required this.stockName,
    required this.skippedPrice,
    required this.recordedAt,
    required this.reason,
    required this.reasonLabel,
    required this.answerCheckSetting,
    required this.answerCheckStatus,
    this.otherNote,
    this.answerPrice,
    this.answerPriceDate,
    this.answerChangePercent,
    this.answeredAt,
  });

  final String id;
  final String stockCode;
  final String stockName;
  final double skippedPrice;
  final DateTime recordedAt;
  final SkipReason reason;
  final String reasonLabel;
  final String? otherNote;
  final AnswerCheckSetting answerCheckSetting;
  final AnswerCheckStatus answerCheckStatus;
  final double? answerPrice;
  final DateTime? answerPriceDate;
  final double? answerChangePercent;
  final DateTime? answeredAt;

  SkipRecord copyWith({
    AnswerCheckStatus? answerCheckStatus,
    double? answerPrice,
    DateTime? answerPriceDate,
    double? answerChangePercent,
    DateTime? answeredAt,
  }) => SkipRecord(
    id: id,
    stockCode: stockCode,
    stockName: stockName,
    skippedPrice: skippedPrice,
    recordedAt: recordedAt,
    reason: reason,
    reasonLabel: reasonLabel,
    otherNote: otherNote,
    answerCheckSetting: answerCheckSetting,
    answerCheckStatus: answerCheckStatus ?? this.answerCheckStatus,
    answerPrice: answerPrice ?? this.answerPrice,
    answerPriceDate: answerPriceDate ?? this.answerPriceDate,
    answerChangePercent: answerChangePercent ?? this.answerChangePercent,
    answeredAt: answeredAt ?? this.answeredAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'stockCode': stockCode,
    'stockName': stockName,
    'skippedPrice': skippedPrice,
    'recordedAt': recordedAt.toIso8601String(),
    'reason': reason.name,
    'reasonLabel': reasonLabel,
    'otherNote': otherNote,
    'answerPeriod': answerCheckSetting.period.name,
    'customAnswerDate': answerCheckSetting.customDate?.toIso8601String(),
    'answerCheckStatus': answerCheckStatus.name,
    'answerPrice': answerPrice,
    'answerPriceDate': answerPriceDate?.toIso8601String(),
    'answerChangePercent': answerChangePercent,
    'answeredAt': answeredAt?.toIso8601String(),
  };

  factory SkipRecord.fromJson(Map<String, dynamic> json) {
    final customDate = json['customAnswerDate'] as String?;
    return SkipRecord(
      id: json['id'] as String,
      stockCode: json['stockCode'] as String,
      stockName: json['stockName'] as String,
      skippedPrice: (json['skippedPrice'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      reason: SkipReason.values.byName(json['reason'] as String),
      reasonLabel: json['reasonLabel'] as String,
      otherNote: json['otherNote'] as String?,
      answerCheckSetting: AnswerCheckSetting(
        period: AnswerCheckPeriod.values.byName(json['answerPeriod'] as String),
        customDate: customDate == null ? null : DateTime.parse(customDate),
      ),
      answerCheckStatus: AnswerCheckStatus.values.byName(
        json['answerCheckStatus'] as String,
      ),
      answerPrice: (json['answerPrice'] as num?)?.toDouble(),
      answerPriceDate: _parseNullableDate(json['answerPriceDate']),
      answerChangePercent: (json['answerChangePercent'] as num?)?.toDouble(),
      answeredAt: _parseNullableDate(json['answeredAt']),
    );
  }

  static DateTime? _parseNullableDate(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}

String skipReasonLabel(SkipReason reason) => switch (reason) {
  SkipReason.priceTooHigh => '高いと思った',
  SkipReason.expectingDrop => 'まだ下がりそう',
  SkipReason.marketConcern => '材料・地合いが不安',
  SkipReason.preserveFunds => '資金を温存したい',
  SkipReason.other => 'その他',
};

String answerCheckSettingLabel(AnswerCheckSetting setting) {
  final date = setting.customDate;
  if (setting.period == AnswerCheckPeriod.custom && date != null) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
  return switch (setting.period) {
    AnswerCheckPeriod.threeDays => '3日後',
    AnswerCheckPeriod.oneWeek => '1週間後',
    AnswerCheckPeriod.oneMonth => '1か月後',
    AnswerCheckPeriod.threeMonths => '3か月後',
    AnswerCheckPeriod.custom => 'カスタム',
  };
}
