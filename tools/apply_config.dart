import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // ✅ 1. قراءة ملف config.json
  final configFile = File('config.json');
  if (!configFile.existsSync()) {
    print('❌ config.json not found!');
    return;
  }

  final config = jsonDecode(await configFile.readAsString());
  final appName = config['app_name'];
  final packageName = config['package_name'];
  final version = config['version'];
  final iconUrl = config['icon_url'];
  final onboardingImages = List<String>.from(config['onboarding_images'] ?? []);
  final splashImages = List<String>.from(config['splash_images'] ?? []);
  final androidKeystore = config['android_keystore'];
  final iosCert = config['ios_cert'];

  print('🔧 Applying config for: $appName');

  // 🧹 2. تنظيف مجلد assets القديم (علشان مايحصلش تكرار)
  final assetsDir = Directory('assets');
  if (assetsDir.existsSync()) {
    await assetsDir.delete(recursive: true);
  }
  await assetsDir.create(recursive: true);

  // 💾 3. تحميل الصور (الأيقونة + Onboarding + Splash)
  Future<void> downloadFile(String url, String path) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      print('✅ Downloaded: $path');
    } else {
      print('⚠️ Failed to download $url');
    }
  }

  // تحميل الأيقونة
  final iconPath = 'assets/app_icon.png';
  if (iconUrl != null) await downloadFile(iconUrl, iconPath);

  // تحميل صور الـ Onboarding
  for (int i = 0; i < onboardingImages.length; i++) {
    await downloadFile(onboardingImages[i], 'assets/onboarding_${i + 1}.png');
  }

  // تحميل صور الـ Splash
  for (int i = 0; i < splashImages.length; i++) {
    await downloadFile(splashImages[i], 'assets/splash_${i + 1}.png');
  }

  // 💾 4. حفظ ملفات البصمة (keystore و iOS cert)
  final keystoreDir = Directory('keys');
  if (!keystoreDir.existsSync()) await keystoreDir.create();

  if (androidKeystore != null) {
    final ksFile = File('keys/android_keystore.jks');
    await ksFile.writeAsBytes(base64Decode(androidKeystore));
    print('✅ Android keystore saved.');
  }

  if (iosCert != null) {
    final iosFile = File('keys/ios_certificate.p12');
    await iosFile.writeAsBytes(base64Decode(iosCert));
    print('✅ iOS certificate saved.');
  }

  // 📝 5. تعديل pubspec.yaml (الاسم، الفيرجن، والأيقونة)
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    print('❌ pubspec.yaml not found!');
    return;
  }

  var content = await pubspec.readAsString();
  content = content.replaceFirst(
      RegExp(r'^name: .+', multiLine: true),
      'name: ${appName.toLowerCase().replaceAll(" ", "_")}');
  content = content.replaceFirst(
      RegExp(r'^version: .+', multiLine: true), 'version: $version');

  if (!content.contains('flutter_icons:')) {
    content += '''

flutter_icons:
  android: true
  ios: true
  image_path: $iconPath
''';
  }

  await pubspec.writeAsString(content);
  print('✅ pubspec.yaml updated');

  // 🧱 6. تغيير الـ package name (Android + iOS)
  final flutterPath = 'flutter'; // لو انت على Linux/GitHub CI
  await runCommand(flutterPath, ['pub', 'get']);
  try {
    await runCommand(
        flutterPath, ['pub', 'run', 'rename', '--bundleId', packageName]);
  } catch (e) {
    print('⚠️ Rename failed: $e');
  }

  // 🔧 7. تحديث AndroidManifest و Info.plist
  await _updateDisplayNames(appName);
  await _updateGradlePackage(packageName);

  // 🎨 8. توليد الأيقونة
  await runCommand(flutterPath, ['pub', 'run', 'flutter_launcher_icons:main']);

  print('🚀 Configuration applied successfully!');
}

/// Helpers
Future<void> runCommand(String executable, List<String> arguments) async {
  print('> $executable ${arguments.join(' ')}');
  final process = await Process.start(executable, arguments,
      mode: ProcessStartMode.inheritStdio);
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('❌ Command failed: $executable ${arguments.join(' ')}');
    exit(exitCode);
  }
}

Future<void> _updateDisplayNames(String appName) async {
  // Android
  final androidManifest = File('android/app/src/main/AndroidManifest.xml');
  if (androidManifest.existsSync()) {
    var androidContent = await androidManifest.readAsString();
    androidContent = androidContent.replaceAll(
        RegExp(r'android:label=".*?"'), 'android:label="$appName"');
    await androidManifest.writeAsString(androidContent);
    print('✅ Android app name updated');
  }

  // iOS
  final iosPlist = File('ios/Runner/Info.plist');
  if (iosPlist.existsSync()) {
    var iosContent = await iosPlist.readAsString();
    iosContent = iosContent.replaceAll(
        RegExp(r'<key>CFBundleDisplayName</key>\s*<string>.*?</string>'),
        '<key>CFBundleDisplayName</key>\n\t<string>$appName</string>');
    await iosPlist.writeAsString(iosContent);
    print('✅ iOS app name updated');
  }
}

Future<void> _updateGradlePackage(String packageName) async {
  final gradleKts = File('android/app/build.gradle.kts');
  if (gradleKts.existsSync()) {
    var ktsContent = await gradleKts.readAsString();

    if (ktsContent.contains('applicationId')) {
      ktsContent = ktsContent.replaceAll(
        RegExp(r'applicationId\s*=\s*".*?"'),
        'applicationId = "$packageName"',
      );
    } else {
      ktsContent = ktsContent.replaceAllMapped(
        RegExp(r'defaultConfig\s*\{'),
            (match) => '${match[0]}\n        applicationId = "$packageName"',
      );
    }

    await gradleKts.writeAsString(ktsContent);
    print('✅ Android build.gradle.kts package updated');
  }
}
