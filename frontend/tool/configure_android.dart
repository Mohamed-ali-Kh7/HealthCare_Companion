// Configure le projet Android généré par `flutter create` pour HealthCare Companion.
//
// Usage (depuis le dossier frontend/) :
//   flutter create --org com.healthcare --platforms android,ios .
//   dart run tool/configure_android.dart
//
// Le script est idempotent (il peut être relancé sans effet de bord). Il ajoute :
//  - les permissions (réseau, localisation, activité physique, notifications) ;
//  - l'autorisation du HTTP non chiffré (développement local uniquement) ;
//  - les récepteurs de flutter_local_notifications (rappels planifiés, redémarrage) ;
//  - le "core library desugaring" exigé par flutter_local_notifications.
// ignore_for_file: avoid_print
import 'dart:io';

const _marker = 'healthcare-companion-config';

void main() {
  _patchManifest(File('android/app/src/main/AndroidManifest.xml'));

  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    _patchGradle(kts, kotlinDsl: true);
  } else if (groovy.existsSync()) {
    _patchGradle(groovy, kotlinDsl: false);
  } else {
    stderr.writeln('build.gradle introuvable : lancez d\'abord "flutter create ."');
    exit(1);
  }

  // Le test d'exemple généré par "flutter create" référence MyApp, qui n'existe pas ici
  final sampleTest = File('test/widget_test.dart');
  if (sampleTest.existsSync() && sampleTest.readAsStringSync().contains('MyApp')) {
    sampleTest.deleteSync();
    print('test/widget_test.dart (exemple généré) supprimé.');
  }
  print('Configuration Android terminée.');
}

void _patchManifest(File file) {
  if (!file.existsSync()) {
    stderr.writeln('AndroidManifest.xml introuvable : lancez d\'abord "flutter create ."');
    exit(1);
  }
  var xml = file.readAsStringSync();
  if (xml.contains(_marker)) {
    print('AndroidManifest.xml déjà configuré.');
    return;
  }

  const permissions = '''
    <!-- $_marker : permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />
''';
  xml = xml.replaceFirst('<application', '$permissions    <application');

  // HTTP en clair autorisé pour l'API locale (http://10.0.2.2:8081). À retirer en production (HTTPS).
  xml = xml.replaceFirst('<application', '<application\n        android:usesCleartextTraffic="true"');

  const receivers = '''
        <!-- $_marker : rappels de médicaments (flutter_local_notifications) -->
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
''';
  final end = xml.lastIndexOf('</application>');
  xml = '${xml.substring(0, end)}$receivers    ${xml.substring(end)}';

  file.writeAsStringSync(xml);
  print('AndroidManifest.xml configuré.');
}

void _patchGradle(File file, {required bool kotlinDsl}) {
  var gradle = file.readAsStringSync();
  if (gradle.contains('desugar_jdk_libs')) {
    print('${file.path} déjà configuré.');
    return;
  }

  final enable = kotlinDsl
      ? '        isCoreLibraryDesugaringEnabled = true'
      : '        coreLibraryDesugaringEnabled true';
  final compileOptions = RegExp(r'compileOptions\s*\{');
  final match = compileOptions.firstMatch(gradle);
  if (match != null) {
    gradle = gradle.replaceRange(match.end, match.end, '\n$enable');
  } else {
    gradle = gradle.replaceFirst(
        RegExp(r'android\s*\{'), 'android {\n    compileOptions {\n$enable\n    }');
  }

  final dependency = kotlinDsl
      ? '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
      : "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'";
  gradle = '${gradle.trimRight()}\n\n// $_marker\ndependencies {\n$dependency\n}\n';

  file.writeAsStringSync(gradle);
  print('${file.path} configuré (desugaring).');
}
