import 'dart:io';

class AppLogger {
  static late File _file;
  static bool _initialized = false;
  static late Directory _logDir;

  /// The resolved logs directory (next to exe or %LOCALAPPDATA% fallback).
  static Directory get logDir => _logDir;

  /// Returns the logs directory next to the running executable.
  /// Falls back to %LOCALAPPDATA%\TeapodStream\logs if write fails.
  static Directory _resolveLogDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final primary = Directory('${exeDir.path}\\logs');
    if (primary.existsSync() || _canWrite(primary)) return primary;

    final fallback = Directory(
      '${Platform.environment['LOCALAPPDATA']}\\TeapodStream\\logs',
    );
    return fallback;
  }

  static bool _canWrite(Directory dir) {
    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final probe = File('${dir.path}\\.probe');
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  static void init() {
    if (_initialized) return;
    try {
      _logDir = _resolveLogDir();
      if (!_logDir.existsSync()) _logDir.createSync(recursive: true);
      _file = File('${_logDir.path}\\app.log');
      _initialized = true;
      log('APP', 'Logger initialized — dir: ${_logDir.path}');
    } catch (_) {}
  }

  static void log(String tag, String msg) {
    if (!_initialized) return;
    try {
      final ts = DateTime.now().toIso8601String();
      _file.writeAsStringSync('$ts [$tag] $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  static void clear() {
    if (!_initialized) return;
    try {
      _file.writeAsStringSync('');
    } catch (_) {}
  }
}
