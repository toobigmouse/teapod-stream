import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socks5_proxy/socks.dart';
import '../core/interfaces/vpn_engine.dart';
import '../core/services/app_logger.dart';
import 'vpn_provider.dart';

class IpInfo {
  final String ip;
  final String country;
  final String countryCode;

  const IpInfo({
    required this.ip,
    required this.country,
    required this.countryCode,
  });
}

class IpInfoNotifier extends AsyncNotifier<IpInfo?> {
  @override
  Future<IpInfo?> build() async {
    final connectionState = ref.watch(vpnConnectionStateProvider);
    if (connectionState == VpnState.connected) {
      final vpnState = ref.read(vpnProvider);
      AppLogger.log('IP', 'connected state, socksPort=${vpnState.activeSocksPort}, user=${vpnState.activeSocksUser}');
      if (vpnState.activeSocksPort > 0) {
        return _fetch(
          socksPort: vpnState.activeSocksPort,
          socksUser: vpnState.activeSocksUser,
          socksPassword: vpnState.activeSocksPassword,
        );
      }
    }
    AppLogger.log('IP', 'not connected or no socks port, state=$connectionState');
    return null;
  }

  Future<IpInfo?> _fetch({
    required int socksPort,
    required String socksUser,
    required String socksPassword,
  }) async {
    if (socksPort <= 0) return null;
    AppLogger.log('IP', 'fetching via SOCKS5 127.0.0.1:$socksPort');
    final client = HttpClient();
    if (socksPort > 0) {
      SocksTCPClient.assignToHttpClient(client, [
        ProxySettings(
          InternetAddress.loopbackIPv4,
          socksPort,
          username: socksUser.isNotEmpty ? socksUser : null,
          password: socksUser.isNotEmpty ? socksPassword : null,
        ),
      ]);
    }
    try {
      final req = await client
          .getUrl(Uri.parse('http://ip-api.com/json?fields=query,country,countryCode,status'))
          .timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.userAgentHeader, 'TeapodStream');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();
      AppLogger.log('IP', 'response: $body');
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] != 'success') {
        AppLogger.log('IP', 'status not success: ${json['status']}');
        return null;
      }
      return IpInfo(
        ip: json['query'] as String,
        country: json['country'] as String,
        countryCode: json['countryCode'] as String,
      );
    } catch (e) {
      AppLogger.log('IP', 'fetch error: $e');
      return null;
    } finally {
      client.close();
    }
  }
}

final ipInfoProvider = AsyncNotifierProvider<IpInfoNotifier, IpInfo?>(IpInfoNotifier.new);
