# Session Summary — TeapodStream Windows Port

## Goal
Port TeapodStream (Android Flutter VPN) to Windows 11 + maintain Android compatibility.

## Status
All changes committed and pushed to `origin/master` (`toobigmouse/teapod-stream`).

**Latest commit**: `dfc98ad` — "Windows port: single-instance, tray menu, release build (MSIX)"
58 files changed, +4623 / −139 lines.

## What Was Done

### Cross-platform core
- `AppLogger` — async init, uses `getApplicationDocumentsDirectory()` on Android, `Platform.pathSeparator` everywhere
- `CloseInterceptor` — callback-based close handler for Windows quit-from-tray
- `TrayManager` — system tray init, popup menu (Показать / Добавить конфигурацию / Добавить подписку / Закрыть приложение), right-click → `popUpContextMenu()`
- `WindowManager` — fixed-size window, no-op `ensureSingleInstance()` on Windows

### Single-instance guard (native C++)
- `CreateMutexW` in `windows/runner/main.cpp` before Dart VM starts
- Second instance exits immediately, brings first window to foreground
- Dart `ensureSingleInstance()` is now a no-op

### Windows xray engine
- `WindowsXrayEngine` — xray subprocess, TUN routing (Bypass/Only)
- `WinTunWrapper` — FFI wrapper for WinTUN C library
- WinTUN C++ wrapper (CMakeLists.txt + win_tun_wrapper.cpp/.h)
- Known pre-existing issue: stats polling fails with `flag provided but not defined: -j`

### Build & packaging
- Release build: `flutter build windows --release`
- MSIX packaging: `windows/build.ps1` creates signed `TeapodStream-x64-<version>.msix`
- MSIX excludes `logs/` directory
- GitHub Actions CI: `.github/workflows/windows-msix.yml`
- Self-signed cert password: `teapodstream`
- Cert must be installed in **Trusted Root Certification Authorities**

### Cleanup
- `nul` garbage file deleted (artifact from accidental bash redirect)
- `nul` added to `.gitignore`

### Android compatibility preserved
- All Android files touched for cross-platform imports only
- APK builds and runs on Pixel 6 emulator

## Key Files

| File | Purpose |
|---|---|
| `windows/runner/main.cpp` | `CreateMutexW` guard, `SetQuitOnClose(true)` |
| `lib/core/services/tray_manager.dart` | System tray + popup menu |
| `lib/core/services/window_manager.dart` | Window sizing, no-op ensureSingleInstance |
| `lib/core/services/app_logger.dart` | Cross-platform log init |
| `lib/core/services/close_interceptor.dart` | Quit callback |
| `lib/main.dart` | Entry point, platform branching |
| `lib/app.dart` | Tray navigation callbacks |
| `lib/protocols/xray/windows_xray_engine.dart` | Windows xray + TUN |
| `lib/protocols/xray/win_tun/` | WinTUN FFI wrappers (Dart + C++) |
| `windows/build.ps1` | MSIX packaging script |
| `.github/workflows/windows-msix.yml` | CI for MSIX build |
| `AGENTS.md` | Dev instructions for AI agents |
| `FIXES.md` | Bug fix log |
