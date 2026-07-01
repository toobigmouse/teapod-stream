import 'dart:io';
import 'package:win32/win32.dart';

/// Sets the main window to a fixed size: full screen height, harmonious width.
/// Removes the resize border so the window cannot be dragged to resize.
void initFixedSizeWindow() {
  if (!Platform.isWindows) return;
  try {
    final hwnd = GetActiveWindow();
    if (hwnd == 0) return;

    // Screen dimensions
    final screenW = GetSystemMetrics(SM_CXSCREEN);
    final screenH = GetSystemMetrics(SM_CYSCREEN);

    // Subtract taskbar (~48px)
    final winH = screenH - 48;
    // 0.55 aspect ratio — phone-like harmonious width
    final winW = (winH * 0.55).toInt().clamp(360, 560);

    // Remove WS_THICKFRAME (resize border) and WS_MAXIMIZEBOX
    final style = GetWindowLongPtr(hwnd, GWL_STYLE);
    final newStyle = style & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX;
    SetWindowLongPtr(hwnd, GWL_STYLE, newStyle);

    // Set size and center on screen
    final left = ((screenW - winW) / 2).toInt();
    final top = ((screenH - winH) / 2).toInt();
    SetWindowPos(hwnd, HWND_TOP, left, top, winW, winH, SWP_FRAMECHANGED);
  } catch (_) {}
}
