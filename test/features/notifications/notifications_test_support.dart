// Shared scaffolding for the L5-A1 «Avisos» tests: a scriptable repository, the
// real use cases and bloc registered in `sl`, and a routed app around
// NotificationsPage (the page needs a GoRouter for `canPop` and `push`).
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:exom_app/features/notifications/domain/usecases/delete_read_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_my_notifications_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/get_unread_count_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_all_notifications_as_read_usecase.dart';
import 'package:exom_app/features/notifications/domain/usecases/mark_notification_as_read_usecase.dart';
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:exom_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Scriptable in-memory repository.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository(this.items);

  List<NotificationEntity> items;
  bool failLoad = false;
  bool failMarkRead = false;
  Completer<void>? deleteGate;
  bool failDelete = false;
  int deleteReadCalls = 0;
  int markReadCalls = 0;
  int markAllReadCalls = 0;
  Duration loadDelay = Duration.zero;

  @override
  Future<NotificationsPageEntity> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    if (loadDelay > Duration.zero) await Future<void>.delayed(loadDelay);
    if (failLoad) throw Exception('load failed');
    return NotificationsPageEntity(
      items: List<NotificationEntity>.of(items),
      total: items.length,
      page: 1,
      limit: limit,
      totalPages: 1,
    );
  }

  @override
  Future<int> getUnreadCount() async =>
      items.where((item) => item.isUnread).length;

  @override
  Future<void> markAsRead(String id) async {
    markReadCalls++;
    if (failMarkRead) throw Exception('mark read failed');
  }

  @override
  Future<int> markAllAsRead() async {
    markAllReadCalls++;
    return 0;
  }

  @override
  Future<int> deleteRead() async {
    deleteReadCalls++;
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (failDelete) throw Exception('delete failed');
    items = items.where((item) => item.isUnread).toList();
    return 0;
  }
}

/// Fixed "now" of the page in these tests (a Friday at noon), so the day
/// groups and the relative times do not depend on when the suite runs.
final DateTime kNoticesNow = DateTime(2026, 11, 20, 12);

NotificationEntity notice(
  String id,
  String title,
  String body, {
  required bool unread,
  Duration age = const Duration(minutes: 5, seconds: 30),
  Map<String, dynamic>? data,
}) {
  final createdAt = kNoticesNow.subtract(age);
  return NotificationEntity(
    id: id,
    title: title,
    body: body,
    status: 'SENT',
    createdAt: createdAt,
    readAt: unread ? null : createdAt.add(const Duration(minutes: 1)),
    data: data,
  );
}

/// Two unread and three read notifications, one with a long title and body,
/// each with the `data.type` that picks its icon.
List<NotificationEntity> mainSceneItems() => [
  notice(
    'n1',
    'Nuevo plan de dieta',
    'Definición, 2.150 kcal, desde el lunes 23 de noviembre.',
    unread: true,
    data: {'type': 'diet'},
  ),
  notice(
    'n2',
    'Tu entrenador ha actualizado tu sesión de pierna y fuerza',
    'Hay un ejercicio nuevo: la sentadilla búlgara con pausa de dos segundos '
        'abajo.',
    unread: true,
    age: const Duration(minutes: 40),
    data: {'type': 'training'},
  ),
  notice(
    'n3',
    'Reto completado',
    '10.000 pasos al día: lo has conseguido esta semana.',
    unread: false,
    age: const Duration(hours: 3),
    data: {'type': 'challenge'},
  ),
  notice(
    'n4',
    'Tu resumen semanal está listo',
    'Revisa cómo ha ido la semana y cuéntale a tu entrenador qué tal te has '
        'sentido.',
    unread: false,
    age: const Duration(days: 1),
    data: {'type': 'recap'},
  ),
  notice(
    'n5',
    'Cambio en tu calendario',
    'Tu sesión del viernes 20 pasa al sábado 21.',
    unread: false,
    age: const Duration(days: 2),
    data: {'type': 'calendar'},
  ),
];

/// Registers the real bloc over [repository] in `sl` (reset first).
Future<void> registerNotificationsBloc(
  FakeNotificationsRepository repository,
) async {
  await sl.reset();
  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(
      getMyNotifications: GetMyNotificationsUseCase(repository),
      getUnreadCount: GetUnreadCountUseCase(repository),
      markAsRead: MarkNotificationAsReadUseCase(repository),
      markAllAsRead: MarkAllNotificationsAsReadUseCase(repository),
      deleteRead: DeleteReadNotificationsUseCase(repository),
    ),
  );
  addTearDown(sl.reset);
}

/// Pumps NotificationsPage at `/` of a router with a second route `/other`.
Future<GoRouter> pumpNotificationsPage(
  WidgetTester tester,
  FakeNotificationsRepository repository, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  bool settle = true,
  DateTime? now,
}) async {
  final pageNow = now ?? kNoticesNow;
  await loadRedesignFonts();
  await registerNotificationsBloc(repository);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => NotificationsPage(now: () => pageNow),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        GlassDecoration.brightness = Theme.of(context).brightness;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}
