# Session — TeapodStream Windows

## Current state (committed)

**Branch**: `master` (2 ahead of `origin/master`)
**Last commit**: `37d6cca` — fix Windows TUN routing loop + FakeDNS
**Tree**: clean (all changes restored)

## Approach in code

- **TUN mode** (system stack, MTU 1500, `autoRoute: true`)
- **FakeDNS** enabled — returns 198.18.x.x fake IPs for domain-based routing
- **`sendThrough`** on DIRECT (freedom) outbound — binds to physical adapter IP to break routing loop
- **`_getPhysicalAdapterIp()`** via PowerShell — filters out virtual adapters
- **SOCKS5 inbound** with auth (`$socksUser/$socksPassword`)
- **Admin check** (`_isAdmin()`) — TUN mode requires admin rights

## Problem

Full/Only modes don't work. Bypass mode works.

Root cause: `sendThrough` cannot bypass TUN routing on Windows (no SO_MARK). The DIRECT outbound's socket still matches TUN routes and loops back.

FakeDNS makes it worse: DIRECT outbound receives fake IP (198.18.x.x) and can't resolve the real IP.

## Untracked files

- `SESSION.md` — this file
- `teapod_connect.ahk` — AutoHotkey helper script

## Q: Что делать с DIRECT outbound?

Давай сначала подумаем. У нас сейчас TUN роутинг и sendThrough на direct outbound. sendThrough не обходит TUN на Windows — нет SO_MARK.

**Вариант A**: Убрать TUN, оставить system proxy только для HTTP. Не требует админа, работает из коробки. Но:
- SOCKS5 auth нужна (ключевая функция)
- HTTP inbound можно добавить без пароля
- SOCKS5 inbound оставить с паролем

**Вариант B**: Оставить TUN, но как-то чинить DIRECT. Проблема — нет SO_MARK, sendThrough не работает.

**Вариант C**: TUN + system proxy. TUN ловит весь трафик, но DIRECT outbound идёт через system proxy (HTTP) вместо физического адаптера. Не циклится.

Выбирай вариант, скажи — сделаем.
