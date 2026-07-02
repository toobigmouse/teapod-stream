# Исправления — Android (fix/android)

## Batch 1 — целостность данных и утечки

| ID | Проблема | Файл | Статус |
|---|---|---|---|
| C1 | `_editConfig` терял 16 полей (password, method, fingerprint, alpn, ech, rawXrayConfig...) при редактировании URI | `lib/ui/screens/configs_screen.dart` | ✅ |
| C2 | `importBundle` терял 7 полей (lastPingedAt, allowInsecure, pinSHA256, finalmask, alpn, ech, rawXrayConfig) при импорте | `lib/providers/config_provider.dart` | ✅ |
| C3 | `apps_provider` использовал `ref.read` вместо `ref.watch` — UI split-tunnel не обновлялся после переключения excluded | `lib/providers/apps_provider.dart` | ✅ |
| C4 | 7× `TextEditingController` без `.dispose()` (утечка памяти в диалогах); 2× `MediaQuery.of(context)` вместо `ctx` | `lib/ui/screens/configs_screen.dart`, `profiles_screen.dart` | ✅ |
| C6 | `refreshStaleSubscriptions` — одна упавшая подписка обрывала цикл обновления всех | `lib/providers/config_provider.dart` | ✅ |
| C12 | `state.value?.activeConfigId` без `.hasValue` guard (фragile) | `lib/providers/config_provider.dart` | ✅ |
| C13 | `_current!` — краш если `ProfileNotifier` не загружен | `lib/providers/profile_provider.dart` | ✅ |
| C14 | `_connectedAt` — `??=` вместо `=` (не обновлялся при реконнекте) | `lib/providers/vpn_provider.dart` | ✅ |
| C15 | `_openQrScan` — `setState()` после `Navigator.push` без mounted check | `lib/ui/screens/add_config_screen.dart` | ✅ |

## План на следующие batch

| ID | Проблема | Файл | Статус |
|---|---|---|---|
| C5 | `http.Client` не закрыт в `_downloadFile` (утечка соединений) | `lib/providers/geo_provider.dart` | ⏳ |
| C7 | `Future.microtask` без try-catch (`vpn_provider.dart:126-153`); `Timer.periodic` без try-catch (`vpn_provider.dart:118-123`) | `lib/providers/vpn_provider.dart`, `geo_provider.dart` | ⏳ |
| C8 | `syncActiveSettings()` fire-and-forget в `settings_provider.dart:20` | `lib/providers/settings_provider.dart` | ⏳ |
| C9 | VMess parser не читает 12 полей (TLS fingerprint, Reality, ALPN, ECH...) | `lib/protocols/xray/vless_parser.dart` | ⏳ |
| C10 | Trojan parser не читает 7 полей (allowInsecure, pinSHA256, alpn, ech...) | `lib/protocols/xray/vless_parser.dart` | ⏳ |
| C11 | Hysteria2 parser не читает 3 поля (alpn, ech, fingerprint) | `lib/protocols/xray/vless_parser.dart` | ⏳ |
