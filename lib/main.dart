import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalStorage.init();
  FlavorConfig.init(Flavor.dev);
  await initDependencies();
  await sl<FcmService>().init();
  runApp(const ExomApp());
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
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
