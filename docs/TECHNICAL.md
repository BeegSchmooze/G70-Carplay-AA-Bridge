# Technical notes — Genesis G70 (IKFL.USA.0000.V014.011.251120)

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

## Open items

- **CarPlay turn-by-turn**: confirm the handover session comes up on the car
  now that messages carry their length.
- **Side roads for Android Auto**: the phone doesn't send them; match the car's
  ADASIS map stream to the route.
- The angle sign for CarPlay side roads (`persist.leafia.g70.cpangle`).

## Probe

`tools/probe` collects logs, props and app files to the USB drive (read only).
This toolbox has no `find`, `tr`, `wc` or `tail`; scripts must use toolbox
commands only.
