import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text(
          'Calendario',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
