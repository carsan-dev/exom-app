/// Registry of screens that already show the state of every feedback upload
/// in line. While one of them is the current route, the app-wide upload
/// notices are not shown as SnackBars (they would cover the page's own message
/// and, on narrow screens, its list and buttons).
///
/// Each screen registers a probe that is evaluated when a notice arrives, so a
/// route pushed on top of the screen stops the suppression.
class InlineUploadStatusScope {
  InlineUploadStatusScope._();

  static final List<bool Function()> _probes = [];

  static bool get isActive => _probes.any((probe) => probe());

  static void register(bool Function() isCurrent) => _probes.add(isCurrent);

  static void unregister(bool Function() isCurrent) =>
      _probes.remove(isCurrent);
}
