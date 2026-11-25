import 'dart:async';

import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/widgets/recap_sunday_prompt_dialog.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:flutter/material.dart';

/// Reads the current session; `null` while there is none or the onboarding
/// is not settled yet (the layer tries again on a later build).
typedef AutomaticPromptSessionReader = AutomaticPromptSession? Function();

/// Stack layer of the shell that opens at most one automatic prompt (quick
/// tour or Sunday recap reminder) after the first frame on /home.
class AutomaticPromptLayer extends StatefulWidget {
  const AutomaticPromptLayer({
    super.key,
    required this.coordinator,
    required this.active,
    required this.readSession,
    required this.onStartTutorial,
    required this.onOpenRecap,
  });

  final AutomaticPromptCoordinator coordinator;

  /// The shell is on /home: the only place where prompts are checked.
  final bool active;
  final AutomaticPromptSessionReader readSession;
  final VoidCallback onStartTutorial;
  final VoidCallback onOpenRecap;

  @override
  State<AutomaticPromptLayer> createState() => _AutomaticPromptLayerState();
}

class _AutomaticPromptLayerState extends State<AutomaticPromptLayer> {
  bool _checked = false;
  AutomaticPrompt _visible = AutomaticPrompt.none;
  AutomaticPromptSession? _session;
  bool _dontShowAgain = false;

  Future<void> _check() async {
    if (!mounted || _checked || !widget.active) return;
    final session = widget.readSession();
    if (session == null) return;
    _checked = true;

    bool stillCurrent() =>
        mounted && widget.active && widget.readSession()?.uid == session.uid;

    AutomaticPrompt prompt;
    try {
      prompt = await widget.coordinator.nextPrompt(
        uid: session.uid,
        email: session.email,
        tutorialDue: session.tutorialDue,
        isStillCurrent: stillCurrent,
      );
    } catch (_) {
      // Storage failure: no prompt this time.
      return;
    }
    if (!mounted) return;
    if (prompt == AutomaticPrompt.none) {
      // The check went stale (left /home or another user mid-fetch): check
      // again the next time this shell is on /home.
      if (!stillCurrent()) _checked = false;
      return;
    }
    setState(() {
      _session = session;
      _visible = prompt;
      _dontShowAgain = false;
    });
  }

  /// Hides the prompt; returns the session and checkbox value it had.
  (AutomaticPromptSession, bool)? _close() {
    final session = _session;
    final dontShowAgain = _dontShowAgain;
    setState(() {
      _visible = AutomaticPrompt.none;
      _session = null;
      _dontShowAgain = false;
    });
    return session == null ? null : (session, dontShowAgain);
  }

  void _startTutorial() {
    _close();
    widget.onStartTutorial();
  }

  void _skipTutorial() {
    final closed = _close();
    if (closed == null) return;
    final (session, dontShowAgain) = closed;
    unawaited(
      _persist(
        widget.coordinator.resolveTutorialSkip(
          uid: session.uid,
          email: session.email,
          dontShowAgain: dontShowAgain,
        ),
      ),
    );
  }

  void _resolveRecap({required bool open}) {
    final closed = _close();
    if (open) widget.onOpenRecap();
    if (closed == null) return;
    final (session, dontShowAgain) = closed;
    unawaited(
      _persist(
        widget.coordinator.resolveRecapSundayPrompt(
          uid: session.uid,
          email: session.email,
          dontShowAgain: dontShowAgain,
        ),
      ),
    );
  }

  /// A failed local write only means the prompt may come back; it must not
  /// surface as an uncaught error.
  Future<void> _persist(Future<void> write) async {
    try {
      await write;
    } catch (_) {}
  }

  void _setDontShowAgain(bool value) => setState(() => _dontShowAgain = value);

  @override
  Widget build(BuildContext context) {
    if (widget.active && !_checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
    return switch (_visible) {
      AutomaticPrompt.none => const SizedBox.shrink(),
      AutomaticPrompt.tutorial => TutorialPromptDialog(
        onStart: _startTutorial,
        onSkip: _skipTutorial,
        dontShowAgain: _dontShowAgain,
        onDontShowAgainChanged: _setDontShowAgain,
      ),
      AutomaticPrompt.recapSunday => RecapSundayPromptDialog(
        onFill: () => _resolveRecap(open: true),
        onSkip: () => _resolveRecap(open: false),
        dontShowAgain: _dontShowAgain,
        onDontShowAgainChanged: _setDontShowAgain,
      ),
    };
  }
}
