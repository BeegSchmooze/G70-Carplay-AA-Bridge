# Technical notes — Genesis G70 (IKFL.USA 251120, 250818, 260507)

Head unit: Telechips TCC803x, Android 4.4.2 (Dalvik), `ro.product.opt.stepofspec = 95`.
No app or library on this firmware matched any car HMG Leafia Plus supports, so
everything was ported by hand. Tools: baksmali/smali 2.5.2 (`-a 18`), the
reference and register checkers in `tools/checks`, and a mock head unit that
runs the real ARM `lpatch` under qemu (`tools/checks/mock-test.sh`).

## Wireless Android Auto (GPM)

- A failed wireless attempt left `GalConnectionManager` in start mode 2 with no
  session ("Already AA Starting mode"); the session is now recreated.
- A USB drive (mass storage / hub) made GPM start a wired attempt that blocked
  wireless until restart; `StartReceiver` now ignores class 8/9 devices.

## Wireless CarPlay (DiPO + Iap2ServerApp)

- The car dials the iPhone's iAP2 RFCOMM service through Broadcom BTCM, but no
  app pumped that link into the iAP2 server. A bridge in DiPO carries the
  Bluetooth SPP data to `Iap2SvcTransportReadDone`; `Iap2ServiceReceiver.onReceive`
  (empty in the US build) starts/ends the session.
- On units with stepofspec ≥ 0 the CarPlay engine starts only after a *USB*
  iAP2 authentication; the bridge starts it for wireless (`LeafiaDipoStart`).
- `e/m.onControllerAdded` is empty in the US build; wireless controllers now call
  `connectCarPlay`.
- `e/b.K()` (iPhone id) is null for Bluetooth sessions and crashed `dipoActivated`;
  it falls back to the bridge's session address.
- Audio: a wireless session never switched the source (now `changeMode(115)`)
  and DiPO only requests audio focus when it thinks iAP2 is connected (now set
  when the bridge session starts).

## Turn-by-turn: the firmware gates

Every turn-by-turn path is gated on `stepofspec >= 999`; this car is 95:

| Where | Gate | Patch |
|---|---|---|
| DiPO `i/e.jx()` | route-guidance listener, cluster analyzer `e/u` | returns true |
| Iap2ServerApp `Iap2InitInformationMsg` | advertises RouteGuidanceDisplay | always advertised |
| GPM `GalConnectionSession` ctor | creates `GpmNaviTBTManager` | always created |

## Android Auto navigation bridge (libautoreceiver_infobank.so)

Modern phones send `NavigationState` (0x8006) and `NavigationCurrentPosition`
(0x8007); the stock library drops them. The NEMESIS `projection.tbt` patch adds
a 9th PT_LOAD with self-contained code, hooks
`NavigationStatusEndpoint::routeMessage`+0xe8, `Controller::sendVersionRequest`+0x12
and `RdsType_IsValid`, and reaches the library through a 5-entry relative table.

G70 port (`tools/aa-lib-port`): same segment layout as the US library, different
code addresses. The four byte runs the original delta copied from US stock were
recovered (each found exactly once in G70 stock). Table: thunk
`navigationNextTurnCallback` 0xaef3f, thunk `navigationNextTurnDistanceCallback`
0xaeeaf, string range-init 0xa64dd, `_M_deallocate_block` 0xa6455, return
0xbccb5. Hook registers at 0xbccb0 match the US build (r4 = endpoint, r2 = type,
r6 = data, r5 = length). A logging stub (tag `LeafiaAA`) prints each message type.

What the bridge sends GPM:

| Call | Meaning |
|---|---|
| next turn, event < 0x20 | real maneuver (43 modern maneuver types mapped to the old event + side) |
| next turn, 0x20 / 0x22 / 0x43 / "P …" | bridge's own (current road, clear, dumps) — dropped |
| next turn, 0x40+n | upcoming-step list — dropped in v0.9 |
| distance (meters, 0, display e3, unit) | distance to the next turn — used |
| distance, unit 0x100 \| u | distance to destination — dropped |
| distance, unit 0x200 \| … | lane data — dropped |

GPM fixes: stock sent an all -1 trap frame after every update (blanked the
arrow) — now a no-op; GPM sends only turn data, never navi-alive / operation
status (as HMG Leafia Plus found, those leave the cluster in phone mode); the
turn is only shown within 1 mile (v0.9).

## Car navigation muting

The car navigation sends turn frames every ~0.5 s even with no route, which
overwrite the phone's. While the phone guides, DiPO / GPM stamp
`sys.leafia.phonetbt`; the navigation app skips its turn display frames
(types 0/2/3/0x64/0x65/0x66, 0x4c–0x4e) while the stamp is fresh. Trap /
camera frames still pass.

## v0.95 (update 15)

