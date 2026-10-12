import 'dart:async';
import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// The caller awaits route.completed before starting the canonical timer.
class ExecutionStartCountdown extends StatefulWidget {
  const ExecutionStartCountdown({super.key, required this.isValid, this.now});
  final bool Function() isValid;
  final DateTime Function()? now;

  @override
  State<ExecutionStartCountdown> createState() =>
      _ExecutionStartCountdownState();
}

class _ExecutionStartCountdownState extends State<ExecutionStartCountdown>
    with WidgetsBindingObserver {
  late final DateTime _deadline;
  Timer? _tick;
  ModalRoute<Object?>? _route;
  int _remaining = 5000;
  bool _closed = false;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _deadline = _now.add(const Duration(seconds: 5));
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _closed) return;
      if (!widget.isValid()) return _close(false);
      final remaining = _deadline
          .difference(_now)
          .inMilliseconds
          .clamp(0, 5000);
      if (remaining == 0) return _close(true);
      setState(() => _remaining = remaining);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<Object?>(context);
  }

  void _stop() {
    _closed = true;
    _tick?.cancel();
  }

  void _close(bool start) {
    if (_closed) return;
    final route = _route;
    _stop();
    // Back starts the reverse transition before this widget is disposed.
    // Never let a late deadline or lifecycle callback pop the workout below it.
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop(start);
    } else {
      // A covered preparation is interrupted, never a successful start.
      route.navigator?.removeRoute(route, false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close(false);
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = (_remaining / 1000).ceil();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _stop();
      },
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        child: Container(
          decoration: GlassDecoration.elevated(),
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.executionPrepareTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(l10n.executionPrepareBody, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Semantics(
                  liveRegion: true,
                  label: l10n.executionPrepareCountdown(seconds),
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 144,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _remaining / 5000,
                              strokeWidth: 4,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          FittedBox(
                            child: AnimatedSwitcher(
                              duration: reducedMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: Text(
                                '$seconds',
                                key: ValueKey(seconds),
                                style: theme.textTheme.displayMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => _close(false),
                  child: Text(l10n.executionPrepareCancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
