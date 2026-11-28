import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// SIL OFL 1.1 requires shipping the copyright notice and the license with the
/// bundled fonts; they are surfaced in the app's license page.
const Map<String, String> _fontLicenseAssets = {
  'DM Sans': 'assets/fonts/dm-sans-OFL.txt',
  'Barlow Condensed': 'assets/fonts/barlow-OFL.txt',
};

/// Registers the bundled fonts' licenses with [LicenseRegistry]. The assets are
/// read lazily, only when the license list is requested.
void registerFontLicenses({AssetBundle? bundle}) {
  for (final entry in _fontLicenseAssets.entries) {
    LicenseRegistry.addLicense(() async* {
      final text = await (bundle ?? rootBundle).loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    });
  }
}
