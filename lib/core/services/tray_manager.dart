import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:system_tray/system_tray.dart';
import 'package:win32/win32.dart';
import '../constants/app_constants.dart';
import 'app_logger.dart';

/// Sets the C++ g_hide_on_close flag via WM_APP+1 message.
bool _lastHideValue = false;

void setHideOnClose(bool hide) {
  if (!Platform.isWindows) return;
  if (hide == _lastHideValue) return; // Skip if unchanged
  _lastHideValue = hide;
  final hwnd = _findMainWindow();
  AppLogger.log('TRAY', 'setHideOnClose($hide) hwnd=$hwnd');
  if (hwnd != 0) {
    final msgResult = PostMessage(hwnd, 0x8001, hide ? 1 : 0, 0); // WM_APP + 1
    AppLogger.log('TRAY', 'PostMessage(WM_APP+1) result=$msgResult');
  } else {
    AppLogger.log('TRAY', 'WARN: FindWindow returned 0 — WM_APP+1 NOT sent');
  }
}

int _findMainWindow() {
  final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  final title = 'teapodstream'.toNativeUtf16();
  try {
    final result = FindWindow(className, title);
    AppLogger.log('TRAY', 'FindWindow class=FLUTTER_RUNNER_WIN32_WINDOW title=teapodstream => $result');
    return result;
  } catch (e) {
    AppLogger.log('TRAY', 'FindWindow EXCEPTION: $e');
    return 0;
  } finally {
    calloc.free(className);
    calloc.free(title);
  }
}

/// Manages system tray icon and window show/hide behavior.
class TrayManager {
  static final TrayManager instance = TrayManager._();
  TrayManager._();

  final SystemTray _tray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  bool _initialized = false;
  bool Function()? _isConnected;
  bool _isHidden = false;

  bool get isHidden => _isHidden;

  Future<void> init({required bool Function() isConnected}) async {
    if (_initialized) return;
    _isConnected = isConnected;

    final iconPath = await _resolveIcon();
    AppLogger.log('TRAY', 'init() iconPath=$iconPath');
    await _tray.initSystemTray(
      title: AppConstants.appName,
      iconPath: iconPath,
      toolTip: AppConstants.appName,
    );

    await _tray.setContextMenu([
      MenuItem(
        label: 'Показать',
        onClicked: () {
          AppLogger.log('TRAY', 'context menu: Показать clicked');
          showWindow();
        },
      ),
      MenuSeparator(),
      MenuItem(
        label: 'Выход',
        onClicked: () {
          AppLogger.log('TRAY', 'context menu: Выход clicked');
          exitApp();
        },
      ),
    ]);

    _tray.registerSystemTrayEventHandler((eventName) {
      AppLogger.log('TRAY', 'tray event: $eventName');
      if (eventName == 'leftMouseDblClk' || eventName == 'click' || eventName == 'double-click') {
        showWindow();
      }
    });

    _initialized = true;
    AppLogger.log('TRAY', 'init() complete');
  }

  void showWindow() {
    AppLogger.log('TRAY', 'showWindow() called');
    final hwnd = _findMainWindow();
    if (hwnd != 0) {
      ShowWindow(hwnd, SW_SHOW);
      SetForegroundWindow(hwnd);
      AppLogger.log('TRAY', 'showWindow: ShowWindow(SW_SHOW) + SetForegroundWindow done');
    } else {
      AppLogger.log('TRAY', 'showWindow: FindWindow returned 0, fallback to AppWindow.show');
      _appWindow.show();
    }
    _isHidden = false;
  }

  void hideWindow() {
    AppLogger.log('TRAY', 'hideWindow() called');
    final hwnd = _findMainWindow();
    if (hwnd != 0) {
      ShowWindow(hwnd, SW_HIDE);
      AppLogger.log('TRAY', 'hideWindow: ShowWindow(SW_HIDE) done');
    } else {
      _appWindow.hide();
    }
    _isHidden = true;
  }

  /// Returns true if app should close, false to hide to tray.
  bool handleClose() {
    final connected = _isConnected != null && _isConnected!();
    AppLogger.log('TRAY', 'handleClose() connected=$connected');
    if (connected) {
      hideWindow();
      return false;
    }
    return true;
  }

  Future<void> exitApp() async {
    AppLogger.log('TRAY', 'exitApp() called');
    try {
      // Force close: set g_force_close = true in C++ before closing
      final hwnd = _findMainWindow();
      if (hwnd != 0) {
        final msgResult = PostMessage(hwnd, 0x8002, 0, 0); // WM_APP + 2
        AppLogger.log('TRAY', 'PostMessage(WM_APP+2) result=$msgResult');
      } else {
        AppLogger.log('TRAY', 'WARN: FindWindow returned 0 — WM_APP+2 NOT sent');
      }
      Process.run('taskkill', ['/F', '/IM', 'xray.exe']);
    } catch (e) {
      AppLogger.log('TRAY', 'exitApp exception: $e');
    }
    _appWindow.close();
  }

  Future<String> _resolveIcon() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\data\\flutter_assets\\assets\\icon.ico',
      '$exeDir\\data\\flutter_assets\\assets\\icon.png',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return Platform.resolvedExecutable;
  }
}
