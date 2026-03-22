import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

const _devApiBaseUrlOverride = String.fromEnvironment('EXOM_API_BASE_URL');

enum Flavor { dev, staging, prod }

class FlavorConfig {
  final Flavor flavor;
  final String apiBaseUrl;

  FlavorConfig._({required this.flavor, required this.apiBaseUrl});

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    _instance ??= FlavorConfig._(
      flavor: Flavor.dev,
      apiBaseUrl: _fallbackDevBaseUrl,
    );
    return _instance!;
  }

  static String get _fallbackDevBaseUrl {
    if (_devApiBaseUrlOverride.isNotEmpty) {
      return _devApiBaseUrlOverride;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api/v1';
    }

    return 'http://localhost:3000/api/v1';
  }

  static Future<String> _resolveDevBaseUrl() async {
    if (_devApiBaseUrlOverride.isNotEmpty) {
      return _devApiBaseUrlOverride;
    }

    if (!Platform.isAndroid) {
      return 'http://localhost:3000/api/v1';
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.isPhysicalDevice) {
      return 'http://127.0.0.1:3000/api/v1';
    }

    return 'http://10.0.2.2:3000/api/v1';
  }

  static Future<String> _resolveApiBaseUrl(Flavor flavor) async {
    return switch (flavor) {
      Flavor.dev => _resolveDevBaseUrl(),
      Flavor.staging => Future.value('https://api-staging.exom.app/api/v1'),
      Flavor.prod => Future.value('https://api.exom.app/api/v1'),
    };
  }

  static Future<void> init(Flavor flavor) async {
    _instance = FlavorConfig._(
      flavor: flavor,
      apiBaseUrl: await _resolveApiBaseUrl(flavor),
    );
  }

  bool get isDev => flavor == Flavor.dev;
  bool get isProd => flavor == Flavor.prod;
}
