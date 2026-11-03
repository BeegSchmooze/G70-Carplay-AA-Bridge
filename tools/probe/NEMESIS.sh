#!/system/bin/sh
# G70 wireless CarPlay probe - READ ONLY. Changes nothing on the car.
# Collects what the Leafia port kit leaves out for the Bluetooth -> iAP2 path:
# which app handles the iAP2 Bluetooth (SPP) connect request, the Bluetooth app
# and iAP2 native pieces, init services, device nodes and the current props.
# Writes G70PROBE-<n>/ on this USB drive (a new folder each run). Never post it publicly (it can hold phone
# names and Bluetooth addresses).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

# one folder per run: G70PROBE-1, G70PROBE-2, ...
_n=1
while [ -e "$(pwd)/G70PROBE-$_n" ]; do _n=$((_n + 1)); done
OUT=$(pwd)/G70PROBE-$_n
mkdir -p "$OUT/app" "$OUT/lib" "$OUT/bin" "$OUT/etc" "$OUT/rc" || exit 1
LOG=$OUT/probe.txt
: > "$LOG" || exit 1
say() { echo "$1" >> "$LOG"; }
section() { say ""; say "===== $1"; }
grab() { if cp "$1" "$2" 2>/dev/null; then say "ok   $1"; else say "FAIL $1"; fi; }

# logs only by default (a few MB). The stock app/library copies, launcher and vehicle survey
# (~70 MB) run only when a file named G70PROBE-FULL is on the drive root.
FULL=0
[ -e "$(pwd)/G70PROBE-FULL" ] && FULL=1

say "g70-probe 2 (full=$FULL)"
say "date $(date)"
say "id $(id)"

section "background logger"
# logcat only holds a minute or two; keep a rolling copy on the unit until the next
# restart so a later run can collect what happened while you tested
BGDIR=/data/nemesis/g70log
mkdir -p "$BGDIR" "$OUT/bglog" 2>/dev/null
_running=0
if [ -f "$BGDIR/pid" ]; then
    read -r _pid < "$BGDIR/pid"
    case "$(cat /proc/$_pid/cmdline 2>/dev/null)" in *logcat*) _running=1 ;; esac
fi
for f in "$BGDIR"/logcat.txt*; do
    [ -f "$f" ] && cp "$f" "$OUT/bglog/" 2>/dev/null
done
if [ $_running = 1 ]; then
    say "logger already running (pid $_pid) - copied its files"
else
    rm -f "$BGDIR"/logcat.txt* 2>/dev/null
    # hostapd logs a status line every second; leave it out to keep more history
    # one append-only file (this logcat ignores -r/-n); a guard moves it aside past 100 MB
    logcat -v time hostapd:S bt-hci:S CoNA:S BluetoothAdapterService:S BluetoothAdapter:S TPEGHDRadioController:S LocalBluetoothManager:S CachedBluetoothDevice:S JNI_Layer:S UserProfileService:S BufferQueue:S Java_Layer:S HereFuelDecoder:S HereImageDecoder:S bt-btif:S audio_a2dp_hw:S ExSL:S BluetoothA2dp:S SystemService:S BTCMListenerManager:S BluetoothUtils:S SXM65HD:S RDO_MICOM_CMD_EVENT:S RadioService:S HDBandScan:S MicomD:S CompassLogRightSideScreen:S SplitScreenViewCompass:S HDAASDataTransfer:S HDDecoder:S HKMC_RadioNA:S TimePolicyManager:S >> "$BGDIR/logcat.txt" 2>/dev/null &
    _lp=$!
    echo $_lp > "$BGDIR/pid"
    (
        while [ -d /proc/$_lp ]; do
            set -- $(ls -l "$BGDIR/logcat.txt" 2>/dev/null)
            if [ -n "$4" ] && [ "$4" -gt 104857600 ] 2>/dev/null; then
                cp "$BGDIR/logcat.txt" "$BGDIR/logcat.txt.1" 2>/dev/null
                : > "$BGDIR/logcat.txt"
            fi
            sleep 60
        done
    ) > /dev/null 2>&1 &
    say "started logger (pid $_lp) - it records until the head unit restarts"
fi

