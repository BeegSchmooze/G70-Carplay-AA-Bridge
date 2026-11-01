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

## Open items

- **CarPlay turn-by-turn**: when CarPlay moves to Wi-Fi the iPhone sends
  `disableBluetooth`; DiPO tells BTCM (`btcmSetupDipoConnectStatus`) and the
  iAP2 SPP link drops 1.4 s later, so `StartRouteGuidanceUpdate` fails ("called
  before the iap2 is ready"). There is no iAP2-over-Wi-Fi transport in this
  firmware; the SPP link has to survive the profile disconnect.
- **HUD street name** (Android Auto): `updateTPCrossroadName` reaches the cluster
  but the HUD's street line appears to come from the turn list
  (`updateTPTurnList` / `updateTPTurnListNew`), which the built-in navigation
  sends and stock GPM never did.
- **First step / smoother distance**: use the upcoming-step list to skip
  "depart/straight" steps, and count the distance down from vehicle speed
  between phone updates.
- Lane guidance and the destination readout.

## Probe

`tools/probe` collects logs, props and app files to the USB drive (read only).
This toolbox has no `find`, `tr`, `wc` or `tail`; scripts must use toolbox
commands only.
