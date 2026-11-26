import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/navigation/notification_navigation_coordinator.dart';
import 'package:exom_app/core/navigation/notification_route_utils.dart';
import 'package:exom_app/core/onboarding/onboarding_readers.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/services/local_notification_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_launch_symbol.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_service_starter.dart';
import 'package:exom_app/core/services/fcm_service.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_session.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImageCache();
  await showBootstrapSplash();
  // L5-D3 r3 (D3-E1): the splash's first frame draws this decoded symbol.
  final launchSymbol = precacheLaunchSymbol();

  try {
    await _bootstrap().timeout(const Duration(seconds: 20));
    await launchSymbol.timeout(_launchSymbolCap, onTimeout: () {});
    runApp(const ExomApp());
  } catch (error, stackTrace) {
    debugPrint('[BOOTSTRAP] Failed to start EXOM: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(ExomBootstrapErrorApp(error: error.toString()));
  }
}

/// Longest the native splash may be held for the symbol to be ready.
const Duration _bootstrapSymbolCap = Duration(milliseconds: 500);

/// Loader [ExomBrandSymbol] builds on the bootstrap screen for [brightness]
/// (default: the platform's, as the screen follows the system like the native
/// splash; symbol height [ExomLaunchSymbol.height]); same cache key as the
/// widget's.
@visibleForTesting
SvgAssetLoader bootstrapSymbolLoader([Brightness? brightness]) {
  return ExomLaunchSymbol.loaderFor(
    brightness ?? WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );
}

/// AppTheme.light/dark are pure static getters (no DI, no async), so they are
/// safe before bootstrap and give the brand widgets their palette.
ThemeData _bootstrapTheme(Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;

/// Loads the recoloured symbol into flutter_svg's cache so the first
/// [ExomBootstrapApp] build finds the bytes without waiting for the asset.
@visibleForTesting
Future<void> precacheBootstrapSymbol() async {
  await bootstrapSymbolLoader().loadBytes(null);
}

/// Shows [ExomBootstrapApp] with the symbol already painted in the first
/// frame: the first frame is deferred (the native splash stays) until the
/// symbol is cached and has had two frames to resolve, capped at 500 ms in
/// total. Any failure or the cap lets the first frame through anyway.
@visibleForTesting
Future<void> showBootstrapSplash({
  Duration cap = _bootstrapSymbolCap,
  void Function(Widget app) run = runApp,
}) async {
  final binding = WidgetsBinding.instance;
  final clock = Stopwatch()..start();
  binding.deferFirstFrame();
  try {
    try {
      await precacheBootstrapSymbol().timeout(cap);
    } catch (error) {
      debugPrint('[BOOTSTRAP] Symbol precache skipped: $error');
    }
    run(const ExomBootstrapApp());
    final left = cap - clock.elapsed;
    if (left > Duration.zero) {
      // The deferred frames still build, so the picture resolves meanwhile.
      await (() async {
        await binding.endOfFrame;
        await binding.endOfFrame;
      })().timeout(left);
    }
  } catch (error) {
    debugPrint('[BOOTSTRAP] Symbol wait ended early: $error');
  } finally {
    binding.allowFirstFrame();
  }
}

/// Longest [main] waits for [precacheLaunchSymbol] once the rest of the
/// bootstrap is done.
const Duration _launchSymbolCap = Duration(milliseconds: 300);

/// Decodes the launch symbol the splash draws on its first frame (L5-D3 r3,
/// D3-E1): without it that frame showed the background alone while the
/// splash's own symbol was decoded. [main] starts it while the bootstrap
/// screen is up, together with the bootstrap. Never throws.
@visibleForTesting
Future<void> precacheLaunchSymbol() async {
  try {
    await ExomLaunchSymbol.precachePictures();
  } catch (error) {
    debugPrint('[BOOTSTRAP] Launch symbol skipped: $error');
  }
}

void _configureImageCache() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20;
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

Future<void> _initializeFeedbackUploads() async {
  try {
    await sl<FeedbackUploadQueueService>().init();
  } catch (error) {
    debugPrint('[FEEDBACK] Queue initialization failed: $error');
  }
}

Future<void> _initializeProgressPhotoUploads() async {
  try {
    await sl<ProgressPhotoUploadQueueService>().init();
  } catch (error) {
    debugPrint('[PROGRESS_PHOTOS] Queue initialization failed: $error');
  }
}

const double _bootstrapIndicatorSize = 24;
const double _bootstrapIndicatorGap = 32;
const Duration _bootstrapIndicatorDelay = Duration(milliseconds: 300);
const Duration _bootstrapIndicatorFade = Duration(milliseconds: 200);

/// Exact continuation of the native splash: the symbol at the screen centre
/// (insets ignored, geometry in [ExomLaunchSymbol]). Like the native splash it
/// follows the system brightness (carbon in dark, paper in light), not the
/// theme chosen in the app, which is not loaded yet. A progress indicator
/// appears only after 300 ms.
class ExomBootstrapApp extends StatelessWidget {
  const ExomBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _bootstrapTheme(Brightness.light),
      darkTheme: _bootstrapTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _BootstrapScaffold(child: _BootstrapSplash()),
    );
  }
}

