import 'package:flutter/material.dart';

/// Guide character asset, kept behind a widget for easy future replacement.
class CatPlaceholder extends StatelessWidget {
  const CatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '猫キャラクター',
      image: true,
      child: Image.asset(
        'assets/images/cat_guide.png',
        width: 118,
        height: 126,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
