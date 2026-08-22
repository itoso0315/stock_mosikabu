import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalStockLinkService {
  Uri yahooFinanceUri(String stockCode);
  Future<bool> openYahooFinance(String stockCode);
}

class YahooFinanceLinkService implements ExternalStockLinkService {
  const YahooFinanceLinkService();

  @override
  Uri yahooFinanceUri(String stockCode) {
    return Uri.https(
      'finance.yahoo.co.jp',
      '/quote/${stockCode.toUpperCase()}.T',
    );
  }

  @override
  Future<bool> openYahooFinance(String stockCode) {
    return launchUrl(
      yahooFinanceUri(stockCode),
      mode: LaunchMode.externalApplication,
    );
  }
}
