import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    _Faq(
      question: '¿Cómo registro mi peso y medidas?',
      answer:
          'Ve a tu perfil y pulsa el botón "Registrar métricas". Podrás introducir tu peso, horas de sueño y medidas corporales. Los datos aparecerán en la gráfica de tu perfil.',
    ),
    _Faq(
      question: '¿Cómo marco un ejercicio como completado?',
      answer:
          'Entra en el entrenamiento del día desde la pantalla de inicio o la pestaña "Entrena". Pulsa el check junto a cada ejercicio para marcarlo como completado.',
    ),
    _Faq(
      question: '¿Para qué sirve el Recap Semanal?',
      answer:
          'El Recap es un formulario semanal para que puedas comunicar a tu entrenador cómo te ha ido la semana: nivel de esfuerzo, calidad de la nutrición, recuperación y estado de ánimo.',
    ),
    _Faq(
      question: '¿Cómo funciona el Calendario?',
      answer:
          'El Calendario muestra el estado diario de tus entrenamientos y dieta. Los puntos de colores indican si tienes actividad asignada (amarillo) o si ya la has completado (verde).',
    ),
    _Faq(
      question: '¿Qué es el Feedback de ejercicios?',
      answer:
          'Puedes enviar vídeos o imágenes de tu técnica para que tu entrenador los revise y te dé respuesta directamente desde la app.',
    ),
    _Faq(
      question: '¿Cómo desbloqueo logros?',
      answer:
          'Los logros se otorgan automáticamente cuando alcanzas ciertos hitos de entrenamiento. Tu entrenador también puede concederte logros manualmente.',
    ),
    _Faq(
      question: '¿Puedo usar la app sin conexión?',
      answer:
          'La app necesita conexión para cargar datos del servidor. Sin conexión se mostrarán los últimos datos cargados, pero no podrás actualizar tu progreso.',
    ),
    _Faq(
      question: '¿Cómo contacto con mi entrenador?',
      answer:
          'Usa la sección "Feedback" para enviar vídeos o imágenes con notas. Tu entrenador recibirá la notificación y podrá responderte desde el panel de administración.',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              'Preguntas frecuentes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ..._faqs.map((f) => _FaqTile(faq: f)),
        ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.4) : AppColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                        color: _expanded ? AppColors.primary : AppColors.textPrimary,
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
