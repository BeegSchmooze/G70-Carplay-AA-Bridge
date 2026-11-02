# Leafia Plus — Genesis G70 Bridge

Wireless Android Auto, wireless CarPlay and Android Auto turn-by-turn on the
cluster/HUD for the **2022 Genesis G70** head unit, as a reversible
[NEMESIS](https://github.com/xwtk/hmg_nemesis) package. It builds on
[HMG Leafia Plus](https://github.com/VysseCodes/HMG-Leafia-Plus), which had no
patch set for this car's firmware, so every patch here was ported to it.

> Unofficial. Not affiliated with Hyundai, Kia, Genesis, Google, Apple, the
> NEMESIS project or HMG Leafia Plus. You use it at your own risk.

## Status (v0.96)

v0.96 has the same features as v0.95 ("update 15"). What's new is who can install
it: any head unit whose stock files match, not only one firmware version (see
[Compatibility](#compatibility)).

| Feature | State |
|---|---|
| Wireless Android Auto | Works |
| Wireless CarPlay (Bluetooth iAP2 bridge, Wi-Fi session, audio, volume) | Works |
| iPhone saved in the car's projection device list / Device Connections | Works (new in v0.95) |
| Android Auto turn-by-turn on the cluster and HUD | Works: turns, exits and forks drawn the way the car's own navigation draws them (arrow at the real angle), with the distance |
| Street name above the arrow on the HUD (Android Auto) | Works for turns, exits and forks; like the car's own navigation, icon steps (straight, merge, U-turn, roundabout) show no name |
| Distance count-down | Smooth: counts down from the car's speed between the phone's updates |
| First instruction from a standstill | Shows the first real turn instead of Google's "head toward …" step |
| Android Auto reconnect after walking away with the car running | Fix included (a stale session for the same phone is ended so it can reconnect); not yet confirmed on the car |
| Car navigation's own turn frames muted while the phone guides | Works; its speed-camera / trap frames still pass |
| Side roads drawn behind the arrow (Android Auto) | **Not yet**: the phone doesn't send them; planned from the car's map data |
| CarPlay turn-by-turn on the cluster and HUD | **In progress**: route guidance has to move into the CarPlay session when the iPhone drops Bluetooth. v0.95 adds that handover and fixes a stock DiPO bug that sent every message on that channel empty; not yet working on the car. Full CarPlay integration is the next milestone |

Joining another Wi-Fi network from the car's settings turns off the hotspot that
wireless Android Auto and CarPlay use; restart the head unit to get it back.

Work on the open items continues; see [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Requirements

- A head unit whose stock files match the ones the build was made from. It was
  built and tested on a **Genesis G70 2022, firmware
  `IKFL.USA.0000.V014.011.251120`**; other firmwares (and closely related cars)
  install only if every file the package changes is byte-identical. Run the
  compatibility check first (below).
- NEMESIS 1.15 or newer on the head unit.
- HMG Leafia Plus **`wireless.carplay.aa`** installed first (basic mode is
  enough): it provides the wireless feature flags and the hotspot.
- A FAT32 USB drive.

## Compatibility

`G70-Compat-Check.zip` (in the release, source in `tools/compat/`) is a
read-only NEMESIS script: unzip it onto the USB drive, plug it in, and it writes
`G70COMPAT-<n>/report.txt` with one line per file the package changes (MATCH or
DIFFERENT), whether Leafia is installed, and a result:

- **COMPATIBLE**: the package will install on your car.
- **NOT COMPATIBLE YET**: the report lists which files differ and which feature
  each one belongs to. A port for your firmware is possible: open an issue with
  the report, and send a run of the probe (`tools/probe`) privately.

The installer does the same check itself and refuses before changing anything
if a file doesn't match, so trying an install on an unmatched car is safe. It
just won't install. Every change is still built from the car's own stock files
and must match the tested build's checksum.

## Install

1. Download the release zip (`G70-Bridge-v0.96.zip`) and unzip it onto the root
   of the USB drive. You should have `NEMESIS.data` and
   `packages/g70.carplay.bt.zip` at the top level. Do not unzip
   `g70.carplay.bt.zip` itself.
2. Plug the drive into the car with the head unit on.
3. If an earlier build of this package is installed, NEMESIS first offers
   **uninstall**: accept it. Then accept **install**.
4. The head unit restarts. The first start after an install can take a few
   minutes, and Bluetooth may show "initializing" for a while; that is the apps
   being optimised once.

## Uninstall

NEMESIS Manager → Packages → `g70.carplay.bt` → Uninstall, then restart the head
unit. Every changed file, property and library goes back to stock byte for byte.

## How it is built

Nothing modified from Hyundai, Google or Apple is shipped. The package carries
only patch deltas (`package/files/*.lpd`). During install, Leafia's `lpatch`
rebuilds each app on the head unit from that unit's own stock files: it refuses
unless the stock `.odex` is exactly the expected original, and the rebuilt APK
must match the tested build's checksum. Native libraries are patched the same
way. The changes themselves are in [`src/patches/`](src/patches) as smali
diffs against the stock apps.

| Part | Change |
|---|---|
| `HKMC_DiPO` (CarPlay) | Bluetooth→iAP2 bridge, starts the CarPlay engine for wireless, audio source and focus, turn-by-turn gate opened, iPhone in the device list, iAP2 handover into the CarPlay session, drawn turns, stock iAP send-length bug fixed |
| `Iap2ServerApp` | Starts/ends the iAP2 session on the Bluetooth transport; advertises route guidance |
| `HKMC_GPM` (Android Auto) | Stuck-session, USB-drive and same-phone reconnect fixes; turn-by-turn sent straight to the cluster (port of HMG-API's AaTurns) with drawn turns, street name, lanes, smooth count-down |
| `HKMC_Navi_ExSL` (car navigation) | Skips its turn frames while the phone guides; logs what it sends to the cluster (diagnostics) |
| `libautoreceiver_infobank.so` | Leafia/NEMESIS `projection.tbt` navigation bridge, ported to this car's library build |
| `libCarPlayCore.so` | Leafia recipe: accept Wi-Fi CarPlay sessions |
| Leafia audio part | Unchanged (`package/comp/4_audio`) |

## Repository layout

```
package/          the NEMESIS package source (zip its contents to make g70.carplay.bt.zip)
src/patches/      smali diffs: stock app -> this build (new classes included)
src/java/         Java source of the bridge classes compiled into the apps
src/hooks/        the scripts that insert the calls into the apps' smali
tools/aa-lib-port library port scripts (see docs/TECHNICAL.md)
tools/checks/     reference/register checkers and the mock head-unit tests
tools/probe/      read-only diagnostic probe (NEMESIS execute script)
tools/compat/     read-only compatibility check (generated from the installer's checksums)
docs/             technical notes
```

## Diagnostics

`tools/probe` is a read-only NEMESIS script that writes logs to the USB drive.
Its output contains your phone names, Bluetooth addresses and vehicle data:
**don't post it publicly**.

## Licence and credits

GPL-3.0 (see `LICENSE`), with parts under AGPL-3.0; see [NOTICE.md](NOTICE.md).
Built on HMG Leafia Plus by VysseCodes and contributors, and on NEMESIS and
its community packages by xwtk and contributors.
