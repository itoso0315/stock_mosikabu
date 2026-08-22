class StockQuote {
  const StockQuote({
    required this.code,
    required this.name,
    required this.price,
    required this.fetchedAt,
  });

  final String code;
  final String name;
  final double price;
  final DateTime fetchedAt;

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    return StockQuote(
      code: json['code'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}
