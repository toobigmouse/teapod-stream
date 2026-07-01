# AGENTS.md — TeapodStream

Flutter VPN client for Android. Xray-core + teapod-tun2socks (AAR).

## Key commands

| Command | Purpose |
|---|---|
| `./build.sh binaries` | Download teapod-core.aar + geoip/geosite.dat |
| `./build.sh debug` | Build debug APK (split-per-abi) |
| `./build.sh release` | Build release APK (obfuscated, split-per-abi) |
| `./build.sh run` | Run debug on connected device |
| `./build.sh aab` | Build AAB for Play Store |
| `flutter analyze` | Lint check |
| `flutter test` | Unit tests (minimal; main verification = device) |

Run `./build.sh binaries` first — without teapod-core.aar in `android/app/libs/` and geo data in `assets/binaries/`, the build will succeed but crash at runtime.

## Architecture

- **State management**: Riverpod 3 (flutter_riverpod) — no codegen. `ConsumerWidget`/`ConsumerStatefulWidget` + `WidgetRef`.
- **Entrypoint**: `lib/main.dart` → `TeapodApp` (wraps in `ProviderScope`).
- **4 tab screens**: Home, Configs, Logs, Settings — via `IndexedStack` in `_AppShell`.
- **VPN state**: `vpnProvider` (Riverpod) syncs with native via `MethodChannel('com.teapodstream/vpn')`.
- **Protocol parsers**: `lib/protocols/xray/vless_parser.dart` — supports VLESS, VMess, Trojan, Shadowsocks, Hysteria2.
- **Deep links**: `EventChannel('com.teapodstream/vpn/events')` → `DeeplinkHandler`.
- **Custom tab icons**: `CustomPainter` — no SVG dependency.

## Build quirks

- **minSdk 29** — required by teapod-tun2socks AAR (`getConnectionOwnerUid`).
- **NDK 28.2.13676358** — pinned in both `build.sh` and `android/app/build.gradle.kts`.
- **Java 17** target (compileOptions).
- **Android build dir** redirected to `../../build` (under project root) — `android/build.gradle.kts`.
- **Release builds**: `--obfuscate --split-debug-info=build/app/outputs/symbols`.
- **JNI libs** (`android/app/src/main/jniLibs/`) and `*.aar` are gitignored — downloaded by `./build.sh binaries`.
- **x86 lib excluded** in packaging (`lib/x86/**`) — not supported by teapod-core.
- Release signing uses debug keystore by default.

## Notable conventions

- Tab bar UI uses custom `CustomPainter` for icons (no `flutter_svg`).
- Subscription User-Agent: `TeapodStream/<version> (Android; XrayNG-compatible) Xray-core/<ver>`.
- Gradle props: 4G heap, parallel builds, caching enabled.
- `.gitignore` excludes AI assistant files (CLAUDE.md, .claude/, .qwen/, etc.).
- No riverpod_generator, freezed, or JSON serialization codegen.
