#!/usr/bin/env python3
"""Make the G70 bridge compatibility check (a read-only NEMESIS execute script) from the
installer's own checksum lists (package/firmware/<name>/sums.sh, one per supported firmware),
so the two always agree.

usage: mk_compat.py <package dir> <out dir>
Writes <out>/NEMESIS.sh and <out>/NEMESIS.data.
"""
import os, re, sys

pkg, out = sys.argv[1:3]
common = open(os.path.join(pkg, 'scripts', 'common.sh')).read()
apps = re.search(r'^APPS=(.*)$', common, re.M).group(1)
fwdir = os.path.join(pkg, 'firmware')
sets = sorted(d for d in os.listdir(fwdir) if os.path.isfile(os.path.join(fwdir, d, 'sums.sh')))
keep = 'APPS=%s\nSETS="%s"\n' % (apps, ' '.join(sets))
for d in sets:
    body = [l for l in open(os.path.join(fwdir, d, 'sums.sh')).read().splitlines() if l and not l.startswith('#')]
    keep += '\nset_%s() {\n%s\n}' % (d, '\n'.join('    ' + l for l in body))

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

say "Genesis G70 bridge - compatibility check"
say "date $(date)"
_p=$(getprop ro.build.product 2>/dev/null)
say "firmware $_p (the name alone doesn't decide it: the files below do)"
say "firmware sets in this package: $SETS"
say ""

# check_set <name>: one line per file for that set into $T; BAD = the files that differ
check_set() {
    "set_$1"
    BAD=""; T=""
    for _a in $APPS; do
        _apk=$(file_md5 /system/app/$_a.apk)
        _odex=$(file_md5 /system/app/$_a.odex)
        _sa=$(eval echo "\$SUM_STOCK_${_a}_apk")
        _so=$(eval echo "\$SUM_STOCK_${_a}_odex")
        _new=$(eval echo "\$SUM_NEW_${_a}")
        _prev=$(eval echo "\$SUM_PREV_${_a}")
        if [ "$_apk" = "$_sa" ] && [ "$_odex" = "$_so" ]; then
            T="$T|MATCH    $_a (stock, same as the build's)"
        elif [ "$_apk" = "$_new" ] || in_list "$_apk" "$_prev"; then
            T="$T|MATCH    $_a (a build of this package is installed)"
        else
            T="$T|DIFFERENT $_a  apk $_apk  odex $_odex"
            BAD="$BAD $_a"
        fi
    done
    _lib=$(file_md5 /system/lib/libautoreceiver_infobank.so)
    if [ "$_lib" = "$SUM_STOCK_AALIB" ]; then
        T="$T|MATCH    libautoreceiver_infobank.so (stock)"
    elif [ "$_lib" = "$SUM_NEW_AALIB" ] || in_list "$_lib" "$SUM_PREV_AALIB"; then
        T="$T|MATCH    libautoreceiver_infobank.so (a build of this package is installed)"
    else
        T="$T|DIFFERENT libautoreceiver_infobank.so  $_lib"
        BAD="$BAD libautoreceiver_infobank.so"
    fi
}
# say_lines: the lines check_set collected ('|' separated)
say_lines() {
    local _ifs=$IFS _l
    IFS='|'
    for _l in ${T#|}; do [ -n "$_l" ] && say "$_l"; done
    IFS=$_ifs
}

FOUND=""; BEST=""; BESTN=99
for _s in $SETS; do
    check_set "$_s"
    _c=0; for _b in $BAD; do _c=$((_c + 1)); done
    if [ -z "$BAD" ]; then FOUND=$_s; break; fi
    if [ "$_c" -lt "$BESTN" ]; then BEST=$_s; BESTN=$_c; fi
done
if [ -n "$FOUND" ]; then
    say "firmware set $FOUND (built on $PRODUCT) matches:"
else
    check_set "$BEST"
    say "no firmware set matches; the closest is $BEST (built on $PRODUCT):"
fi
say_lines

_core=$(file_md5 /system/lib/libCarPlayCore.so)
if [ "$_core" = "$SUM_G70_CPCORE" ]; then
    say "MATCH    libCarPlayCore.so (stock)"
else
    say "CHECKED AT INSTALL libCarPlayCore.so  $_core (patched by pattern; the installer checks it fits)"
fi

if [ -f "$CP_XML" ]; then
    say "INFO     wireless CarPlay / Android Auto features already on (left as they are)"
else
    say "INFO     wireless CarPlay / Android Auto features off (the package turns them on)"
fi
if [ -d /data/nemesis/backup/wireless.projection ]; then
    say "INFO     HMG Leafia Plus wireless.carplay.aa is installed: not needed by the bridge"
    say "         (it can stay; uninstalling it first avoids two packages owning the same settings)"
fi

say ""
if [ -n "$FOUND" ]; then
    say "RESULT: COMPATIBLE - the bridge package should install on this car (firmware set $FOUND)."
else
    say "RESULT: NOT COMPATIBLE YET - these differ:$BAD"
    for _b in $BAD; do
        case $_b in
            HKMC_DiPO|Iap2ServerApp) say "  $_b: wireless CarPlay" ;;
            HKMC_GPM|libautoreceiver_infobank.so) say "  $_b: wireless Android Auto fixes and Android Auto turn-by-turn" ;;
            HKMC_Navi_ExSL) say "  $_b: muting the car navigation's turn frames while the phone guides" ;;
        esac
    done
    say "A port for this firmware is possible: send the project this report and a run of the"
    say "read-only probe (privately - the probe holds phone names and Bluetooth addresses)."
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
