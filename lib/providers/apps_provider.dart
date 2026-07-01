import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/models/app_info.dart';
import 'settings_provider.dart';

Future<List<AppInfo>> _getInstalledAppsAndroid() async {
  const channel = MethodChannel(AppConstants.methodChannel);
  final result = await channel.invokeMethod<List>('getInstalledApps');
  if (result == null) return [];

  return result.map((item) {
    final map = Map<String, dynamic>.from(item as Map);
    final pkg = map['packageName'] as String;
    return AppInfo(
      packageName: pkg,
      appName: map['appName'] as String? ?? pkg,
      isSystem: map['isSystem'] as bool? ?? false,
      isExcluded: false,
    );
  }).toList()
    ..sort((a, b) => a.appName.compareTo(b.appName));
}

List<AppInfo> _getInstalledAppsWindows() {
  try {
    final psScript = r'''
$apps = @()
$keys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($key in $keys) {
  Get-ItemProperty $key -ErrorAction SilentlyContinue | ForEach-Object {
    $name = $_.DisplayName
    $loc = $_.InstallLocation
    $sys = $_.SystemComponent
    $parent = $_.ParentDisplayName
    if ($name -and $name.Length -gt 0) {
      $isSys = ($sys -eq 1) -or ($parent -and $parent.Length -gt 0)
      $path = if ($loc -and $loc.Length -gt 0) { $loc } else { $name }
      Write-Output "$name`t$path`t$isSys"
    }
  }
}
''';

    final result = Process.runSync(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', psScript],
    );

    if (result.exitCode != 0) return [];

    final lines = (result.stdout as String).split('\n');
    final apps = <AppInfo>[];
    final seen = <String>{};

    for (final line in lines) {
      final parts = line.trimRight().split('\t');
      if (parts.length < 3) continue;

      final name = parts[0].trim();
      final path = parts[1].trim();
      final isSystem = parts[2].trim() == 'True';

      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);

      apps.add(AppInfo(
        packageName: path,
        appName: name,
        isSystem: isSystem,
        isExcluded: false,
      ));
    }

    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  } catch (_) {
    return [];
  }
}

final installedAppsProvider =
    FutureProvider<List<AppInfo>>((ref) async {
  List<AppInfo> apps;

  if (Platform.isWindows) {
    apps = _getInstalledAppsWindows();
  } else {
    try {
      apps = await _getInstalledAppsAndroid();
    } on PlatformException {
      apps = [];
    } on MissingPluginException {
      apps = [];
    } catch (_) {
      apps = [];
    }
  }

  final settings = ref.read(settingsProvider).maybeWhen(
      data: (d) => d, orElse: () => null);
  final excluded = settings?.excludedPackages ?? {};

  return apps.map((app) {
    return app.copyWith(isExcluded: excluded.contains(app.packageName));
  }).toList();
});
