import 'package:flutter/material.dart';

import '../../../core/theme/wnt_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/wnt_app.png', width: 104, height: 104),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: WntColors.brand),
          ],
        ),
      ),
    );
  }
}
