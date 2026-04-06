import 'package:flutter/material.dart';

class TrialExpiredScreen extends StatelessWidget {
  final VoidCallback? onContactTrainer;
  final VoidCallback? onLogout;

  const TrialExpiredScreen({
    super.key,
    this.onContactTrainer,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule_outlined,
                    color: Color(0xFFFFB300),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tu periodo de prueba ha finalizado',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Has disfrutado de 14 días de acceso. Para seguir usando EXOM, contacta con tu entrenador.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                if (onContactTrainer != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onContactTrainer,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Contactar entrenador'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (onLogout != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onLogout,
                      child: const Text('Cerrar sesión'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
