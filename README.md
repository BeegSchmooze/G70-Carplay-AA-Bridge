# G70 CarPlay / AA Bridge

Wireless Android Auto and wireless CarPlay, with turn-by-turn from both on the
cluster/HUD, for the **2022 Genesis G70** head unit, as a reversible
[NEMESIS](https://github.com/xwtk/hmg_nemesis) package. It started from
[HMG Leafia Plus](https://github.com/VysseCodes/HMG-Leafia-Plus), which had no
patch set for this car's firmware, so every patch here was ported to it. Since
v1.1 it is **standalone**: HMG Leafia Plus does not need to be installed.

> Unofficial. Not affiliated with Hyundai, Kia, Genesis, Google, Apple, the
> NEMESIS project or HMG Leafia Plus. You use it at your own risk.

## Status (v1.1)

v1.1 ("update 22") makes the package standalone. It now turns on the wireless
CarPlay / Android Auto features and the Wi-Fi hotspot itself, which used to need
HMG Leafia Plus's `wireless.carplay.aa`. It also adds speed and red-light camera
alerts on the HUD from your own camera list. v1.0 brought Apple Maps
turn-by-turn and the now-playing track to the cluster and HUD. As since v0.96,
it installs on any head unit whose stock files match (see
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
| CarPlay turn-by-turn on the cluster and HUD | Works (new in v1.0): Apple Maps turns with the distance. Tested parked and on short routes; rerouting not yet tested on the car |
| CarPlay now playing on the cluster and HUD | Works (new in v1.0): track title and changes |
| CarPlay call state on the cluster | Requested from the iPhone; not yet tested on the car |
| Speed / red-light camera alerts on the HUD | Works (new in v1.1), from a camera list you supply (see [Camera alerts](#camera-alerts)). The camera icon takes the place of the speed-limit sign, with the distance; the cluster also shows its own "uneven road ahead" notice and chime |
| Standalone wireless setup (no HMG Leafia Plus) | New in v1.1; tested in the mock head unit on factory files and confirmed on a second G70 |

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
- A FAT32 USB drive.

HMG Leafia Plus is **not** needed. If its `wireless.carplay.aa` is already
installed, the bridge leaves the settings it made alone and works alongside it.
To keep things simple, uninstall it first (NEMESIS Manager → Packages) and
restart the head unit; the bridge then turns everything on itself.

## Compatibility

`G70-Compat-Check.zip` (in the release, source in `tools/compat/`) is a
read-only NEMESIS script: unzip it onto the USB drive, plug it in, and it writes
`G70COMPAT-<n>/report.txt` with one line per file the package changes (MATCH or
DIFFERENT), whether the wireless features are already on, and a result:

- **COMPATIBLE**: the package will install on your car.
- **NOT COMPATIBLE YET**: the report lists which files differ and which feature
  each one belongs to. A port for your firmware is possible: open an issue with
  the report, and send a run of the probe (`tools/probe`) privately.

The installer does the same check itself and refuses before changing anything
if a file doesn't match, so trying an install on an unmatched car is safe. It
just won't install. Every change is still built from the car's own stock files
and must match the tested build's checksum.

## Install

1. Download the release zip (`G70-Bridge-v1.1.zip`) and unzip it onto the root
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
unit. Every changed file, property and library goes back to stock byte for byte,
including the wireless settings, if the bridge was the one that turned them on.

## Camera alerts

The bridge ships no camera data. Put your own list on the head unit with
`tools/cameras` (a NEMESIS execute script): copy its two files and your
`cameras.csv` to the root of a USB drive, plug it in and confirm. It copies the
list to `/data/leafia/cameras.csv` and writes `G70CAMERAS-<n>/result.txt`. Run it
with no `cameras.csv` on the drive to remove the list and turn alerts off.

The CSV is `lat,lon,type,speed,heading,f2,category` with a header line (type
`redlight` = red-light camera, anything else = speed camera; heading 360 = any
direction; f2 1 = one direction, 2 = both). Alerts start 0.3 mi before a camera
(0.5 mi from 45 mph) and use the car's own GPS, with or without navigation.

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
| `HKMC_DiPO` (CarPlay) | Bluetooth→iAP2 bridge, starts the CarPlay engine for wireless, audio source and focus, iAP2 notifications let through for wireless sessions, iPhone in the device list, iAP2 handover into the CarPlay session, now playing and call state requested over wireless, drawn turns; stock bugs fixed: iAP send length, maneuver index |
| `Iap2ServerApp` | Starts/ends the iAP2 session on the Bluetooth transport; advertises route guidance |
| `HKMC_GPM` (Android Auto) | Stuck-session, USB-drive and same-phone reconnect fixes; turn-by-turn sent straight to the cluster (port of HMG-API's AaTurns) with drawn turns, street name, lanes, smooth count-down; camera list matched against GPS |
| `HKMC_Navi_ExSL` (car navigation) | Skips its turn frames while the phone guides; shows camera alerts in its speed-limit frames; logs what it sends to the cluster (diagnostics) |
| Wireless settings | Wireless CarPlay / Android Auto and Wi-Fi feature files added, `featurexml.cfg`'s removal of them and of the hotspot commented out, `persist.ium.support=carplay`; each left alone when already in place |
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
tools/cameras/    puts your camera list on the head unit (no camera data included)
docs/             technical notes
```

## Diagnostics

`tools/probe` is a read-only NEMESIS script that writes logs to the USB drive.
Its output contains your phone names, Bluetooth addresses and vehicle data:
**don't post it publicly**.

By default it collects logs only, gzipped (a few MB). A file named
`G70PROBE-FULL` on the drive root makes it also copy the stock apps and
libraries a port needs (about 70 MB). Its first run after a head-unit restart
starts a background logger that records until the next restart. To capture a
test, run the probe once before it and again afterwards.

## Licence and credits

GPL-3.0 (see `LICENSE`), with parts under AGPL-3.0; see [NOTICE.md](NOTICE.md).
Built on HMG Leafia Plus by VysseCodes and contributors, and on NEMESIS and
its community packages by xwtk and contributors.
