#!/usr/bin/env python3
"""Make the G70 bridge compatibility check (a read-only NEMESIS execute script) from the
installer's own checksum list, so the two always agree.

usage: mk_compat.py <package dir> <out dir>
Writes <out>/NEMESIS.sh and <out>/NEMESIS.data.
"""
import os, re, sys

pkg, out = sys.argv[1:3]
common = open(os.path.join(pkg, 'scripts', 'common.sh')).read()
sums = re.findall(r'^(SUM_[A-Za-z0-9_]+|PRODUCT|APPS)=(.*)$', common, re.M)
keep = '\n'.join('%s=%s' % (k, v) for k, v in sums)

script = r'''#!/system/bin/sh
# G70 bridge compatibility check - READ ONLY. Changes nothing on the car.
# Compares this head unit's stock files with the ones the Genesis G70 bridge package is
# built from, and writes the result to G70COMPAT-<n>/report.txt on this USB drive.
# Every file the package changes must match byte for byte; the firmware name alone
# doesn't decide it. The report holds no personal data (firmware id and file checksums).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin

# from the package's installer (scripts/common.sh)
@SUMS@
SUM_G70_CPCORE=@CPCORE@
CP_XML=/system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml

_n=1
while [ -e "$(pwd)/G70COMPAT-$_n" ]; do _n=$((_n + 1)); done
OUT=$(pwd)/G70COMPAT-$_n
mkdir -p "$OUT" || exit 1
R=$OUT/report.txt
: > "$R" || exit 1
say() { echo "$1" >> "$R"; }

file_md5() {
    local _line
    _line=$(md5 "$1" 2>/dev/null) || return 1
    set -- $_line
    [ -n "$1" ] || return 1
    echo "$1"
}
in_list() {
    local _s
    for _s in $2; do [ "$1" = "$_s" ] && return 0; done
    return 1
}

BAD=""
say "Genesis G70 bridge - compatibility check"
say "date $(date)"
_p=$(getprop ro.build.product 2>/dev/null)
if [ "$_p" = "$PRODUCT" ]; then
    say "firmware $_p (the build's own)"
else
    say "firmware $_p (the build was made on $PRODUCT; it installs if every file below matches)"
fi
say ""

for _a in $APPS; do
    _apk=$(file_md5 /system/app/$_a.apk)
    _odex=$(file_md5 /system/app/$_a.odex)
    _sa=$(eval echo "\$SUM_STOCK_${_a}_apk")
    _so=$(eval echo "\$SUM_STOCK_${_a}_odex")
    _new=$(eval echo "\$SUM_NEW_${_a}")
    _prev=$(eval echo "\$SUM_PREV_${_a}")
    if [ "$_apk" = "$_sa" ] && [ "$_odex" = "$_so" ]; then
        say "MATCH    $_a (stock, same as the build's)"
    elif [ "$_apk" = "$_new" ] || in_list "$_apk" "$_prev"; then
        say "MATCH    $_a (a build of this package is installed)"
    else
        say "DIFFERENT $_a  apk $_apk  odex $_odex"
        BAD="$BAD $_a"
    fi
done

_lib=$(file_md5 /system/lib/libautoreceiver_infobank.so)
if [ "$_lib" = "$SUM_STOCK_AALIB" ]; then
    say "MATCH    libautoreceiver_infobank.so (stock)"
elif [ "$_lib" = "$SUM_NEW_AALIB" ] || in_list "$_lib" "$SUM_PREV_AALIB"; then
    say "MATCH    libautoreceiver_infobank.so (a build of this package is installed)"
else
    say "DIFFERENT libautoreceiver_infobank.so  $_lib"
    BAD="$BAD libautoreceiver_infobank.so"
fi

_core=$(file_md5 /system/lib/libCarPlayCore.so)
if [ "$_core" = "$SUM_G70_CPCORE" ]; then
    say "MATCH    libCarPlayCore.so (stock)"
else
    say "CHECKED AT INSTALL libCarPlayCore.so  $_core (patched by pattern; the installer checks it fits)"
fi

if [ -f "$CP_XML" ]; then
    say "OK       HMG Leafia Plus wireless.carplay.aa is installed"
else
    say "MISSING  HMG Leafia Plus wireless.carplay.aa: install it first (basic mode is enough)"
    BAD="$BAD leafia"
fi

say ""
if [ -z "$BAD" ]; then
    say "RESULT: COMPATIBLE - the bridge package should install on this car."
else
    say "RESULT: NOT COMPATIBLE YET - these differ:$BAD"
    for _b in $BAD; do
        case $_b in
            HKMC_DiPO|Iap2ServerApp) say "  $_b: wireless CarPlay" ;;
            HKMC_GPM|libautoreceiver_infobank.so) say "  $_b: wireless Android Auto fixes and Android Auto turn-by-turn" ;;
            HKMC_Navi_ExSL) say "  $_b: muting the car navigation's turn frames while the phone guides" ;;
            leafia) say "  install HMG Leafia Plus first, then run this check again" ;;
        esac
    done
    case "$BAD" in
        " leafia") ;;
        *)  say "A port for this firmware is possible: send the project this report and a run of the"
            say "read-only probe (privately - the probe holds phone names and Bluetooth addresses)." ;;
    esac
fi
sync
exit 0
'''

cpcore = re.search(r'^SUM_G70_CPCORE=(\w+)$', open(os.path.join(os.path.dirname(__file__), 'compat-cpcore.txt')).read(), re.M).group(1)
script = script.replace('@SUMS@', keep).replace('@CPCORE@', cpcore)
os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'NEMESIS.sh'), 'w', newline='\n').write(script)
open(os.path.join(out, 'NEMESIS.data'), 'w', newline='\n').write('[nemesis]\nversion=1.0\ntype=execute\npath=NEMESIS.sh\n')
print('wrote', out)
