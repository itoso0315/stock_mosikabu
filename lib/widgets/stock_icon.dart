import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StockIcon extends StatelessWidget {
  const StockIcon({
    super.key,
    required this.companyName,
    required this.stockCode,
    this.size = 42,
  });

  final String companyName;
  final String stockCode;
  final double size;

  static final _companyPrefixes = RegExp(r'^(?:株式会社|（株）|\(株\)|㈱)\s*');

  @visibleForTesting
  static String displayCharacter({
    required String companyName,
    required String stockCode,
  }) {
    final normalizedName = companyName
        .trim()
        .replaceFirst(_companyPrefixes, '')
        .trim();
    final source = normalizedName.isNotEmpty
        ? normalizedName
        : stockCode.trim();
    if (source.isEmpty) return '?';
    final character = String.fromCharCode(source.runes.first);
    return RegExp(r'^[a-zA-Z]$').hasMatch(character)
        ? character.toUpperCase()
        : character;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.warmAccent,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      displayCharacter(companyName: companyName, stockCode: stockCode),
      maxLines: 1,
      style: TextStyle(
        color: AppColors.primaryDark,
        fontSize: size * 0.43,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}
