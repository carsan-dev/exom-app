import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayuda'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text(
          'Ayuda',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