- **Drawn turns and the HUD street name** (Android Auto, `LeafiaAaTurns`): the
  car's navigation engine sends drawn display types to the cluster (13 turn at
  an intersection with direction and side-street bits, 17/18 exit right/left,
  25 fork), not fixed icons. The HUD shows the street name only for those: a
  name sent with an icon type (0x40 and up) is blanked, as the engine itself
  does. Direction is degrees clockwise from straight ahead; side-street bits:
  0x1 ahead, bits 1-7 right (22.5° bins), bits 8-14 left, none for behind. The
  turn list (`updateTPTurnListNew`, F2 frame) uses the engine's layout (count up
  to 3, three types, name of turn 1 in UTF-16LE plus one zero byte) and its
  two-step order (clear frame first); the cross name and the list share one
  transport channel, so they go out at least 700 ms apart.
- **Same-phone reconnect** (`LeafiaAaRestart`): when the same phone restarts
  wireless negotiation while a stale session holds, the stale session is ended
  so the phone's retry starts clean.
- **iPhone in the device list** (`LeafiaCpRegister`): Device Connections and
  auto connection read PhoneProjection's wireless device list, which only GPM
  filled. DiPO now reports the iPhone (add, ready, connecting, connected) at
  every wireless CarPlay session start, and disconnected when CarPlay ends (not
  when Bluetooth drops, which every wireless session does).
- **CarPlay iAP2 handover** (`LeafiaCpHandover`, HMG-API's design): when the
  iPhone drops Bluetooth during wireless CarPlay, the iAP2 server starts a
  session on the CarPlay client component (5); iPhone→car through
  `CarPlayService.oniAPSendMessage`, car→iPhone through notification 0x51 and
  `CarPlayService.iAPSendMessage`; route guidance is restarted on it, retried
  until the server accepts it. Stock bug fixed for this:
  `CarPlayService$1iAPSendMessage.setMsgDataLen` (non-blocking send) stored the
  length only when its own field was outside the int range, so every message
  reached `TccCarPlay_iAPSendMessage` with size 0.
- **CarPlay drawn turns** (`LeafiaCpTurn`): iAP2 maneuvers at an intersection
  become drawn turns, with the direction from the exit angle and side roads
  from the junction's road angles; plus the HUD distance.

## v1.0 (update 20): CarPlay turn-by-turn and now playing

Four things stood between the iPhone's route guidance and the cluster on a
wireless session; v1.0 fixes all of them (`LeafiaCpHandover`, `hooks16_dipo.py`,
`hooks19_dipo.py`).

- **DiPO's notification gate.** DiPO's iAP2 listener (`e/g`) passes
  notifications on only while its notify flag is set, and only a connect with a
  device serial sets it. The iAP2 server reports wireless sessions without a
  serial, so every notification was dropped. The hook sets the flag for a
  bridged wireless session. The first argument of `IIap2Listener.connected` is
  the iAP2 **component** (`Iap2Service.onSendConnected` passes `getComponent()`:
  1 USB, 4 the Bluetooth link, 5 the CarPlay channel), not a result code.
- **Which notifications reach DiPO.** For a bridged session, only data
  notifications pass: telephony (30-32), now playing (36-38) and route guidance
  (0x78-0x7a). Identification (0), transport identifier (24), USB device info
  (25) and the session callbacks (10/11/15/16) stay out, because they drive
  DiPO's USB new-device path. Each notification number is logged once per
  session (`Leafia: first iAP2 notification N`).
- **Now playing and call state.** DiPO's `setStartiAP2Service` asks the iPhone
  for now playing and call state only on USB; wireless (transport 1) skips them.
  The handover requests them on the CarPlay channel once route guidance is
  accepted.
- **Stock maneuver-index bug.** `e/u.d` (analyze_ManeuverUpdate) has
  `GetComponentIdsFromManeuverMsg` inlined. It writes the maneuver index into a
  clone of `maneuverIndex[]` and then checks the original, still -1, so every
  RouteGuidanceManeuverUpdate was dropped and `updateTBTInfo` never found the
  current maneuver. `hooks19_dipo.py` writes into the array itself.
- The CarPlay-channel send uses the library's native `iAPSendMessage` directly
  (in order), instead of DiPO's thread-per-message send, which could reorder
  messages.

## v1.1 (update 22): standalone, camera alerts

### Wireless settings (no HMG Leafia Plus)

The head unit offers wireless CarPlay / Android Auto only when PackageManager has
the two connectivity features, `featurexml.cfg` (in `ro.mobis.targetdir`) doesn't
remove them at boot, and `persist.ium.support=carplay`. A factory G70's
`featurexml.cfg` also removes `com.hkmc.software.wifihotspot.xml`, the hotspot
both projections run on, and some units have no `android.hardware.wifi.xml`.
The installer (the projection part of `scripts/common.sh`) does what Leafia
1.x's slim `wireless.projection` did:

- adds the carplay_wireless / androidauto_wireless feature files when absent;
- comments out `featurexml.cfg`'s removal lines (both wireless features and the
  hotspot) and, when the hotspot was removed, adds the hotspot / Wi-Fi feature
  files that are missing;
