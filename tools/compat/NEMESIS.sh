#!/system/bin/sh
# G70 bridge compatibility check - READ ONLY. Changes nothing on the car.
# Compares this head unit's stock files with the ones the Genesis G70 bridge package is
# built from, and writes the result to G70COMPAT-<n>/report.txt on this USB drive.
# Every file the package changes must match byte for byte; the firmware name alone
# doesn't decide it. The report holds no personal data (firmware id and file checksums).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin

# from the package's installer (scripts/common.sh)
APPS="Iap2ServerApp HKMC_DiPO HKMC_GPM HKMC_Navi_ExSL"
SETS="250818 251120 260507"

set_250818() {
    PRODUCT=IKFL.USA.0000.V014.010.250818
    SUM_STOCK_HKMC_DiPO_apk=ea9b80e1af3c6c5e7df9a7c65af0f10d
    SUM_STOCK_HKMC_DiPO_odex=da0e1ea366c5e4fdae9f48dd8a7d00f9
    SUM_STOCK_Iap2ServerApp_apk=f5d60c0e7a1fd8851bfbbfb012ad90b6
    SUM_STOCK_Iap2ServerApp_odex=7a12115a12132b0ed21afb6d109038e2
    SUM_STOCK_HKMC_GPM_apk=3e5445453094de0589a9c99e45fc8235
    SUM_STOCK_HKMC_GPM_odex=d2e99d7491d4e17adbea03df9eb7b90e
    SUM_STOCK_HKMC_Navi_ExSL_apk=608941d6a7a09c0bc5e411482f58fefd
    SUM_STOCK_HKMC_Navi_ExSL_odex=936627900a298d7d5de4680a1ab0242e
    SUM_STOCK_AALIB=147dac01e89358ee10c6113e53d7e957
    SUM_NEW_HKMC_DiPO=96658b1bac7c173a6489619b08335658
    SUM_NEW_Iap2ServerApp=ae5788ba6256d75cc0c167653c250b83
    SUM_NEW_HKMC_GPM=bf487401a7d2d9cec913507064f696db
    SUM_NEW_HKMC_Navi_ExSL=a820e589c3542bf2ce13894267b7ab51
    SUM_NEW_AALIB=81f24682e7cc78e0884a57195f4e2062
    SUM_PREV_HKMC_DiPO="00fd169d2897c0512a53e612cac424f6"
    SUM_PREV_Iap2ServerApp="0003964129c5c00c1ed9989244bb9174"
    SUM_PREV_HKMC_GPM="cd9e35b2dea9ca2b6e23618341479317"
    SUM_PREV_HKMC_Navi_ExSL="4a3065a9771f811e7b540de1dc01b433"
    SUM_PREV_AALIB=""
}
set_251120() {
    PRODUCT=IKFL.USA.0000.V014.011.251120
    SUM_STOCK_HKMC_DiPO_apk=3d2ef97eb6a6bcd0c095a0369d03ab7a
    SUM_STOCK_HKMC_DiPO_odex=9d8d144d6b21e96f5df53389068f6c1e
    SUM_STOCK_Iap2ServerApp_apk=f5d60c0e7a1fd8851bfbbfb012ad90b6
    SUM_STOCK_Iap2ServerApp_odex=9553c77d84af024ddf557e584e22e2e1
    SUM_STOCK_HKMC_GPM_apk=41acee707881cee45496ea1c609269fd
    SUM_STOCK_HKMC_GPM_odex=bd81a1f7021f6fcfe5493318ebde829d
    SUM_STOCK_HKMC_Navi_ExSL_apk=fa6b8cb90701f2f333a785ebab0133d0
    SUM_STOCK_HKMC_Navi_ExSL_odex=5f83f1fbc68ce37168c5179418abc0fe
    SUM_STOCK_AALIB=9ee6c1d408eaed98c43e03bef5e4866c
    SUM_NEW_HKMC_DiPO=2addfeef2b479ca068d08ccd6724c6bc
    SUM_NEW_Iap2ServerApp=f1fa1d46b44ac1e6acb7200cd37c24c1
    SUM_NEW_HKMC_GPM=28d58f7248d3e680251b422d5cd40f88
    SUM_NEW_HKMC_Navi_ExSL=b1b91588c420d8b1943b16023353917b
    SUM_NEW_AALIB=97df33a3bf78336c9511792d7118d713
    SUM_PREV_HKMC_DiPO="6922669d1c356cee538651c98772df3d"
    SUM_PREV_Iap2ServerApp="406ee0d95345bc90205b259ec2018bf9"
    SUM_PREV_HKMC_GPM="ce84e98b87eed5cc46813b31ac4c7ef4"
    SUM_PREV_HKMC_Navi_ExSL="b9c9e7cd477b87cb8750c2e0445120cc"
    SUM_PREV_AALIB="a20ebe3fe5ab90a545040a82fe9b6c88"
}
set_260507() {
    PRODUCT=IKFL.USA.0000.V015.012.260507
    SUM_STOCK_HKMC_DiPO_apk=e38f835ebf4c7e11cec7a4030649e657
    SUM_STOCK_HKMC_DiPO_odex=9f8f3fe2c7ddacbf7e7eb28e5a4be7dc
    SUM_STOCK_Iap2ServerApp_apk=fde208439f993986a60396e759797a01
    SUM_STOCK_Iap2ServerApp_odex=1b1af561ab9c83de765cd2580ee8bbee
    SUM_STOCK_HKMC_GPM_apk=98ba43132073f3e8d06391cb8f0d8a0f
    SUM_STOCK_HKMC_GPM_odex=9d991b5ef563a20d0b3543df113ef6a8
    SUM_STOCK_HKMC_Navi_ExSL_apk=19559e742b1d21550aa8f0324e8e6d36
    SUM_STOCK_HKMC_Navi_ExSL_odex=ac5464b567d4253d5cad007f74699ce7
    SUM_STOCK_AALIB=48ee793af8b86052503b8c952b034731
    SUM_NEW_HKMC_DiPO=4991c8fab151d1d06d7a837f012d9af2
    SUM_NEW_Iap2ServerApp=daefe2d3f36e8058108b83075cd2552a
    SUM_NEW_HKMC_GPM=9c345f7d1a09670ea975cd23e217b50e
    SUM_NEW_HKMC_Navi_ExSL=b319d480362ed6f88b6676950472939d
    SUM_NEW_AALIB=c08410a8d32a615b1aa805cd8a243d52
    SUM_PREV_HKMC_DiPO="8a42214c40b516407594ed9629dd5b60"
    SUM_PREV_Iap2ServerApp="4c4cf0234a1ddf9f8a9160e1b72cf91a"
    SUM_PREV_HKMC_GPM="23953f21377181a1b08494e68230dd4f"
    SUM_PREV_HKMC_Navi_ExSL="f4ba3670352c89d33e9df22b5afe6764"
    SUM_PREV_AALIB=""
}
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
