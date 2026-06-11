---
name: read-logs
description: >-
  Read IntelliNest's logs on this machine — the app's own os_log output (iOS Simulator or a
  connected device) and the error/warning lines forwarded into Home Assistant. Use when asked to
  read, tail, check, or grep the IntelliNest logs, or to debug what the running app logged.
allowed-tools: Bash, Read
---

# Reading IntelliNest logs

IntelliNest logs to two places. The app writes every `Log.info/error/warning/debug/verbose` call
(`IntelliNest/Utils/Extensions/LogExtension.swift`) to Apple's unified logging system. Since the
"Added error logs to Home Assistant" change, every **error** and **warning** is *also* forwarded to
Home Assistant's system log via `system_log.create`, tagged with logger `intellinest`. So the app's
own log is the full firehose; Home Assistant holds errors + warnings in one place alongside HA's
own logs.

Identifiers used below:

- os_log **subsystem**: `se.laross.IntelliNest`  •  **category**: `App`
- Home Assistant: `http://192.168.1.205:8123` (internal LAN URL)
- Forwarded HA logger name: `intellinest`

## 1. App logs from the iOS Simulator (most common on this Mac)

Simulator logs flow into the host's unified log. Use `simctl` against the booted simulator.

Live tail (all levels):

```bash
xcrun simctl spawn booted log stream \
  --level debug \
  --predicate 'subsystem == "se.laross.IntelliNest"'
```

Errors and warnings only (the formatter prefixes each line with `[ERROR]` / `[WARNING]`):

```bash
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "se.laross.IntelliNest" && (eventMessage CONTAINS "[ERROR]" || eventMessage CONTAINS "[WARNING]")'
```

Recent history instead of a live tail (last hour, including info/debug):

```bash
xcrun simctl spawn booted log show \
  --last 1h --info --debug \
  --predicate 'subsystem == "se.laross.IntelliNest"'
```

If nothing appears, confirm a simulator is booted (`xcrun simctl list devices booted`) and the app
has been launched so it has emitted at least one log line.

## 2. App logs from a physical iPhone

`simctl` only covers simulators. For a device plugged into this Mac:

- **Console.app** — open Console, select the device in the sidebar, click Start, and filter on
  `subsystem:se.laross.IntelliNest`. This is the simplest path for a real device.
- It is not capturable from a plain `log stream` on the Mac (that streams the Mac's own log, not
  the phone's).

## 3. Errors + warnings inside Home Assistant

These are the lines the app forwarded. Three ways to read them:

- **HA UI** — Settings → System → Logs, then filter/search for `intellinest`.
- **HA REST API** (scriptable, no UI). `GET /api/error_log` returns the whole log as plain text;
  grep it for the forwarded lines. The bearer token is the same long-lived Home Assistant token the
  app uses (kept in `IntelliNest-Info.xcconfig`, never committed — paste it inline, do not hardcode
  it into any committed file):

  ```bash
  curl -s -H "Authorization: Bearer <HA_LONG_LIVED_TOKEN>" \
    http://192.168.1.205:8123/api/error_log | grep -i intellinest
  ```

- **Log file on the HA host** — `/config/home-assistant.log` (via SSH or the Samba/File-editor
  add-on), again grep for `intellinest`.

## Reading the output

Each app log line is formatted as:

```
[LEVEL] [optionalTag] File.swift:42 functionName(_:) - <user>: <message>
```

so you can grep by level (`[ERROR]`), by source file, or by the acting user. The HA-forwarded lines
carry the identical text under the `intellinest` logger, which makes them easy to correlate with the
on-device log when chasing the same incident.