- sets `persist.ium.support=carplay` in `build.prop` when it isn't there.

Each item is checked first and recorded (`add.<file>` markers, backups of
`featurexml.cfg` and `build.prop`); what is already in place (stock, or
Leafia's) is left alone, so uninstall undoes only what the bridge changed.

The head unit's `grep` has no `\|` alternation: such a pattern never matches,
which made a first standalone build miss the removal lines on a factory unit.
The `featurexml.cfg` checks use shell `case` matching. The mock head unit
(`tools/checks/mock-test.sh`, `mock-upgrade.sh`) stubs `grep` the same way and
fails any package script that uses `\|`. A later install over a build that
recorded nothing for `featurexml.cfg` records and patches it then.

### Camera alerts

- GPM (system uid, has GPS) loads `/data/leafia/cameras.csv` (`LeafiaCamDb`:
  grid index, Uniden direction rules), takes GPS every second (`LeafiaCam`,
  started from `GalReceiverService.onCreate`) and publishes the camera ahead as
  `sys.leafia.cam = kind,whole,tenths,unit` or `0`. The car navigation has no
  location permission and can't set `sys.*` properties, so it only reads it.
- The HUD draws an icon only for the trap frame's non-speed code, and it
  replaces the speed-limit sign: 1 = red-light camera. The speed / mobile /
  red-line fields, the over-speed alarm and the road-event frame draw nothing.
  `LeafiaNavCam` (first in the car navigation's `sendClusterData`) overlays the
  last trap frame with non-speed 1 and alarm 1 (speed camera) or 3 (red-light),
  replaces the distance frame with the camera distance, and polls every
  500 ms, resending when the camera or distance changes and every 5 s (trap
  frames are otherwise sent only when the limit changes). Hooks: `src/hooks/hooks21_cam.py`.
- Non-speed 1 also makes the cluster show "uneven road ahead" with a chime.

## Open items

- **CarPlay**: rerouting and call state not yet tested on the car.
- **Camera icon above the limit sign**: no trap-frame field found that draws
  one there (HUD tests 5 and 6); the icon replaces the sign.
- **Side roads for Android Auto**: the phone doesn't send them; match the car's
  ADASIS map stream to the route.
- The angle sign for CarPlay side roads (`persist.leafia.g70.cpangle`).

## Probe

`tools/probe` collects logs, props and app files to the USB drive (read only).
This toolbox has no `find`, `tr`, `wc` or `tail`; scripts must use toolbox
commands only.

## v1.2: one package for several firmwares, camera alerts moved out

- Firmware sets: `package/firmware/<firmware>/sums.sh` (the stock files that build was made
  from, our builds, earlier builds an install may replace) plus that firmware's `*.lpd`
  deltas. `scripts/common.sh` `pick_firmware` loads each set and keeps the first one whose
  apps and Android Auto library on the unit are stock, ours or an earlier build of ours. The
  set is recorded in the backup folder (`firmware-set`); uninstall falls back to it when no set
  matches any more (after a firmware update), and the restore steps still leave alone any
  file that is not this package's. `check_unit` refuses when no set matches.
- Sets in v1.2: 251120 (our car's original firmware), 250818 (2023 G70) and 260507 (the
  2026.07 update). Earlier builds each set replaces: v1.1, the 250818 port bridge, the first
  260507 builds.
- Camera alerts are no longer in the bridge (GPM without `LeafiaCam*` and its start call; the
  car navigation from the turn-mute-only tree). They come back as a separate add-on.
- 260507 port (`tools/port`): deodex against the port's own framework, 3-way merge of our
  smali onto its stock (`merge.py`), method renames (`renames.py`), stock fields our code
  uses compared by how the stock code uses them (`fieldcheck.py`), then `check_refs` /
  `check_regs` against its framework. Fixes it needed: `DipoService.C(Z)` now sets another
  field (the audio flag is `hH`, set by `E(Z)`); `f/b.bH` -> `bJ`, `e/g.mH` -> `mM`; the car
  navigation's `am.getCurrentContext` is `al.getCurrentContext`. Android Auto library:
  `tools/aa-lib-port/build_lib_port.py` entry `g70-260507` (addresses from `mapaddr.py` /
  `blmap.py`; the dealloc helper is the same function with the allocator inlined).
- Checks: `tools/port/mock_multi.sh` (fresh install on each firmware's files picks the right
  set; an IKPE-named unit with 250818 files installs; an unknown file mix is refused; upgrades
  from v1.1, the 250818 bridge and both 260507 builds; every uninstall byte-identical) and
  `tools/port/mock_compat.sh` (the compatibility check names the right set, or the closest set
  and the files that differ).
