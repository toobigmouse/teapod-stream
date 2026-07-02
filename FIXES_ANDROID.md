# Исправления — Android (fix/android)

## Batch 1 — целостность данных и утечки

| ID | Проблема | Файл | Статус |
|---|---|---|---|
| C1 | `_editConfig` терял 16 полей (password, method, fingerprint, alpn, ech, rawXrayConfig...) при редактировании URI | `lib/ui/screens/configs_screen.dart` | ✅ |
| C2 | `importBundle` терял 7 полей (lastPingedAt, allowInsecure, pinSHA256, finalmask, alpn, ech, rawXrayConfig) при импорте | `lib/providers/config_provider.dart` | ✅ |
| C3 | `apps_provider` использовал `ref.read` вместо `ref.watch` — UI split-tunnel не обновлялся после переключения excluded | `lib/providers/apps_provider.dart` | ✅ |
| C4 | 7× `TextEditingController` без `.dispose()`; 2× `MediaQuery.of(context)` вместо `ctx` | `lib/ui/screens/configs_screen.dart`, `profiles_screen.dart` | ✅ |
| C6 | `refreshStaleSubscriptions` — одна упавшая подписка обрывала цикл обновления всех | `lib/providers/config_provider.dart` | ✅ |
| C12 | `state.value?.activeConfigId` без `.hasValue` guard | `lib/providers/config_provider.dart` | ✅ |
| C13 | `_current!` — краш если `ProfileNotifier` не загружен | `lib/providers/profile_provider.dart` | ✅ |
| C14 | `_connectedAt` — `??=` вместо `=` (не обновлялся при реконнекте) | `lib/providers/vpn_provider.dart` | ✅ |
| C15 | `_openQrScan` — `setState()` после `Navigator.push` без mounted check | `lib/ui/screens/add_config_screen.dart` | ✅ |

## Batch 2 — утечки ресурсов, async ошибки, парсеры

| ID | Проблема | Файл | Статус |
|---|---|---|---|
| C5 | `http.Client` не закрыт в `_downloadFile` (утечка соединений) | `lib/providers/geo_provider.dart` | ✅ |
| C7 | `Future.microtask`/`Timer.periodic` без try-catch (vpn + geo + theme providers) | `lib/providers/vpn_provider.dart`, `geo_provider.dart`, `theme_provider.dart` | ✅ |
| C8 | `syncActiveSettings()` fire-and-forget | `lib/providers/settings_provider.dart` | ✅ |
| C9 | VMess parser — добавлены 12 полей (fp, pbk, sid, spx, pqv, flow, encryption, allowInsecure, pinSHA256, fm, alpn, ech) | `lib/protocols/xray/vless_parser.dart` | ✅ |
| C10 | Trojan parser — добавлены 7 полей (allowInsecure, pinSHA256, flow, encryption, fm, alpn, ech) | `lib/protocols/xray/vless_parser.dart` | ✅ |
| C11 | Hysteria2 parser — добавлены 3 поля (fp, alpn, ech) | `lib/protocols/xray/vless_parser.dart` | ✅ |

## Batch 3 — Android-native (Kotlin)

| ID | Проблема | Файл | Статус |
|---|---|---|---|
| A1 | **JSON injection** — `socksUser`/`socksPassword` писались через raw string interpolation в `socks_creds.json` | `XrayVpnService.kt:1512` | ✅ |
| A2 | **ProGuard** — отсутствовал `-keep class teapodcore.**`, release-сборка падает | `proguard-rules.pro` | ✅ |
| A3 | **Auto-reconnect игнорирует user disconnect** — после убийства процесса статический флаг сбрасывается, `user_disconnected.flag` не проверялся | `XrayVpnService.kt:377-378` | ✅ |
| A4 | **`startForegroundService` без `startForeground()`** — в `ACTION_DISCONNECT` не вызывалась `ensureForeground()`, Android 8+ убивает процесс | `XrayVpnService.kt:258` | ✅ |
| A5 | **TOCTOU race** — `reconnectInternal` мог запустить CONNECT_QUICK даже после того, как пользователь нажал Disconnect | `XrayVpnService.kt:1136` | ✅ |
| A6 | `allowIcmp` default `false` в `ConnectionParams` — несовместим с `true` в настройках | `ConnectionParams.kt:55` | ✅ |
|
| ## Batch 4 — race conditions, data loss, resource leaks |
|
| ID | Проблема | Файл | Статус |
|---|---|---|---|
| D1 | **Data loss** — `_editSubscriptionUrl` удалял старую подписку ДО fetch новой; при ошибке данные терялись навсегда | `lib/ui/screens/configs_screen.dart:646` | ✅ |
| D2 | **Missing \`@Volatile\`** — `tunInterface`, `statsThread` гонка между `startVpn`/`stopVpn` (утечка FD, пропущенный interrupt) | `XrayVpnService.kt:197-198` | ✅ |
| D3 | **Missing \`@Volatile\`** — `pendingNetworkRunnable` гонка между `ConnectivityManager` callback и `stopVpn` (спонтанный реконнект) | `XrayVpnService.kt:212` | ✅ |
| D4 | **Missing \`@Volatile\`** — `heartbeatThread` гонка между `startHeartbeat`/`stopHeartbeat` (пропущенный interrupt) | `XrayVpnService.kt:213` | ✅ |
| D5 | **Утечка \`http.Client\`** — 3 вызова `http.get()`/`http.head()` без `.close()` | `profile_provider.dart:203`, `deeplink_router.dart:106`, `geo_provider.dart:120` | ✅ |