# the built-in navigation's cluster turn messages (display daemon CoNA: turn type, side
# street, direction, turn name, turn list). CoNA is too chatty for the main log, so a
# second logger keeps only these lines.
for f in "$BGDIR"/cona.txt*; do
    [ -f "$f" ] && cp "$f" "$OUT/bglog/" 2>/dev/null
done
_cona=0
if [ -f "$BGDIR/conapid" ]; then
    read -r _cpid < "$BGDIR/conapid"
    [ -d "/proc/$_cpid" ] && _cona=1
fi
if [ $_cona = 0 ]; then
    rm -f "$BGDIR"/cona.txt* 2>/dev/null
    (
        logcat -v time CoNA:V '*:S' 2>/dev/null | grep -E "sendTurnDa|PE02|PE07|TurnName|TBTList|TBT_LIST|LaneInfo|FrameRG_Cluster|SideStreet|ClusterRouteType" >> "$BGDIR/cona.txt"
    ) > /dev/null 2>&1 &
    echo $! > "$BGDIR/conapid"
    say "started cluster turn logger (CoNA)"
else
    say "cluster turn logger already running"
fi

section "props"
getprop > "$OUT/getprop.txt" 2>&1
grep -iE "iap|carplay|wifi|bt|bluetooth|wireless|stepofspec|ium" "$OUT/getprop.txt" >> "$LOG"

section "device nodes"
ls -l /dev/iap2 /dev/tcc-cp /dev/ttyHS* /dev/rfcomm* /dev/socket >> "$LOG" 2>&1

section "processes"
ps > "$OUT/ps.txt" 2>&1
grep -iE "iap|bt|blue|dipo|carplay|mdns|projection|hostapd|dnsmasq" "$OUT/ps.txt" >> "$LOG"

section "services"
service list > "$OUT/services.txt" 2>&1
grep -iE "iap|bt|blue|dipo|carplay" "$OUT/services.txt" >> "$LOG"

if [ $FULL = 1 ]; then
section "receivers for the SPP connect request"
dumpsys package r > "$OUT/receivers.txt" 2>&1
grep -n -A4 -E "START_SPP_CONNECT_FOR_CONNECTIVITY|REQUEST_CONNECT_SPP|iap2.start|telechips.android.iap2" "$OUT/receivers.txt" >> "$LOG"

section "init scripts"
for f in /*.rc; do
    cp "$f" "$OUT/rc/" 2>/dev/null
done
grep -n -B1 -A3 -iE "iap|bluetooth|bt_|btld|rfcomm" /*.rc >> "$LOG" 2>/dev/null

section "file lists"
ls -l /system/app > "$OUT/system-app.txt" 2>&1
ls -l /system/priv-app > "$OUT/system-priv-app.txt" 2>&1
ls -l /system/bin > "$OUT/system-bin.txt" 2>&1
ls -l /system/xbin > "$OUT/system-xbin.txt" 2>&1
ls -l /system/lib > "$OUT/system-lib.txt" 2>&1
ls -lR /system/etc/bluetooth > "$OUT/system-etc-bluetooth.txt" 2>&1
ls -l /system/vendor/lib > "$OUT/vendor-lib.txt" 2>&1

section "apps that mention the SPP connect request or iAP2"
for f in /system/app/*.odex /system/priv-app/*.odex; do
    [ -f "$f" ] || continue
    if grep -q -E "START_SPP_CONNECT_FOR_CONNECTIVITY|com/tcc/iap2|IIap2Service" "$f" 2>/dev/null; then
        say "match $f"
        _b=${f%.odex}
        grab "$f" "$OUT/app/"
        [ -f "$_b.apk" ] && grab "$_b.apk" "$OUT/app/"
    fi
done
for f in /system/app/Bluetooth.apk /system/app/Bluetooth.odex /system/app/BTAudio.apk /system/app/BTAudio.odex; do
    [ -f "$f" ] && grab "$f" "$OUT/app/"
done

section "native iAP2 and Bluetooth pieces"
for f in /system/bin/*; do
    case "${f##*/}" in
        *iap*|*IAP*|*Iap*|*bt*|*bluetooth*|*mdns*|*carplay*|*CarPlay*) grab "$f" "$OUT/bin/" ;;
    esac
