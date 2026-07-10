import 'package:flutter/foundation.dart';

class NotificationNavigationCoordinator extends ChangeNotifier {
  String? _pendingRoute;

  String? get pendingRoute => _pendingRoute;

  void enqueue(String route) {
    _pendingRoute = route;
    notifyListeners();
  }

  bool consumeIfReady({
    required bool isReady,
    required ValueChanged<String> navigate,
  }) {
    final route = _pendingRoute;
    if (!isReady || route == null) return false;
    _pendingRoute = null;
    navigate(route);
    return true;
  }
}
