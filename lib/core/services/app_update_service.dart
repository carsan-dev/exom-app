import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/models/mobile_app_config_model.dart';

class AppUpdateService {
  AppUpdateService(this._apiClient, this._packageInfo);

  final ApiClient _apiClient;
  final PackageInfo _packageInfo;

  String get currentVersionLabel =>
      '${_packageInfo.version} ($_currentBuildNumber)';

  Future<AppUpdateDecision> checkForUpdates() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return _upToDateDecision();
    }

    try {
      final config = await _apiClient
          .get<MobileAppConfigModel>(
            '/public/mobile-config',
            fromJson: MobileAppConfigModel.fromJson,
          )
          .timeout(const Duration(seconds: 4));

      final isAndroid = Platform.isAndroid;
      final minBuild = isAndroid ? config.minAndroidBuild : config.minIosBuild;
      final recommendedBuild = isAndroid
          ? config.recommendedAndroidBuild
          : config.recommendedIosBuild;
      final latestVersion = isAndroid
          ? config.latestAndroidVersion
          : config.latestIosVersion;
      final forceUpdate = isAndroid
          ? config.forceAndroidUpdate
          : config.forceIosUpdate;
      final storeUrl = isAndroid ? config.androidStoreUrl : config.iosStoreUrl;

      final status = _resolveStatus(
        minBuild: minBuild,
        recommendedBuild: recommendedBuild,
        forceUpdate: forceUpdate,
      );

      if (status == AppUpdateStatus.upToDate) {
        return _upToDateDecision(latestVersion: latestVersion);
      }

      return AppUpdateDecision(
        status: status,
        currentVersion: _packageInfo.version,
        currentBuild: _currentBuildNumber,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
        title: config.updateTitle,
        message: config.updateMessage,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[APP_UPDATE] Skipping update check: $error');
      }
      return _upToDateDecision();
    }
  }

  Future<bool> openStore(AppUpdateDecision decision) async {
    if (decision.storeUrl.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(decision.storeUrl);
    if (uri == null) {
      return false;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      return true;
    }

    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  int get _currentBuildNumber => int.tryParse(_packageInfo.buildNumber) ?? 0;

  AppUpdateStatus _resolveStatus({
    required int minBuild,
    required int recommendedBuild,
    required bool forceUpdate,
  }) {
    if (_currentBuildNumber < minBuild) {
      return AppUpdateStatus.requiredUpdate;
    }

    if (_currentBuildNumber < recommendedBuild) {
      return forceUpdate
          ? AppUpdateStatus.requiredUpdate
          : AppUpdateStatus.recommendedUpdate;
    }

    return AppUpdateStatus.upToDate;
  }

  AppUpdateDecision _upToDateDecision({String latestVersion = ''}) {
    return AppUpdateDecision(
      status: AppUpdateStatus.upToDate,
      currentVersion: _packageInfo.version,
      currentBuild: _currentBuildNumber,
      latestVersion: latestVersion,
    );
  }
}