done
for f in /system/lib/*.so /system/vendor/lib/*.so; do
    case "${f##*/}" in
        libiap*|libIap*|libtcciap*|libCarPlay*) ;;   # already in the port kit
        *iap*|*Iap*|*bt*|*bluetooth*|*bluedroid*|*bta*|*rfcomm*|*mdns*|*dns_sd*) grab "$f" "$OUT/lib/" ;;
    esac
done
for f in /system/framework/com.broadcom.bt.jar /system/framework/com.broadcom.bt.odex; do
    [ -f "$f" ] && grab "$f" "$OUT/lib/"
done
for f in /system/etc/bluetooth/*; do
    [ -f "$f" ] && grab "$f" "$OUT/etc/"
done
fi

section "wireless Android Auto"
# hotspot settings without the passphrase
for f in /data/misc/wifi/hostapd.conf /system/etc/wifi/hostapd.conf /data/misc/wifi/softap.conf; do
    [ -f "$f" ] || continue
    say "-- $f"
    grep -E "^(interface|driver|channel|hw_mode|ieee80211[a-z]*|country_code|ht_capab|vht_[a-z_]*|wmm_enabled|max_num_sta)=" "$f" >> "$LOG" 2>/dev/null
done
if [ -x /system/bin/wl ] || [ -x /system/xbin/wl ]; then
    for c in band chanspec channel country autocountry_default ap; do
        say "wl $c: $(wl $c 2>&1)"
    done
fi
dumpsys wifi > "$OUT/dumpsys-wifi.txt" 2>&1
grep -iE "apBand|apChannel|channel|frequency|SoftAp" "$OUT/dumpsys-wifi.txt" | grep -viE "ssid|psk|pass" >> "$LOG"
cat /proc/net/arp > "$OUT/arp.txt" 2>&1
# TCP listeners and connections (Android Auto listens on 40515 = 0x9E43)
cat /proc/net/tcp > "$OUT/tcp.txt" 2>&1
cat /proc/net/tcp6 > "$OUT/tcp6.txt" 2>&1
netstat -an > "$OUT/netstat.txt" 2>&1
grep -i ":9E43" "$OUT/tcp.txt" "$OUT/tcp6.txt" >> "$LOG" 2>/dev/null || say "nothing on port 40515"

section "G70 CarPlay bridge"
mkdir -p "$OUT/nemesis" 2>/dev/null
for f in /data/nemesis/*.log; do
    [ -f "$f" ] && cp "$f" "$OUT/nemesis/" 2>/dev/null
done
for p in persist.leafia.g70.cpbridge persist.leafia.g70.cpcomp persist.sys.iap2.wifi persist.iap2.iden.wireless; do
    say "$p=$(getprop $p)"
done
ls -l /system/app/HKMC_DiPO.* /system/app/Iap2ServerApp.* >> "$LOG" 2>&1

section "logs (last minute or so)"
logcat -d -v time > "$OUT/logcat-full.txt" 2>&1
logcat -d -v time -b events > "$OUT/logcat-events.txt" 2>&1
dmesg > "$OUT/dmesg.txt" 2>&1
grep -iE "iap2|spp|rfcomm|carplay|wireless|LeafiaCP|BTCMSppApi|DiPO" "$OUT/logcat-full.txt" > "$OUT/logcat-iap2-bt.txt" 2>/dev/null
grep -E "LeafiaCP|Leafia:" "$OUT/logcat-full.txt" > "$OUT/logcat-bridge.txt" 2>/dev/null
grep -iE "AAProjection|GalReceiver|WirelessExplorer|HfDeviceBTCMSppApi|BTCM|GPM|AndroidAuto|hostapd|SoftAp|dnsmasq|Tether" "$OUT/logcat-full.txt" > "$OUT/logcat-aa.txt" 2>/dev/null

# Read-only vehicle signal survey: every zero-argument get*/is* call on the car's
# vehicle services (list made off-car from the framework's AIDL stubs). Each call
# gets 3 s; a stuck service is killed so the probe always finishes.
if [ $FULL = 1 ]; then
section "vehicle signal survey"
_vs="$(pwd)/vsurvey-calls.txt"
[ -f "$_vs" ] || _vs="$(pwd)/_g70-probe/vsurvey-calls.txt"
if [ -f "$_vs" ]; then
    _n=0
    while read -r _svc _code _name _ret; do
        [ -n "$_code" ] || continue
        service call "$_svc" "$_code" > "$OUT/vs.tmp" 2>&1 &
        _cp=$!
        ( sleep 3; kill -9 $_cp 2>/dev/null ) &
        _wp=$!
        wait $_cp 2>/dev/null
        kill $_wp 2>/dev/null
        _res=""
        while IFS= read -r _l; do _res="$_res $_l"; done < "$OUT/vs.tmp"
        echo "$_svc $_name $_ret ::$_res" >> "$OUT/vsurvey.txt"
        _n=$((_n + 1))
    done < "$_vs"
    rm -f "$OUT/vs.tmp"
    say "survey: $_n calls -> vsurvey.txt"
