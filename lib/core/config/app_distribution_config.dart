enum AppUpdateStatus { upToDate, recommendedUpdate, requiredUpdate }

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.status,
    required this.currentVersion,
    required this.currentBuild,
    this.latestVersion = '',
    this.storeUrl = '',
    this.title = '',
    this.message = '',
  });

  final AppUpdateStatus status;
  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final String storeUrl;
  final String title;
  final String message;

  bool get shouldPrompt => status != AppUpdateStatus.upToDate;
  bool get isBlocking => status == AppUpdateStatus.requiredUpdate;
  String get currentVersionLabel => '$currentVersion ($currentBuild)';
}