class _BootstrapSplash extends StatefulWidget {
  const _BootstrapSplash();

  @override
  State<_BootstrapSplash> createState() => _BootstrapSplashState();
}

class _BootstrapSplashState extends State<_BootstrapSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _bootstrapIndicatorFade,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(_bootstrapIndicatorDelay, () {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
      } else {
        _fade.forward();
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight / 2;
        return Stack(
          children: [
            const Center(
              child: ExomBrandSymbol(height: ExomLaunchSymbol.height),
            ),
            Positioned(
              left: 0,
              right: 0,
              top:
                  centerY +
                  ExomLaunchSymbol.height / 2 +
                  _bootstrapIndicatorGap,
              child: Align(
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  key: const ValueKey<String>('bootstrap-progress-fade'),
                  opacity: _opacity,
                  child: SizedBox(
                    width: _bootstrapIndicatorSize,
                    height: _bootstrapIndicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.exomPalette.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExomBootstrapErrorApp extends StatelessWidget {
  const ExomBootstrapErrorApp({super.key, required this.error});

  /// Technical detail; logged by the caller and never rendered.
  final String error;

  /// The bootstrap UI has no selected locale yet, so it follows the device.
  String _bootstrapMessage() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final locale = AppLocalizations.delegate.isSupported(deviceLocale)
        ? deviceLocale
        : const Locale('es');
    return lookupAppLocalizations(locale).bootstrapErrorMessage;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _BootstrapScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExomBrandLogo(height: 40),
                const SizedBox(height: 20),
                Text(
                  _bootstrapMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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

/// Dark bootstrap bars: transparent status bar, carbon navigation bar, light
/// icons on both.
@visibleForTesting
const SystemUiOverlayStyle bootstrapSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.background,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// Bootstrap bars for [brightness]: [bootstrapSystemUiStyle] in dark; in light
/// a transparent status bar, paper navigation bar and dark icons on both.
SystemUiOverlayStyle bootstrapSystemUiStyleFor(Brightness brightness) {
  if (brightness == Brightness.dark) return bootstrapSystemUiStyle;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: _bootstrapTheme(
      brightness,
    ).extension<ExomThemePalette>()!.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}

/// Scaffold of the bootstrap screens, in the palette of the ambient theme.
class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: bootstrapSystemUiStyleFor(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: context.exomPalette.background,
        resizeToAvoidBottomInset: false,
        body: child,
      ),
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

class _ExomAppView extends StatefulWidget {
  const _ExomAppView();

  @override
  State<_ExomAppView> createState() => _ExomAppViewState();
}

class _ExomAppViewState extends State<_ExomAppView> {
  StreamSubscription<FeedbackUploadNotice>? _feedbackSubscription;
  final _feedbackNoticeSession = FeedbackNoticeSession(
    sessionKey: currentSessionOwnerKey,
  );
  late final NotificationNavigationCoordinator _notificationNavigation;
  late final ValidatedSessionServiceStarter _authenticatedServices;

  @override
  void initState() {
    super.initState();
    _authenticatedServices = ValidatedSessionServiceStarter([
      _initializeFcm,
      _initializeOfflineSync,
      _initializeFeedbackUploads,
      _initializeProgressPhotoUploads,
    ]);
    _feedbackSubscription = sl<FeedbackUploadQueueService>().notices.listen(
      _showFeedbackNotice,
    );
    _notificationNavigation =
        sl<LocalNotificationService>().navigationCoordinator
          ..addListener(_schedulePendingNotification);
    _schedulePendingNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedbackNoticeSession.handle(context.read<AuthBloc>().state);
      _authenticatedServices.handle(context.read<AuthBloc>().state);
    });
  }

  void _schedulePendingNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) return;
      final session = sl<FirebaseAuthService>().currentSession;
      if (session == null) return;
      final resolution = resolveOnboardingForSession(
        authState: authState,
        session: session,
        storage: sl<LocalStorage>(),
      );
      final location = AppRouter.router.routeInformationProvider.value.uri.path;
      final isRouterReady = isNotificationNavigationReady(
        resolution: resolution,
        location: location,
      );
      _notificationNavigation.consumeIfReady(
        isReady: isRouterReady,
        navigate: (route) {
          if (shouldPushNotificationRoute(route)) {
            AppRouter.router.push(route);
          } else {
            AppRouter.router.go(route);
          }
        },
      );
    });
  }

  void _showFeedbackNotice(FeedbackUploadNotice notice) {
    if (!_feedbackNoticeSession.acceptsNotices) return;
    if (notice.kind == FeedbackUploadNoticeKind.preparing ||
        notice.kind == FeedbackUploadNoticeKind.uploading ||
        notice.kind == FeedbackUploadNoticeKind.processing ||
        notice.kind == FeedbackUploadNoticeKind.discarded) {
      return;
    }
    final messenger = AppRouter.scaffoldMessengerKey.currentState;
    final context = AppRouter.scaffoldMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final l10n = AppLocalizations.of(context);
    final isFailure = notice.kind == FeedbackUploadNoticeKind.failed;
    final retry = _feedbackNoticeSession.guardRetry(
      sl<FeedbackUploadQueueService>().retry,
    );
    final message = switch (notice.kind) {
      FeedbackUploadNoticeKind.queued => l10n.feedbackQueued,
      FeedbackUploadNoticeKind.completed => l10n.feedbackSentSuccessfully,
      FeedbackUploadNoticeKind.failed => l10n.feedbackUploadFailed,
      FeedbackUploadNoticeKind.uploading => l10n.feedbackQueued,
      FeedbackUploadNoticeKind.processing => l10n.feedbackQueued,
      FeedbackUploadNoticeKind.preparing => l10n.feedbackQueued,
      FeedbackUploadNoticeKind.discarded => l10n.feedbackQueued,
    };
    FeedbackNoticeSnackBars.show(
      messenger,
      message: message,
      action: isFailure
          ? SnackBarAction(
              label: l10n.retry,
              textColor: Theme.of(context).colorScheme.inversePrimary,
              onPressed: () =>
                  unawaited(retry(notice.id)),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _feedbackSubscription?.cancel();
    _notificationNavigation.removeListener(_schedulePendingNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedulePendingNotification();
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _feedbackNoticeSession.handle(state);
        _authenticatedServices.handle(state);
        AppRouter.router.refresh();
        _schedulePendingNotification();
      },
      child: BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
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
      ),
    );
  }
}
