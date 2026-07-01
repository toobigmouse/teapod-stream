# Исправления / Fixes

| # | Проблема | Решение | Файл |
|---|---|---|---|
| 1 | **Android crash** — `AppLogger.init()` синхронный, `Directory` не существует на Android | Сделал `async`, добавил `getApplicationDocumentsDirectory()` для Android, создание папки если нет | `lib/core/services/app_logger.dart` |
| 2 | **`main()` падал на Windows** — `File('\\debug.log')` использовал `\` вместо `Platform.pathSeparator` | Убрал хардкод `\`, `AppLogger` сам возвращает правильный путь | `lib/main.dart` |
| 3 | **Окно сворачивалось а не выходило** — `SetQuitOnClose(true)` отсутствовал | Добавлен в `main.cpp` | `windows/runner/main.cpp:87` |
| 4 | **Второй экземпляр не блокировался** — Dart-овый `CreateMutexW` не работал из-за GC/FFI нюансов | Перенёс проверку в нативный C++ `CreateMutexW` в `wWinMain`, до старта Dart VM | `windows/runner/main.cpp:36-46` |
| 5 | **Белый экран после `FindWindow`** — Win32 API из Dart падал на старте | Заменил `FindWindow` на нативный mutex, Dart-функция теперь no-op | `lib/core/services/window_manager.dart`, `windows/runner/main.cpp` |
| 6 | **Нет popup-меню в трее** — только "Показать" и "Выход" | Добавил "Добавить конфигурацию", "Добавить подписку", "Закрыть приложение" с навигацией через колбэки | `lib/core/services/tray_manager.dart`, `lib/app.dart` |
| 7 | **Меню в трее не появлялось** — `system_tray` не авто-показывает контекстное меню при правом клике | Добавил обработку `rightMouseDown`/`rightMouseUp` + вызов `popUpContextMenu()` | `lib/core/services/tray_manager.dart` |
