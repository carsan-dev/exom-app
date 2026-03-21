import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text(
          'Ajustes',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
