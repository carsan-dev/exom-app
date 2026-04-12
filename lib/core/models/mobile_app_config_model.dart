class MobileAppConfigModel {
  const MobileAppConfigModel({
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.latestAndroidVersion,
    required this.latestIosVersion,
    required this.minAndroidBuild,
    required this.minIosBuild,
    required this.recommendedAndroidBuild,
    required this.recommendedIosBuild,
    required this.forceAndroidUpdate,
    required this.forceIosUpdate,
    required this.updateTitle,
    required this.updateMessage,
    required this.supportUrl,
    required this.privacyPolicyUrl,
  });

  factory MobileAppConfigModel.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    bool readBool(String key) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        return value.toLowerCase() == 'true';
      }
      return false;
    }

    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    return MobileAppConfigModel(
      androidStoreUrl: readString('android_store_url'),
      iosStoreUrl: readString('ios_store_url'),
      latestAndroidVersion: readString('latest_android_version'),
      latestIosVersion: readString('latest_ios_version'),
      minAndroidBuild: readInt('min_android_build'),
      minIosBuild: readInt('min_ios_build'),
      recommendedAndroidBuild: readInt('recommended_android_build'),
      recommendedIosBuild: readInt('recommended_ios_build'),
      forceAndroidUpdate: readBool('force_android_update'),
      forceIosUpdate: readBool('force_ios_update'),
      updateTitle: readString('update_title'),
      updateMessage: readString('update_message'),
      supportUrl: readString('support_url'),
      privacyPolicyUrl: readString('privacy_policy_url'),
    );
  }

  final String androidStoreUrl;
  final String iosStoreUrl;
  final String latestAndroidVersion;
  final String latestIosVersion;
  final int minAndroidBuild;
  final int minIosBuild;
  final int recommendedAndroidBuild;
  final int recommendedIosBuild;
  final bool forceAndroidUpdate;
  final bool forceIosUpdate;
  final String updateTitle;
  final String updateMessage;
  final String supportUrl;
  final String privacyPolicyUrl;
}
