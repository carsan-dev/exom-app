import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Retos'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text(
          'Retos',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
