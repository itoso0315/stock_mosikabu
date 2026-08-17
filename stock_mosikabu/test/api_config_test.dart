import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/config/api_config.dart';

void main() {
  test('iOSは公開済みRender Backendを使う', () {
    expect(
      ApiConfig.defaultForPlatform(TargetPlatform.iOS),
      'https://stock-mosikabu-api.onrender.com',
    );
  });

  test('Android Emulatorは10.0.2.2を使う', () {
    expect(
      ApiConfig.defaultForPlatform(TargetPlatform.android),
      'http://10.0.2.2:8000',
    );
  });

  test('明示URLを優先し末尾スラッシュを除去する', () {
    expect(
      ApiConfig.resolve('http://192.168.1.20:9000/'),
      'http://192.168.1.20:9000',
    );
  });
}
