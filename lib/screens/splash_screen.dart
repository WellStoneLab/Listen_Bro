import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const String logoAsset = 'assets/images/WellStoneLab_logo.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              logoAsset,
              width: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '聞いてよ！マスター',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
