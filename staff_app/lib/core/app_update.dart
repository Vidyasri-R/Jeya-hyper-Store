import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where tool/release_apk.sh publishes the newest Android APK (the app isn't on the Play Store).
const latestApkInfoUrl = 'https://cdn.jeyahyperstore.in/apps/jeya-staff/latest.json';
const downloadPageUrl = 'https://staff.jeyahyperstore.in/download/';

typedef AppUpdate = ({String versionName, String url});

/// A newer Android APK than this one, or null (web, up to date, offline). Checked once per launch.
final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)))
        .get<Map<String, dynamic>>(latestApkInfoUrl, options: Options(headers: {'Cache-Control': 'no-cache'}));
    return newerApk(res.data, int.tryParse(info.buildNumber) ?? 0);
  } catch (_) {
    return null; // no internet / nothing published yet: try again next launch
  }
});

/// The published APK if its build number is above [installedBuild].
AppUpdate? newerApk(Map<String, dynamic>? latest, int installedBuild) {
  final code = (latest?['versionCode'] as num?)?.toInt() ?? 0;
  final url = latest?['url'] as String?;
  if (url == null || code <= installedBuild) return null;
  return (versionName: latest?['versionName'] as String? ?? '', url: url);
}
