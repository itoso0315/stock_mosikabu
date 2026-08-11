import '../models/stock_candidate.dart';

class StockSearchService {
  const StockSearchService({this.maxResults = 10});

  final int maxResults;

  List<StockCandidate> search(List<StockCandidate> candidates, String input) {
    final query = normalize(input);
    if (query.isEmpty) return const [];

    final matches = <({StockCandidate stock, int rank})>[];
    for (final stock in candidates) {
      final code = normalize(stock.code);
      final name = normalize(stock.name);
      final rank = switch ((code, name)) {
        _ when code == query => 0,
        _ when code.startsWith(query) => 1,
        _ when name.startsWith(query) => 2,
        _ when name.contains(query) => 3,
        _ => null,
      };
      if (rank != null) matches.add((stock: stock, rank: rank));
    }
    matches.sort((a, b) {
      final rankOrder = a.rank.compareTo(b.rank);
      return rankOrder != 0 ? rankOrder : a.stock.code.compareTo(b.stock.code);
    });
    return matches.take(maxResults).map((match) => match.stock).toList();
  }

  String normalize(String value) {
    final buffer = StringBuffer();
    for (var rune in value.trim().toLowerCase().runes) {
      if (rune == 0x3000 || _isWhitespace(rune)) continue;
      if (rune >= 0xFF01 && rune <= 0xFF5E) rune -= 0xFEE0;
      if (rune >= 0x30A1 && rune <= 0x30F6) rune -= 0x60;
      buffer.writeCharCode(rune);
    }
    return buffer.toString().replaceAll('富士', 'ふじ');
  }

  bool _isWhitespace(int rune) =>
      rune == 0x09 || rune == 0x0A || rune == 0x0D || rune == 0x20;
}
