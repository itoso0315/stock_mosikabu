import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key, required this.onStart});

  // Replace only this path when a cat-only asset becomes available.
  static const catAssetPath = 'assets/images/cat_guide.png';

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Semantics(
                  label: 'もし株の白い猫キャラクター',
                  image: true,
                  child: Image.asset(
                    catAssetPath,
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'もし株',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '投資の答え合わせを、未来の自分と。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(flex: 2),
                Semantics(
                  button: true,
                  label: 'START',
                  child: InkWell(
                    key: const ValueKey('start-button'),
                    onTap: onStart,
                    borderRadius: BorderRadius.circular(32),
                    child: const SizedBox(
                      width: 200,
                      height: 64,
                      child: Center(
                        child: Text(
                          'START',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
