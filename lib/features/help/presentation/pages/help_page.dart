import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  List<_Faq> _faqs(BuildContext context) {
    return [
      _Faq(
        question: context.copy(
          '¿Cómo registro mi peso, masa muscular y medidas?',
          'How do I log my weight, muscle mass, and measurements?',
        ),
        answer: context.copy(
          'Ve a tu perfil y entra en "Mis métricas". Desde ahí puedes guardar peso, masa muscular, horas de sueño y medidas corporales. Si no tienes una medición directa de masa muscular, puedes usar la calculadora SEEN con edad, altura, sexo y pantorrilla para obtener una estimación.',
          'Go to your profile and open "My metrics". There you can save weight, muscle mass, sleep hours, and body measurements. If you do not have a direct muscle-mass measurement, you can use the SEEN calculator with age, height, sex, and calf size to get an estimate.',
        ),
      ),
      _Faq(
        question: context.copy(
          '¿Cómo marco un entrenamiento como completado?',
          'How do I mark a workout as completed?',
        ),
        answer: context.copy(
          'Entra en el entrenamiento del día desde Home o desde Entrenamientos. Puedes marcar ejercicios uno a uno o completar la sesión completa desde el resumen final.',
          'Open the day\'s workout from Home or from Trainings. You can mark exercises one by one or complete the entire session from the final summary.',
        ),
      ),
      _Faq(
        question: context.copy(
          '¿Cómo marco una comida como completada?',
          'How do I mark a meal as completed?',
        ),
        answer: context.copy(
          'Abre la dieta del día, entra en la comida correspondiente y pulsa el botón de completado. El Home y el Calendario reflejará el avance real del día.',
          'Open the day\'s diet, enter the corresponding meal, and tap the complete button. Home and Calendar will reflect the actual progress for the day.',
        ),
      ),
      _Faq(
        question: context.copy(
          '¿Puedo usar la app sin conexión?',
          'Can I use the app offline?',
        ),
        answer: context.copy(
          'Sí. La app conserva en caché el último Home, Perfil, Calendario, Dieta, Entreno y Métricas cargados. Sin conexión puedes consultar esos datos, aunque no se enviarán cambios al servidor.',
          'Yes. The app caches the latest loaded Home, Profile, Calendar, Diet, Training, and Metrics. Offline you can review that data, although changes will not be sent to the server.',
        ),
      ),
      _Faq(
        question: context.copy(
          '¿Para qué sirve el ReCap semanal?',
          'What is the weekly recap for?',
        ),
        answer: context.copy(
          'El ReCap te permite resumir tu semana para que tu entrenador entienda cómo has rendido, comido, descansado y qué sensaciones has tenido.',
          'The recap lets you summarize your week so your coach understands how you performed, ate, rested, and how you felt.',
        ),
      ),
      _Faq(
        question: context.copy(
          '¿Cómo contacto con mi entrenador o reporto un problema?',
          'How do I contact my coach or report an issue?',
        ),
        answer: context.copy(
          'Usa la sección Feedback para enviar dudas, incidencias o material técnico. Es el canal principal dentro de la app para que tu entrenador o el equipo de soporte puedan darte seguimiento.',
          'Use the Feedback section to send questions, issues, or technical material. It is the main in-app channel for your coach or the support team to follow up with you.',
        ),
      ),
    ];
  }

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri,
    String errorMessage,
  ) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.copy('Ayuda', 'Help')),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.copy('Centro de ayuda', 'Help center'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.copy(
                    'Todo lo importante para usar EXOM en tu día a día: métricas, entrenamientos, dieta, modo offline y vías de contacto.',
                    'Everything important to use EXOM day to day: metrics, training, diet, offline mode, and contact options.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
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
                  title: context.copy('Feedback', 'Feedback'),
                  subtitle: context.copy(
                    'Enviar duda o incidencia',
                    'Send a question or issue',
                  ),
                  onTap: () => context.push(AppRoutes.feedback),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.settings_outlined,
                  title: context.copy('Ajustes', 'Settings'),
                  subtitle: context.copy(
                    'Notificaciones y caché',
                    'Notifications and cache',
                  ),
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.copy('Soporte y enlaces', 'Support and links'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpLinkTile(
                  icon: Icons.support_agent_outlined,
                  title: context.copy('Centro de soporte', 'Support center'),
                  subtitle: context.copy(
                    'Abre la página externa de soporte y contacto de EXOM.',
                    'Open EXOM\'s external support and contact page.',
                  ),
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.supportPage,
                    context.copy(
                      'No se pudo abrir la página de soporte.',
                      'Could not open the support page.',
                    ),
                  ),
                ),
                _HelpLinkTile(
                  icon: Icons.privacy_tip_outlined,
                  title: context.copy(
                    'Política de privacidad',
                    'Privacy policy',
                  ),
                  subtitle: context.copy(
                    'Consulta cómo se gestionan tus datos y privacidad.',
                    'See how your data and privacy are handled.',
                  ),
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.privacyPolicy,
                    context.copy(
                      'No se pudo abrir la política de privacidad.',
                      'Could not open the privacy policy.',
                    ),
                  ),
                ),
                _HelpLinkTile(
                  icon: Icons.alternate_email,
                  title: context.copy('Escribir a soporte', 'Email support'),
                  subtitle: context.copy(
                    'Abre tu cliente de correo con un email a soporte@exom.app.',
                    'Open your mail client with an email to soporte@exom.app.',
                  ),
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.supportEmail,
                    context.copy(
                      'No se pudo abrir la aplicación de correo.',
                      'Could not open the mail app.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.copy('Preguntas frecuentes', 'Frequently asked questions'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._faqs(context).map((faq) => _FaqTile(faq: faq)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.copy('Créditos', 'Credits'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.copy(
                    'Producto EXOM de valor añadido para clientes. Desarrollo principal por Carlos Sánchez Román, con app móvil en Flutter y backend en NestJS.',
                    'EXOM product created as added value for clients. Main development by Carlos Sanchez Roman, with a Flutter mobile app and NestJS backend.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpLinkTile(
                  icon: Icons.code,
                  title: context.copy('Desarrollador', 'Developer'),
                  subtitle: 'Carlos Sanchez Roman · github.com/carsan-dev',
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.developerGithub,
                    context.copy(
                      'No se pudo abrir el perfil de GitHub.',
                      'Could not open the GitHub profile.',
                    ),
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
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: palette.primary, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDisabled,
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

class _HelpLinkTile extends StatelessWidget {
  const _HelpLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: palette.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textDisabled,
          fontSize: 12,
        ),
      ),
      trailing: Icon(Icons.open_in_new, color: palette.textDisabled, size: 18),
      onTap: onTap,
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? palette.primary.withValues(alpha: 0.4)
              : palette.divider,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _expanded
                            ? palette.primary
                            : palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: palette.textDisabled,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Text(
                  widget.faq.answer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
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
