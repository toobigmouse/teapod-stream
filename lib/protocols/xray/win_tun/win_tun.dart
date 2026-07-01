/// WinTUN Full Tunnel module for TeapodStream
///
/// Provides WinTUN adapter integration for full-tunnel VPN on Windows.
/// Uses xray-core with TUN inbound + WinTUN adapter.
///
/// Usage:
/// ```dart
/// import 'win_tun/win_tun.dart';
///
/// final engine = WinTunEngine();
/// await engine.connect(config, options);
/// ```
library;

export 'win_tun_wrapper.dart';
export 'win_tun_engine.dart';
