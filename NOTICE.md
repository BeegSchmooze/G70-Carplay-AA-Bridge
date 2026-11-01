# Notices

## NEMESIS (AGPL-3.0)

This package installs and runs through **NEMESIS** by xwtk:
https://github.com/xwtk/hmg_nemesis, licensed under the GNU Affero General
Public License v3.0.

The Android Auto navigation bridge in `package/files/libautoreceiver_infobank.tbt.lpd`
is the NEMESIS community package **Turn-by-Turn Guidance for Phone Projection**
(`projection.tbt`) library patch, ported to the Genesis G70 library build (table
re-pointed, hooks moved, four stock byte runs recovered, plus a logging stub).
It remains under the AGPL-3.0.

## HMG Leafia Plus (GPL-3.0)

From HMG Leafia Plus (https://github.com/VysseCodes/HMG-Leafia-Plus), GPL-3.0:

- `lpatch` (`package/tools/lpatch`) and the `lpatch.sh` helpers
- the recipes in `package/recipes/`
- the wireless CarPlay audio part (`package/comp/4_audio`, including `libev6aac.so`)
- the CarPlay Bluetooth bridge design, the `mkdelta` delta format and many of
  the techniques used here (gate patches, cluster muting, trap-frame handling)

## This project (GPL-3.0)

The G70 port: the DiPO, Iap2ServerApp, GPM and car-navigation patches in
`src/patches/` (new classes and edits), the installer scripts, the library port
tools, the checkers, the mock tests and the probe.

## Runtime

Everything Hyundai/Genesis, Google or Apple stays on the head unit: the package
ships only deltas, and the apps and libraries are rebuilt from the car's own
stock files during install.