else
    say "survey: vsurvey-calls.txt not on the drive, skipped"
fi

section "launcher (for adding app-menu tiles: Snorkel LEDs, R8W)"
# the all-apps menu (com.android.launcher3) and the home-screen editor; ~50 MB in all
mkdir -p "$OUT/launcher"
for f in /system/app/Launcher_WP3.apk /system/app/Launcher_WP3.odex \
         /system/app/HKMC_HomeSetting_WP.apk /system/app/HKMC_HomeSetting_WP.odex; do
    [ -f "$f" ] && grab "$f" "$OUT/launcher/"
done
md5 /system/app/Launcher_WP3.* /system/app/HKMC_HomeSetting_WP.* >> "$LOG" 2>&1
# the menu's saved layout (read-only copy): shows how entries are stored
for d in /data/data/com.android.launcher3/databases /data/data/com.android.launcher3/shared_prefs; do
    [ -d "$d" ] && { mkdir -p "$OUT/launcher/${d##*/}"; cp "$d"/* "$OUT/launcher/${d##*/}/" 2>/dev/null; say "copied $d"; }
done
fi

section "Snorkel LEDs (g70.snorkel)"
ls -l /system/app/SnorkelWeb.apk >> "$LOG" 2>&1
ls -l /data/nemesis/backup/g70.snorkel >> "$LOG" 2>&1
pm list packages -f 2>/dev/null | grep -i snorkel >> "$LOG"
ps | grep -i snorkel >> "$LOG"
# the head unit's Wi-Fi (the snorkel controller needs client mode; normally the CarPlay/AA hotspot)
getprop | grep -iE "wlan|wifi|hostapd" >> "$LOG"
netcfg >> "$LOG" 2>&1
dumpsys wifi > "$OUT/dumpsys-wifi.txt" 2>&1

# navigation data probe (read only), when staged on the drive: G70NAVI-<n>/
if [ -f "$(pwd)/_g70-navi-probe/NEMESIS.sh" ]; then
    say "running _g70-navi-probe"
    ( /system/bin/sh "$(pwd)/_g70-navi-probe/NEMESIS.sh" ) >> "$LOG" 2>&1
fi
if [ -f "$(pwd)/_g70-engine-probe/NEMESIS.sh" ]; then
    say "running _g70-engine-probe"
    ( /system/bin/sh "$(pwd)/_g70-engine-probe/NEMESIS.sh" ) >> "$LOG" 2>&1
fi
section "compress"
# the big logs go out gzipped; the filtered logs above stay plain text. If gzip leaves the
# original behind, the plain file is kept and the .gz dropped.
rmdir "$OUT/app" "$OUT/lib" "$OUT/bin" "$OUT/etc" "$OUT/rc" 2>/dev/null
for f in "$OUT"/bglog/logcat.txt* "$OUT/logcat-full.txt" "$OUT/logcat-events.txt" "$OUT/dmesg.txt" "$OUT/receivers.txt"; do
    case "$f" in *.gz) continue ;; esac
    [ -f "$f" ] || continue
    gzip "$f" 2>/dev/null
    if [ -f "$f" ]; then
        rm -f "$f.gz" 2>/dev/null
        say "kept plain ${f##*/}"
    else
        say "gzip ${f##*/}"
    fi
done
say ""
say "end"
sync
exit 0
