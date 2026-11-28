import 'package:exom_app/features/feedback/presentation/inline_upload_status_scope.dart';
import 'package:flutter/material.dart';

/// Shows the app-wide feedback upload notices and remembers the ones it
/// showed, so a screen that reports upload state in line can close exactly
/// those (the current one and any queued behind it) without touching
/// SnackBars owned by other features.
class FeedbackNoticeSnackBars {
  FeedbackNoticeSnackBars._();

  static final List<_Entry> _entries = [];

  /// Shows [message] unless an inline-status screen is the current route.
  static void show(
    ScaffoldMessengerState messenger, {
    required String message,
    SnackBarAction? action,
  }) {
    if (InlineUploadStatusScope.isActive) return;
    final entry = _Entry();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: _NoticeContent(entry: entry, message: message),
        action: action,
      ),
    );
    entry.controller = controller;
    _entries.add(entry);
    controller.closed.whenComplete(() => _entries.remove(entry));
  }

  /// Closes every feedback notice: the visible one now, and the ones still
  /// queued in the messenger as soon as they become visible (a queued
  /// SnackBar cannot be removed before that).
  static void closeAll() {
    for (final entry in List<_Entry>.of(_entries)) {
      entry.cancelled = true;
      if (entry.visible) entry.close();
    }
  }
}

class _Entry {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  bool visible = false;
  bool cancelled = false;
  bool closeRequested = false;

  /// Closing twice would hide whichever SnackBar is current by then.
  void close() {
    if (closeRequested) return;
    closeRequested = true;
    controller?.close();
  }
}

/// The messenger only builds the SnackBar that is current, so mounting this
/// widget means the notice became visible.
class _NoticeContent extends StatefulWidget {
  const _NoticeContent({required this.entry, required this.message});

  final _Entry entry;
  final String message;

  @override
  State<_NoticeContent> createState() => _NoticeContentState();
}

class _NoticeContentState extends State<_NoticeContent> {
  @override
  void initState() {
    super.initState();
    widget.entry.visible = true;
    if (widget.entry.cancelled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.entry.close(),
      );
    }
  }

  @override
  void dispose() {
    widget.entry.visible = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.message);
}
