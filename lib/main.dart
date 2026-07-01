import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/services/app_logger.dart';
import 'core/services/tray_manager.dart';
import 'providers/vpn_provider.dart';
import 'protocols/xray/windows_xray_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  // Kill xray on app exit (Windows)
  if (Platform.isWindows) {
    WidgetsBinding.instance.addObserver(_XrayKiller());
  }

  // Fetch xray-core version early so it's available in the subscription User-Agent.
  if (Platform.isWindows) {
    try {
      final wx = WindowsXrayEngine();
      final versions = await wx.getBinaryVersions();
      final xray = versions['xray'] ?? '';
      if (xray.isNotEmpty && xray != '—') {
        AppConstants.xrayCoreVersion = xray;
      }
    } catch (_) {}
  } else {
    try {
      const channel = MethodChannel(AppConstants.methodChannel);
      final versions = await channel.invokeMethod<Map>('getBinaryVersions');
      final xray = versions?['xray'] as String?;
      if (xray != null && xray.isNotEmpty && xray != 'Error' && xray != '—') {
        AppConstants.xrayCoreVersion = xray;
      }
    } catch (_) {}
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF161A22),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  try {
    File('${AppLogger.logDir.path}\\debug.log')
        .writeAsStringSync('${DateTime.now()}|about to runApp\n', mode: FileMode.append);
  } catch (_) {}

  runApp(const TeapodApp());

  // Initialize tray after first frame
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TrayManager.instance.init(isConnected: _checkVpnConnected);
    });
  }
}

bool _checkVpnConnected() {
  try {
    final element = WidgetsBinding.instance.rootElement;
    if (element == null) return false;
    final container = ProviderScope.containerOf(element);
    final state = container.read(vpnProvider);
    return state.isConnected || state.isConnecting;
  } catch (_) {
    return false;
  }
}

class _XrayKiller extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.log('MAIN', 'AppLifecycleState: $state');
    if (state == AppLifecycleState.detached) {
      AppLogger.log('MAIN', 'detached → killing xray.exe');
      try {
        Process.run('taskkill', ['/F', '/IM', 'xray.exe']);
      } catch (_) {}
    }
  }
}
