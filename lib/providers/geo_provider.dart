import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import 'settings_provider.dart';

sealed class GeoState {}

class GeoMissing extends GeoState {}

class GeoReady extends GeoState {
  final DateTime? lastUpdated;
  GeoReady({this.lastUpdated});
}

class GeoDownloading extends GeoState {
  final int downloaded;
  final int total;
  GeoDownloading({required this.downloaded, required this.total});
}

class GeoError extends GeoState {
  final String message;
  GeoError(this.message);
}

class GeoNotifier extends Notifier<GeoState> {
  static const _kLastUpdated = 'geo_last_updated';
  static const _channel = MethodChannel(AppConstants.methodChannel);

  @override
  GeoState build() {
    Future.microtask(() {
      try {
        check();
      } catch (_) {}
    });
    return GeoMissing();
  }

  Future<String?> _geoDir() async {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final assetsDir = '$exeDir\\data\\flutter_assets\\assets\\binaries';
      if (await Directory(assetsDir).exists()) return assetsDir;
      return null;
    }
    try {
      final dir = await _channel.invokeMethod<String>('getFilesDir');
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<void> check() async {
    final dir = await _geoDir();
    if (dir == null) {
      state = GeoMissing();
      return;
    }
    final geoip = File('$dir/geoip.dat');
    final geosite = File('$dir/geosite.dat');
    if (geoip.existsSync() && geosite.existsSync()) {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_kLastUpdated);
      state = GeoReady(
        lastUpdated: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      );
    } else {
      state = GeoMissing();
    }
  }

  Future<void> download() async {
    final settings = await ref.read(settingsProvider.future);
    final dir = await _geoDir();
    if (dir == null) {
      state = GeoError('Не удалось получить путь к файлам (Windows: put geo files in assets/binaries/)');
      return;
    }

    state = GeoDownloading(downloaded: 0, total: -1);
    int totalDownloaded = 0;
    int grandTotal = -1;

    try {
      final lenGeoip = await _contentLength(settings.geoipUrl);
      final lenGeosite = await _contentLength(settings.geositeUrl);
      if (lenGeoip > 0 && lenGeosite > 0) grandTotal = lenGeoip + lenGeosite;
      state = GeoDownloading(downloaded: 0, total: grandTotal);
    } catch (_) {}

    try {
      for (final (url, name) in [
        (settings.geoipUrl, 'geoip.dat'),
        (settings.geositeUrl, 'geosite.dat'),
      ]) {
        await _downloadFile(
          url: url,
          destPath: '$dir/$name',
          onProgress: (bytes) {
            totalDownloaded += bytes;
            state = GeoDownloading(downloaded: totalDownloaded, total: grandTotal);
          },
        );
      }
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastUpdated, now.millisecondsSinceEpoch);
      state = GeoReady(lastUpdated: now);
    } catch (e) {
      state = GeoError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<int> _contentLength(String url) async {
    final client = http.Client();
    try {
      final resp = await client.head(Uri.parse(url));
      return int.tryParse(resp.headers['content-length'] ?? '') ?? -1;
    } finally {
      client.close();
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String destPath,
    required void Function(int bytes) onProgress,
  }) async {
    final tmpPath = '$destPath.tmp';
    final tmpFile = File(tmpPath);
    final destFile = File(destPath);

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final sink = tmpFile.openWrite();
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          onProgress(chunk.length);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    if (destFile.existsSync()) await destFile.delete();
    await tmpFile.rename(destPath);
  }
}

final geoProvider = NotifierProvider<GeoNotifier, GeoState>(GeoNotifier.new);
