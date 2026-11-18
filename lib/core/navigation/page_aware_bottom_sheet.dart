import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Modal bottom sheet that closes itself when the router location changes
/// (e.g. a notification navigates away while it is open).
Future<T?> showPageAwareModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) async {
  final routerDelegate = GoRouter.of(context).routerDelegate;
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  var isClosingForRouteChange = false;

  void dismissOnRouteChange() {
    if (isClosingForRouteChange || !navigator.mounted || !navigator.canPop()) {
      return;
    }

    isClosingForRouteChange = true;
    navigator.pop();
  }

  routerDelegate.addListener(dismissOnRouteChange);

  try {
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  } finally {
    routerDelegate.removeListener(dismissOnRouteChange);
  }
}

/// Pushes [route] (a pageless modal such as `showExomSheet`'s route) and
/// closes it when the router location changes, with the same contract as
/// [showPageAwareModalBottomSheet]: the route is popped (animated) when it is
/// the current route, or removed when something else was pushed above it.
///
/// Without a [GoRouter] above [context] the route is simply pushed.
Future<T?> pushPageAwareRoute<T>(
  BuildContext context,
  Route<T> route, {
  bool useRootNavigator = false,
}) async {
  final routerDelegate = GoRouter.maybeOf(context)?.routerDelegate;
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  var isClosingForRouteChange = false;

  void dismissOnRouteChange() {
    if (isClosingForRouteChange || !navigator.mounted || !route.isActive) {
      return;
    }

    isClosingForRouteChange = true;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  routerDelegate?.addListener(dismissOnRouteChange);

  try {
    return await navigator.push<T>(route);
  } finally {
    routerDelegate?.removeListener(dismissOnRouteChange);
  }
}
