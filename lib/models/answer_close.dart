class AnswerClose {
  const AnswerClose({
    required this.code,
    required this.close,
    required this.priceDate,
  });

  final String code;
  final double close;
  final DateTime priceDate;

  factory AnswerClose.fromJson(Map<String, dynamic> json) => AnswerClose(
    code: json['code'] as String,
    close: (json['close'] as num).toDouble(),
    priceDate: DateTime.parse(json['priceDate'] as String),
  );
}
