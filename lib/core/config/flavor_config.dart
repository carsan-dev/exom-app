import 'dart:io';

enum Flavor { dev, staging, prod }

class FlavorConfig {
  final Flavor flavor;
  final String apiBaseUrl;

  FlavorConfig._({required this.flavor, required this.apiBaseUrl});

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    _instance ??= FlavorConfig._(
      flavor: Flavor.dev,
      apiBaseUrl: _devBaseUrl,
    );
    return _instance!;
  }

  // Android emulator uses 10.0.2.2 to reach host machine localhost
  static String get _devBaseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  static void init(Flavor flavor) {
    _instance = FlavorConfig._(
      flavor: flavor,
      apiBaseUrl: switch (flavor) {
        Flavor.dev => _devBaseUrl,
        Flavor.staging => 'https://api-staging.exom.app/api/v1',
        Flavor.prod => 'https://api.exom.app/api/v1',
      },
    );
  }

  bool get isDev => flavor == Flavor.dev;
  bool get isProd => flavor == Flavor.prod;
}
