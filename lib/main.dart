import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
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
  await initializeDateFormatting('es');
  await initializeDateFormatting('es_ES');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await LocalStorage.init();
  await FlavorConfig.init(Flavor.dev);
  await initDependencies();
  runApp(const ExomApp());
  unawaited(_initializeFcm());
  unawaited(_initializeOfflineSync());
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

class ExomApp extends StatelessWidget {
  const ExomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>()..add(const AuthCheckStatusRequested()),
      child: MaterialApp.router(
        title: 'EXOM',
        theme: AppTheme.dark,
        routerConfig: AppRouter.router,
        scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [
          Locale('es'),
          Locale('es', 'ES'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
