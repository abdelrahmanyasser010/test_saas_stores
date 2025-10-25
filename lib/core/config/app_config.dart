class AppConfig {
  final String appName;
  final String packageName;
  final String version;
  final String apiBaseUrl;
  final String primaryColor;
  final String splashImage;
  final List<String> onboardingImages;
  final String appIcon;
  final String androidKeystoreUrl;
  final String androidKeyPropertiesUrl;
  final String iosCertUrl;
  final String iosProfileUrl;

  AppConfig({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.apiBaseUrl,
    required this.primaryColor,
    required this.splashImage,
    required this.onboardingImages,
    required this.appIcon,
    required this.androidKeystoreUrl,
    required this.androidKeyPropertiesUrl,
    required this.iosCertUrl,
    required this.iosProfileUrl,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'],
      packageName: json['package_name'],
      version: json['version'],
      apiBaseUrl: json['api_base_url'],
      primaryColor: json['primary_color'],
      splashImage: json['splash_image'],
      onboardingImages: List<String>.from(json['onboarding_images']),
      appIcon: json['app_icon'],
      androidKeystoreUrl: json['android_keystore_url'],
      androidKeyPropertiesUrl: json['android_key_properties_url'],
      iosCertUrl: json['ios_cert_url'],
      iosProfileUrl: json['ios_profile_url'],
    );
  }
}


