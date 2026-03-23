import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    _Faq(
      question: '¿Como registro mi peso, masa muscular y medidas?',
      answer:
          'Ve a tu perfil y entra en "Mis métricas". Desde ahi puedes guardar peso, masa muscular, horas de sueño y medidas corporales. Si no tienes una medicion directa de masa muscular, puedes usar la calculadora SEEN con edad, altura, sexo y pantorrilla para obtener una estimacion.',
    ),
    _Faq(
      question: '¿Como marco un entrenamiento como completado?',
      answer:
          'Entra en el entrenamiento del dia desde Home o desde Entrenamientos. Puedes marcar ejercicios uno a uno o completar la sesion completa desde el resumen final.',
    ),
    _Faq(
      question: '¿Como marco una comida como completada?',
      answer:
          'Abre la dieta del dia, entra en la comida correspondiente y pulsa el boton de completado. El Home y el Calendario reflejaran el avance real del dia.',
    ),
    _Faq(
      question: '¿Puedo usar la app sin conexion?',
      answer:
          'Si. La app conserva en cache el ultimo Home, Perfil, Calendario, Dieta, Entreno y Metricas cargados. Sin conexion puedes consultar esos datos, aunque no se enviaran cambios al servidor.',
    ),
    _Faq(
      question: '¿Para que sirve el ReCap semanal?',
      answer:
          'El ReCap te permite resumir tu semana para que tu entrenador entienda como has rendido, comido, descansado y que sensaciones has tenido.',
    ),
    _Faq(
      question: '¿Como contacto con mi entrenador o reporto un problema?',
      answer:
          'Usa la seccion Feedback para enviar dudas, incidencias o material tecnico. Es el canal principal dentro de la app para que tu entrenador o el equipo de soporte puedan darte seguimiento.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayuda'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro de ayuda',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Todo lo importante para usar EXOM en tu dia a dia: metricas, entrenamientos, dieta, modo offline y vias de contacto.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.feedback_outlined,
                  title: 'Feedback',
                  subtitle: 'Enviar duda o incidencia',
                  onTap: () => context.push(AppRoutes.feedback),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.settings_outlined,
                  title: 'Ajustes',
                  subtitle: 'Notificaciones y caché',
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Preguntas frecuentes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FaqTile(faq: faq)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creditos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Producto EXOM. App movil en Flutter, backend en NestJS, autenticacion con Firebase y datos en Supabase.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;

  const _Faq({required this.question, required this.answer});
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;

  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: TextStyle(
                        color: _expanded
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Text(
                  widget.faq.answer,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
