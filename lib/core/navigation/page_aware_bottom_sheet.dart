import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
