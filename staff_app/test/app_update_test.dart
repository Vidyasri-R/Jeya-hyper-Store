import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_staff/core/app_update.dart';

void main() {
  const latest = {'versionName': '1.0.1', 'versionCode': 3, 'url': 'https://cdn.jeyahyperstore.in/apps/jeya-staff/jeya-staff-1.0.1-3.apk'};

  test('offers the published APK only when its build number is higher', () {
    expect(newerApk(latest, 2)?.versionName, '1.0.1');
    expect(newerApk(latest, 3), isNull);
    expect(newerApk(latest, 4), isNull);
  });

  test('ignores a missing or broken manifest', () {
    expect(newerApk(null, 1), isNull);
    expect(newerApk({'versionCode': 9}, 1), isNull);
  });
}
