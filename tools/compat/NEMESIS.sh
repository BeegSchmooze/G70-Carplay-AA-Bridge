#!/system/bin/sh
# G70 bridge compatibility check - READ ONLY. Changes nothing on the car.
# Compares this head unit's stock files with the ones the Genesis G70 bridge package is
# built from, and writes the result to G70COMPAT-<n>/report.txt on this USB drive.
# Every file the package changes must match byte for byte; the firmware name alone
# doesn't decide it. The report holds no personal data (firmware id and file checksums).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin

# from the package's installer (scripts/common.sh)
PRODUCT=IKFL.USA.0000.V014.011.251120
APPS="Iap2ServerApp HKMC_DiPO HKMC_GPM HKMC_Navi_ExSL"
SUM_STOCK_HKMC_DiPO_apk=3d2ef97eb6a6bcd0c095a0369d03ab7a
SUM_STOCK_HKMC_DiPO_odex=9d8d144d6b21e96f5df53389068f6c1e
SUM_STOCK_Iap2ServerApp_apk=f5d60c0e7a1fd8851bfbbfb012ad90b6
SUM_STOCK_Iap2ServerApp_odex=9553c77d84af024ddf557e584e22e2e1
SUM_STOCK_HKMC_GPM_apk=41acee707881cee45496ea1c609269fd
SUM_STOCK_HKMC_GPM_odex=bd81a1f7021f6fcfe5493318ebde829d
SUM_STOCK_HKMC_Navi_ExSL_apk=fa6b8cb90701f2f333a785ebab0133d0
SUM_STOCK_HKMC_Navi_ExSL_odex=5f83f1fbc68ce37168c5179418abc0fe
SUM_NEW_HKMC_DiPO=eb4483a40baafc1d81703e7bb837852b
SUM_NEW_Iap2ServerApp=406ee0d95345bc90205b259ec2018bf9
SUM_NEW_HKMC_GPM=645a2bf8d682971cb2159fc240462bb9
SUM_NEW_HKMC_Navi_ExSL=5c62b556f1fd7f1a837813a40ca2a191
SUM_PREV_HKMC_DiPO="c250f2e3f3d06e2a815a85935e305106 8bd271656e8af7ef61da6d4f33e9d0d1 6b2bdc7eed24629752e61b9a1e0b239c 26f714beedf8224b430a1c1bc2e49c63 947849488fad11450204196aff904b33 57c00b020cb09bfa312250640e4cc9ca 02b779f25634ad18e250de7e716ec3fa dcd52da6ceb2ea135433dec7caa2b88f f45342e682af7c257897f0909378d281 8012b94b4b8a85c6a4939bd0180961bb 96303fd6f75c511e2674cb987c3567c2 ed35c863e4eb0ec8e53934951602fe4c"
SUM_PREV_Iap2ServerApp="57bdeabb2f9cc9708d6bbcf985d2b136"
SUM_PREV_HKMC_GPM="e01c64fc4e3a36bd341e0fa15faa77fa e131dc97d7f2c0a196ff76f786e9e91e 97531c1fd478ac7f2ff63171c817ae62 ddd5f2da66f1b822c811870f41710091 34176b279b79c992593bd9f5b351d33d d9e7194d1cd528537cd5552be26acd1a 386961ac50478484c57bd0e7507ee4d6 eabbf89a47325a08e705d4f6a8ae298a b31e1be345f7fbf8e51dc8ae665305bb 32821c1e0e9839549407c3cc1131dbac 175aab80f023a5b8bd57ece3ea7ba112 83b3862497b0bc5ed15e67394c28d1b2"
SUM_PREV_HKMC_Navi_ExSL="a3a3e3aa99e46929becf15065448271f f0ab55cb5869d5210cb7a1b005e06458"
SUM_STOCK_AALIB=9ee6c1d408eaed98c43e03bef5e4866c
SUM_NEW_AALIB=a20ebe3fe5ab90a545040a82fe9b6c88
SUM_PREV_AALIB="97df33a3bf78336c9511792d7118d713"
SUM_G70_CPCORE=d3a47296437df56fb1ffc7ac3dfca4cb
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
