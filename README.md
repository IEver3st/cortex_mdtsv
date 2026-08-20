# Cortex MDT

A FiveM Mobile Data Terminal (MDT) resource built with a Svelte 5 NUI, supporting law‑enforcement and standalone civilian modes, multi‑framework auto‑detection, and records management for officers, citizens, vehicles, reports, cases, evidence, weapons, citations, CCTV and bodycams.

![GitHub Release](https://img.shields.io/github/v/release/IEver3st/cortex_mdtsv?logo=github)
![Platform](https://img.shields.io/badge/platform-FiveM-ff6b00)
![Lua](https://img.shields.io/badge/language-Lua-000080)
![Svelte](https://img.shields.io/badge/language-Svelte-ff3e00?logo=svelte)

## Overview

Cortex MDT provides an in‑game tablet interface for police, sheriff, highway patrol, fire/EMS and towing personnel, plus a separate civilian self‑service portal. The resource can run on its own (standalone/local JSON storage) or integrate with `qbx_core`, `night_ers` / `ers` / `EmergencyResponseSimulator`, and optional dispatch resources (`cortex-dispatch`, `ps-dispatch`).

## Features

- **Dual UI modes** — officer/PD mode and standalone civilian mode, toggled via commands and keybind.
- **Framework auto‑detection** — `auto`, `qbx`, `ers`, or `standalone` in `shared/config.lua`.
- **Officer management** — profiles, callsigns, ranks, departments, certifications, avatars, duty status and unit status.
- **Citizen records** — profiles, licenses, tags/flags, fingerprints, notes and vehicle ownership.
- **Vehicles** — plate/VIN search, registration status, flags and impound lot tracking.
- **Reports & cases** — report templates, timeline, participants, charges, linked entities and case management.
- **Evidence** — typed evidence log with attachments and transfer history.
- **BOLOs and warrants** — create, view and update active alerts.
- **Weapons** — weapon records and analytics.
- **Roster, leaderboard and FTO** — personnel and training records.
- **Camera operations** — static CCTV, demand-driven bodycams, automatic emergency-vehicle dashcams, and optional synchronized Cortex PolCam mirrors in one registry.
- **Command workspace** — persistent bulletins, awards, Internal Affairs, personnel reviews, court records, SOP directives and patrol plans with department visibility, revision history and audit entries.
- **Public complaints** — a standalone-safe Internal Affairs intake available from the civilian portal, `/complaint`, or the `openComplaint` client export.
- **Dispatch board** — internal dispatch view plus optional bridge to `cortex-dispatch` or `ps-dispatch`; supports panic and traffic‑stop call creation.
- **Offline runtime assets** — the dispatch grid, default camera preview, profile placeholder and UI fonts require no public CDN.
- **Citations** — issue citations from reports; civilians can view them with `/showcitation` or an inventory item.
- **Dashboard** — announcements, quick search, stats and recent activity.
- **Settings** — themes, UI scale, hotkeys, quick actions and tablet emote toggle.
- **Audit logging** — file‑backed NDJSON audit logs with configurable retention.

## Requirements

- A FiveM FXServer running the Cfx runtime.
- The resource `cortex-lib` must be installed and started before `cortex_mdtsv` (`fxmanifest.lua` declares this dependency).
- For SQL‑backed framework modes (e.g., `qbx`): a MySQL/MariaDB database and a compatible `MySQL` resource such as `oxmysql`.
- Optional integrations:
  - `qbx_core` for QBox framework data.
  - `night_ers`, `ers`, or `EmergencyResponseSimulator` for ERS mode.
  - `rpemotes` / `rpemotes-reborn` for the tablet emote.
  - `cortex-dispatch` or `ps-dispatch` for external dispatch bridging.
  - `cortex-hud` for bodycam HUD hide/show.
  - `cortex_polcam` for synchronized, read-only helicopter-camera feeds.

## Installation

1. Copy or clone the `cortex_mdtsv` folder into your server `resources` directory, e.g. `resources/[eco]/cortex_mdtsv`.
2. Make sure `cortex-lib` is installed and started before this resource.
3. If you are using a database‑backed framework mode, run `sql/schema.sql` against your MySQL/MariaDB database. Apply any additional `sql/migrate_*.sql` files that match your current schema version.
4. (Optional) Rebuild the UI:
   ```bash
   cd web
   bun install
   bun run build
   ```
   `vite.config.js` writes the compiled output to the `html/` folder, which is what the `fxmanifest.lua` `ui_page` points to.
5. Add `ensure [eco]/cortex_mdtsv` (or `ensure cortex_mdtsv`) to your `server.cfg`.
6. Configure `shared/config.lua` for your framework, departments, ranks, commands, keybinds and optional integrations.

## Standalone setup

Set `Config.FrameworkMode = 'standalone'` and start `cortex-lib` before `cortex_mdtsv`. No SQL resource or schema import is required in this mode. `/police [callsign]` registers the player on duty, `/mdt` or `F6` opens the officer terminal, and `/civilian` opens the civilian portal.

Standalone records are persisted under `data/localStorage.json`. Writes are debounced, JSON-verified, and replaced atomically; the previous valid file is retained as `data/localStorage.json.bak`. Keep both files writable and preserve `localStorage.json` when updating the resource. Set `Config.StandalonePersistence.enabled = false` only if session-only standalone records are intentional.

## Commands

| Command | Purpose |
| --- | --- |
| `/mdt` | Open or close the authorised officer terminal. The default key mapping is `F6`. |
| `/police [callsign]` | Enter officer duty in standalone mode, optionally with a callsign. |
| `/civilian` | Open or close the civilian self-service portal. |
| `/bodycam` | Toggle the on-duty officer's bodycam availability. |
| `/complaint` | Open the public Internal Affairs complaint form without officer access. |
| `/showcitation` | Open the civilian citation viewer when citations are enabled. |

The complaint form is also available to client resources through `exports.cortex_mdtsv:openComplaint()`.

## ACE permissions

Administrative MDT callbacks are denied unless the player has the configured ACE. The default administrative grant is:

```cfg
add_ace group.admin "cortex_mdt.admin" allow
add_ace group.admin "cortex_mdt.cctv.admin" allow
add_ace group.admin "cortex_mdt.manage" allow
```

QBX officer access is limited to jobs mapped into `Config.Departments`; ERS access requires an active configured service shift. Standalone officer access remains open by default and can be restricted with `Config.Access.standaloneOfficerAce`.

For example, set `Config.Access.standaloneOfficerAce = 'cortex_mdt.officer'`, then grant that ACE to the server principal used by officers:

```cfg
add_ace group.police "cortex_mdt.officer" allow
```

`cortex_mdt.admin` controls general administrative mutations, `cortex_mdt.cctv.admin` controls static-camera management, and `cortex_mdt.manage` controls Command workspace mutations and management-only records. Department/rank policy still applies where configured.

## Camera setup

### Bodycams

On-duty officers are available automatically unless they opt out with `/bodycam`. Frames are requested only while an authorised viewer is watching, are checked against the source player's server-owned position and routing bucket, and stop when the source or viewer leaves duty.

Bodycam audio is intentionally proximity-only. It can adjust a Mumble voice that the viewer already receives, but it cannot hear a distant officer, capture radio or call audio, or replace `pma-voice` routing.

### Dashcams

Dashcams are discovered automatically when an on-duty officer is driving a networked vehicle in `Config.Dashcams.emergencyVehicleClass` (class `18` by default). The server publishes the vehicle model and transform; the viewer applies the configured local-space camera offset. Default front and rear positions make standalone setup work without a vehicle list.

Tune individual models by spawn name. Native Cortex offsets use `x = right`, `y = forward`, and `z = up`, in metres:

```lua
Config.Dashcams.modelOffsets = {
    ['police'] = {
        front = { x = 0.0, y = 0.75, z = 0.55, pitch = 1.0 },
        rear = { x = 0.0, y = -1.20, z = 0.60, pitch = 1.0 },
    },
}
```

Project Sloth-style entries can be copied directly as well:

```lua
Config.Dashcams.modelOffsets = {
    ['police2'] = {
        side = 0.0,
        forward = 1.10,
        height = 0.85,
        pitch = -6.0,
        rearForward = 1.30,
        rearHeight = 0.80,
        rearPitch = -4.0,
    },
}
```

### Cortex PolCam

`cortex_polcam` is optional. When it is started, the MDT reads its active-feed exports and mirrors operator position, FOV, normal/night/thermal vision, and target lock for authorised viewers in the same routing bucket. The MDT view is read-only, so its controls cannot move or change the helicopter operator's camera. Start `cortex_polcam` before `cortex_mdtsv` when using this integration; without it, the rest of the MDT and camera registry continue to work.

## Command and parity modules

The Command page provides durable bulletins, awards, Internal Affairs records, personnel performance reviews, court records, SOP directives, and patrol plans. Records support bounded input, department or management visibility, configurable cross-department sharing, optimistic version conflicts, and audit attribution. SOP acknowledgements are attached to the exact document revision, so a revised directive requires a new acknowledgement.

Use `Config.FeatureParity.features` to enable individual modules, `Config.FeatureParity.manageAce` for mutation access, and `Config.DepartmentSharing` for mutual or one-way visibility between departments.

## Configuration

All runtime configuration lives in `shared/config.lua`:

| Key | Description |
| --- | --- |
| `Config.FrameworkMode` | `auto`, `standalone`, `qbx` or `ers` |
| `Config.FrameworkAutoDetectPriority` | Order used when `FrameworkMode = 'auto'` |
| `Config.Access` | Standalone officer and mandatory administrative ACE policy |
| `Config.OpenCommand` | Command to open the MDT (default: `mdt`) |
| `Config.CivilianCommand` | Command to enter civilian mode (default: `civilian`) |
| `Config.PoliceCommand` | Command to enter officer duty mode (default: `police`) |
| `Config.OpenKey` | Keybind to open the MDT (default: `F6`) |
| `Config.MDTTabletEmote` | Tablet emote settings; set to `false` to disable |
| `Config.AuditLogs` | File‑based audit log retention and size limits |
| `Config.StandaloneCivilianMode` | Settings for standalone/local citizen generation |
| `Config.StandalonePersistence` | Durable standalone record snapshots and write debounce |
| `Config.ErsIntegration` | NPC‑to‑citizen intake for ERS |
| `Config.Departments` / `Config.Ranks` | Departments and rank ladders |
| `Config.Certifications` | Officer certifications |
| `Config.ReportTemplates` | Report templates |
| `Config.EvidenceTypes` | Evidence type list |
| `Config.CitizenFlags` | Flag labels and colors |
| `Config.ImpoundLots` | Impound lot locations |
| `Config.CameraModels` | Static CCTV prop model map |
| `Config.Bodycams` / `Config.Dashcams` | Live feed availability, limits, routing buckets and per-model positions |
| `Config.AirSupport` | Optional Cortex PolCam resource and synchronization settings |
| `Config.FeatureParity` | Command modules, public complaint command and management ACE |
| `Config.DepartmentSharing` | Cross-department visibility for Command records |
| `Config.Dispatch` | Dispatch board and bridge settings |

## Architecture

- `fxmanifest.lua` declares `version '1.0.0'`, `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, `dependency 'cortex-lib'`, and points `ui_page` at `html/index.html`.
- **Client** — `client/main.lua` is the entry point for commands, NUI callbacks, server callbacks, vehicle context, complaints, emotes and UI show/hide. `client/cameras.lua` renders CCTV, bodycam, dashcam and PolCam views. `client/dispatch.lua` handles live unit coordinates and dispatch blips.
- **Server** — `server/main.lua` sets up framework detection, the callback registry, officer/civilian profile building and core events. `server/data.lua` contains data access and business logic. `server/parity.lua` owns Command records, SOP acknowledgements and public complaints. `server/dispatch.lua` runs the dispatch board and external bridges. `server/cameras.lua` owns camera persistence, feed discovery, viewer authorization and synchronized frames. Framework providers live under `server/framework/`, storage under `server/storage/`, and page handlers under `server/pages/`.
- **Shared** — `shared/config.lua` is loaded by both client and server and defines all configurable tables.
- **Web UI** — `web/` is a Svelte 5 application built with Vite and Tailwind CSS. It is output to `html/` for runtime use by FiveM's NUI system.

## Building the UI

The repository ships with prebuilt assets in `html/`. To rebuild after editing the Svelte source:

```bash
cd web
bun install
bun run build
```

This empties `html/` and writes new compiled JS/CSS/index files. The game manifest then loads `html/index.html`.

## SQL Setup

For database modes, execute the table definitions in `sql/schema.sql` against your server database. If you are migrating an older install, run any matching `sql/migrate_*.sql` scripts in order. The schema uses MySQL/MariaDB with `utf8mb4` encoding.

## Limitations

- Released under the [MIT License](LICENSE).
- Release archives do not include `node_modules` or `web/node_modules`.
- SQL‑backed modes require an active MySQL/MariaDB connection compatible with the `MySQL` global.
- Live bodycam and dashcam synchronization requires OneSync-compatible server entity natives.
- Bodycam audio only exposes voice already routed by Mumble proximity; it is not remote surveillance audio.
- Helicopter feeds require the optional `cortex_polcam` resource and are intentionally read-only in the MDT.
- The resource exports `getOfficerData`, `isOfficerOnDuty` and `getFrameworkMode` for external use.

## Disclaimer

Cortex MDT is an independent, community‑made FiveM resource. It is **not affiliated with, endorsed by, or sponsored by Rockstar Games, Take‑Two Interactive, or Cfx.re**. *Grand Theft Auto*, *GTA*, *FiveM* and related marks are trademarks of their respective owners.
