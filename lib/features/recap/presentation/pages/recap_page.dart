import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class RecapPage extends StatelessWidget {
  const RecapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recap Semanal'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text(
          'Recap Semanal',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
