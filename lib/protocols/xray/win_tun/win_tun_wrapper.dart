import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// FFI function signatures
typedef _CreateAdapterNative = Pointer<Void> Function(Pointer<Utf16> adapterName, Pointer<Utf16> tunnelType);
typedef _CreateAdapterDart = Pointer<Void> Function(Pointer<Utf16> adapterName, Pointer<Utf16> tunnelType);

typedef _StartSessionNative = Int32 Function(Pointer<Void> session, Uint32 capacity);
typedef _StartSessionDart = int Function(Pointer<Void> session, int capacity);

typedef _ReceivePacketNative = Int32 Function(Pointer<Void> session, Pointer<Uint8> buffer, Int32 bufferSize);
typedef _ReceivePacketDart = int Function(Pointer<Void> session, Pointer<Uint8> buffer, int bufferSize);

typedef _SendPacketNative = Int32 Function(Pointer<Void> session, Pointer<Uint8> buffer, Int32 bufferSize);
typedef _SendPacketDart = int Function(Pointer<Void> session, Pointer<Uint8> buffer, int bufferSize);

typedef _StopSessionNative = Void Function(Pointer<Void> session);
typedef _StopSessionDart = void Function(Pointer<Void> session);

typedef _DeleteAdapterNative = Void Function(Pointer<Void> session);
typedef _DeleteAdapterDart = void Function(Pointer<Void> session);

typedef _GetLastErrorNative = Pointer<Utf16> Function();
typedef _GetLastErrorDart = Pointer<Utf16> Function();

/// WinTUN adapter states
enum WinTunState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// WinTUN adapter status
class WinTunStatus {
  final WinTunState state;
  final String? error;
  final Duration? duration;
  final int? bytesIn;
  final int? bytesOut;

  WinTunStatus({
    required this.state,
    this.error,
    this.duration,
    this.bytesIn,
    this.bytesOut,
  });
}

/// Dart FFI wrapper for WinTUN
class WinTunWrapper {
  static DynamicLibrary? _library;
  static bool _initialized = false;

  static late _CreateAdapterDart _createAdapter;
  static late _StartSessionDart _startSession;
  static late _ReceivePacketDart _receivePacket;
  static late _SendPacketDart _sendPacket;
  static late _StopSessionDart _stopSession;
  static late _DeleteAdapterDart _deleteAdapter;
  static late _GetLastErrorDart _getLastError;

  /// Initialize the WinTUN library
  static void init() {
    if (_initialized) return;

    if (!Platform.isWindows) {
      throw UnsupportedError('WinTUN is only supported on Windows');
    }

    // Load the DLL
    _library = DynamicLibrary.open('win_tun.dll');

    // Load function pointers
    _createAdapter = _library!.lookupFunction<_CreateAdapterNative, _CreateAdapterDart>(
      'WintunCreateAdapter',
    );
    _startSession = _library!.lookupFunction<_StartSessionNative, _StartSessionDart>(
      'WintunStartSession',
    );
    _receivePacket = _library!.lookupFunction<_ReceivePacketNative, _ReceivePacketDart>(
      'WintunReceivePacket',
    );
    _sendPacket = _library!.lookupFunction<_SendPacketNative, _SendPacketDart>(
      'WintunSendPacket',
    );
    _stopSession = _library!.lookupFunction<_StopSessionNative, _StopSessionDart>(
      'WintunStopSession',
    );
    _deleteAdapter = _library!.lookupFunction<_DeleteAdapterNative, _DeleteAdapterDart>(
      'WintunDeleteAdapter',
    );
    _getLastError = _library!.lookupFunction<_GetLastErrorNative, _GetLastErrorDart>(
      'WintunGetLastError',
    );

    _initialized = true;
  }

  /// Create a new WinTUN adapter session
  static Pointer<Void> createAdapter({
    String adapterName = 'TeapodTUN',
    String tunnelType = 'TeapodStream',
  }) {
    init();

    final namePtr = adapterName.toNativeUtf16();
    final typePtr = tunnelType.toNativeUtf16();

    try {
      final session = _createAdapter(namePtr, typePtr);
      if (session == nullptr) {
        final errorPtr = _getLastError();
        final error = errorPtr.toDartString();
        throw WinTunException('Failed to create adapter: $error');
      }
      return session;
    } finally {
      calloc.free(namePtr);
      calloc.free(typePtr);
    }
  }

  /// Start a session on the adapter
  static void startSession(Pointer<Void> session, {int capacity = 256}) {
    final result = _startSession(session, capacity);
    if (result != 0) {
      final errorPtr = _getLastError();
      final error = errorPtr.toDartString();
      throw WinTunException('Failed to start session: $error');
    }
  }

  /// Receive a packet from the TUN adapter
  static int receivePacket(Pointer<Void> session, Pointer<Uint8> buffer, int bufferSize) {
    return _receivePacket(session, buffer, bufferSize);
  }

  /// Send a packet to the TUN adapter
  static void sendPacket(Pointer<Void> session, Pointer<Uint8> buffer, int bufferSize) {
    final result = _sendPacket(session, buffer, bufferSize);
    if (result != 0) {
      final errorPtr = _getLastError();
      final error = errorPtr.toDartString();
      throw WinTunException('Failed to send packet: $error');
    }
  }

  /// Stop the session
  static void stopSession(Pointer<Void> session) {
    _stopSession(session);
  }

  /// Delete the adapter
  static void deleteAdapter(Pointer<Void> session) {
    _deleteAdapter(session);
  }

  /// Get last error message
  static String getLastError() {
    init();
    final errorPtr = _getLastError();
    return errorPtr.toDartString();
  }
}

/// WinTUN exception
class WinTunException implements Exception {
  final String message;
  WinTunException(this.message);

  @override
  String toString() => 'WinTunException: $message';
}
