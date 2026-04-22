import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/injection_container.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExomBootstrapApp());

  try {
    await _bootstrap().timeout(const Duration(seconds: 20));
    runApp(const ExomApp());
    unawaited(_initializeFcm());
    unawaited(_initializeOfflineSync());
  } catch (error, stackTrace) {
    debugPrint('[BOOTSTRAP] Failed to start EXOM: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(ExomBootstrapErrorApp(error: error.toString()));
  }
}

Future<void> _bootstrap() async {
  await Future.wait([
    initializeDateFormatting('es'),
    initializeDateFormatting('es_ES'),
    initializeDateFormatting('en'),
    initializeDateFormatting('en_US'),
  ]);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await LocalStorage.init();
  await FlavorConfig.init(FlavorConfig.initialFlavor);
  await initDependencies();
}

Future<void> _initializeFcm() async {
  try {
    await sl<FcmService>().init();
  } catch (error) {
    debugPrint('[FCM] Initialization failed: $error');
  }
}

Future<void> _initializeOfflineSync() async {
  try {
    await sl<OfflineSyncService>().init();
  } catch (error) {
    debugPrint('[SYNC] Initialization failed: $error');
  }
}

class ExomBootstrapApp extends StatelessWidget {
  const ExomBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BootstrapScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EXOM',
              style: TextStyle(
                color: Color(0xFFD7F58A),
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            SizedBox(height: 18),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD7F58A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExomBootstrapErrorApp extends StatelessWidget {
  const ExomBootstrapErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BootstrapScaffold(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'EXOM',
                style: TextStyle(
                  color: Color(0xFFD7F58A),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No se pudo iniciar la app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFB8AE9F), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF241209),
      body: Center(child: child),
    );
  }
}

class ExomApp extends StatelessWidget {
  const ExomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AppPreferencesCubit>()),
        BlocProvider(
          create: (_) => sl<AuthBloc>()..add(const AuthCheckStatusRequested()),
        ),
      ],
      child: const _ExomAppView(),
    );
  }
}

class _ExomAppView extends StatelessWidget {
  const _ExomAppView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
      builder: (context, state) {
        return MaterialApp.router(
          title: 'EXOM',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          routerConfig: AppRouter.router,
          scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          locale: state.locale, // null → system locale
          supportedLocales: AppPreferencesDefaults.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) {
            // Sync glass decoration brightness with the active theme so
            // static GlassDecoration.* factories pick the right tokens.
            GlassDecoration.brightness = Theme.of(context).brightness;
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
