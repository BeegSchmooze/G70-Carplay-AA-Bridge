#!/system/bin/sh
# g70.carplay.bt - wireless CarPlay for the Genesis G70 (IKFL.USA 251120),
# built on HMG Leafia Plus parts. Needs Leafia's wireless.carplay.aa (basic mode)
# installed first for the wireless feature flags and the hotspot.
#
#   HKMC_DiPO      + LeafiaCpBridge: carries iAP2 between the iPhone's Bluetooth
#                    link (BTCM SPP) and the iAP2 server; null check in
#                    service/q onSessionDetails (Leafia's reconnect crash fix)
#   HKMC_GPM       Android Auto turn-by-turn: HMG-API AaTurns port (HUD street and
#                    distance, next turns, lanes, remaining trip); a failed wireless attempt no longer leaves
#                    GalConnectionManager stuck in start mode 2 without a session;
#                    a USB drive or hub no longer starts a wired attempt
#   Iap2ServerApp  Iap2ServiceReceiver.onReceive (empty in the US build) starts and
#                    ends the iAP2 session on the Bluetooth transport
#   props          persist.sys.iap2.wifi=t (iPhone gets the hotspot SSID/password),
#                  persist.iap2.iden.wireless=t
#   libCarPlayCore Wi-Fi sessions (Leafia recipe carplay-core-wifi)
#   HKMC_Navi_ExSL car navigation skips its turn frames while the phone guides
#                    (sys.leafia.phonetbt, stamped by DiPO / GPM); traps still pass
#   libautoreceiver_infobank  Android Auto turn-by-turn on the cluster: Leafia's
#                    projection.tbt library patch ported to this stock library
#                    (files/libautoreceiver_infobank.tbt.lpd, hash-gated delta)
#   comp/4_audio   Leafia's wireless CarPlay audio part, unchanged
#
# Nothing modified is shipped: the four apps are rebuilt on the head unit from its
# own stock files (files/<app>.lpd deltas, applied by lpatch only to the exact
# stock .odex, then added to the stock APK), and each result must match the
# tested build's checksum.
# Every change is checked against the stock checksums first, backed up, and put
# back byte for byte on uninstall (NEMESIS Manager > Packages > Uninstall).
export PATH=/data/nemesis/bin:/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

PKG=g70.carplay.bt
BACKUP_DIR=/data/nemesis/backup/g70.carplay.bt
LOG=/data/nemesis/g70.carplay.bt.log
APP_DIR=/system/app
BUILD_DIR=/data/nemesis/build/g70.carplay.bt
CP_XML=/system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml
PRODUCT=IKFL.USA.0000.V014.011.251120
APPS="Iap2ServerApp HKMC_DiPO HKMC_GPM HKMC_Navi_ExSL"

# stock files the builds were made from
SUM_STOCK_HKMC_DiPO_apk=3d2ef97eb6a6bcd0c095a0369d03ab7a
SUM_STOCK_HKMC_DiPO_odex=9d8d144d6b21e96f5df53389068f6c1e
SUM_STOCK_Iap2ServerApp_apk=f5d60c0e7a1fd8851bfbbfb012ad90b6
SUM_STOCK_Iap2ServerApp_odex=9553c77d84af024ddf557e584e22e2e1
SUM_STOCK_HKMC_GPM_apk=41acee707881cee45496ea1c609269fd
SUM_STOCK_HKMC_GPM_odex=bd81a1f7021f6fcfe5493318ebde829d
SUM_STOCK_HKMC_Navi_ExSL_apk=fa6b8cb90701f2f333a785ebab0133d0
SUM_STOCK_HKMC_Navi_ExSL_odex=5f83f1fbc68ce37168c5179418abc0fe
# our builds (stock APK + patched classes.dex)
SUM_NEW_HKMC_DiPO=eb4483a40baafc1d81703e7bb837852b
SUM_NEW_Iap2ServerApp=406ee0d95345bc90205b259ec2018bf9
SUM_NEW_HKMC_GPM=645a2bf8d682971cb2159fc240462bb9
SUM_NEW_HKMC_Navi_ExSL=5c62b556f1fd7f1a837813a40ca2a191
# earlier builds of this package an install may replace (the stock backup is kept)
SUM_PREV_HKMC_DiPO="c250f2e3f3d06e2a815a85935e305106 8bd271656e8af7ef61da6d4f33e9d0d1 6b2bdc7eed24629752e61b9a1e0b239c 26f714beedf8224b430a1c1bc2e49c63 947849488fad11450204196aff904b33 57c00b020cb09bfa312250640e4cc9ca 02b779f25634ad18e250de7e716ec3fa dcd52da6ceb2ea135433dec7caa2b88f f45342e682af7c257897f0909378d281 8012b94b4b8a85c6a4939bd0180961bb 96303fd6f75c511e2674cb987c3567c2 ed35c863e4eb0ec8e53934951602fe4c"
SUM_PREV_Iap2ServerApp="57bdeabb2f9cc9708d6bbcf985d2b136"
SUM_PREV_HKMC_GPM="e01c64fc4e3a36bd341e0fa15faa77fa e131dc97d7f2c0a196ff76f786e9e91e 97531c1fd478ac7f2ff63171c817ae62 ddd5f2da66f1b822c811870f41710091 34176b279b79c992593bd9f5b351d33d d9e7194d1cd528537cd5552be26acd1a 386961ac50478484c57bd0e7507ee4d6 eabbf89a47325a08e705d4f6a8ae298a b31e1be345f7fbf8e51dc8ae665305bb 32821c1e0e9839549407c3cc1131dbac 175aab80f023a5b8bd57ece3ea7ba112 83b3862497b0bc5ed15e67394c28d1b2"
SUM_PREV_HKMC_Navi_ExSL="a3a3e3aa99e46929becf15065448271f f0ab55cb5869d5210cb7a1b005e06458"

# Android Auto library (turn-by-turn)
AA_LIB=/system/lib/libautoreceiver_infobank.so
AA_LPD=files/libautoreceiver_infobank.tbt.lpd
SUM_STOCK_AALIB=9ee6c1d408eaed98c43e03bef5e4866c
SUM_NEW_AALIB=a20ebe3fe5ab90a545040a82fe9b6c88
# earlier builds of the library this package may replace (rebuilt from the stock backup)
SUM_PREV_AALIB="97df33a3bf78336c9511792d7118d713"

PROPS="persist.sys.iap2.wifi persist.iap2.iden.wireless"
PROP_FILE=$BACKUP_DIR/props
PROP_ON=t
PROP_OFF=f

HOLD_PKGS="com.daudio.app.dipo com.tcc.iap2server com.google.android.projection.sink com.mnsoft.navi"
HOLD_FILE=/data/nemesis/g70.carplay.bt.stopped

LP_ROOT=.
. ./scripts/lpatch.sh
CORE_RECIPE=carplay-core-wifi

log() { echo "$1"; mkdir -p /data/nemesis 2>/dev/null; echo "$1" >> "$LOG" 2>/dev/null; true; }

toast() {
    am broadcast -a com.hkmc.intent.action.TOAST \
        -e com.hkmc.intent.extra.TOAST_MESSAGE "$1" \
        --ez com.hkmc.intent.extra.TOAST_POPUPSHOWING true >/dev/null 2>&1 || true
}

# toolbox `mount -o remount` is refused on these units even as root; only NEMESIS can remount
sys_rw() { /system/xbin/nemesis remount rw >/dev/null 2>&1; }
sys_ro() { /system/xbin/nemesis remount ro >/dev/null 2>&1 || true; }

file_md5() {
    local _line _sum
    _line=$(md5 "$1" 2>/dev/null) || return 1
    set -- $_line
    _sum=$1
    [ -n "$_sum" ] || return 1
    echo "$_sum"
}

sum_eq() {
    local _got
    [ -s "$1" ] || return 1
    _got=$(file_md5 "$1") || return 1
    [ "$_got" = "$2" ]
}

stock_sum() { eval echo "\$SUM_STOCK_${1}_${2}"; }
new_sum() { eval echo "\$SUM_NEW_${1}"; }

chown_system() { chown 0.0 "$1" 2>/dev/null || chown 0:0 "$1" 2>/dev/null || true; }

# copy beside the target, then rename over it (new inode; a running app keeps the old mapping)
put_file() {
    local _src="$1" _dst="$2" _tmp="${2}.g70tmp"
    rm -f "$_tmp" 2>/dev/null || true
    cp -f "$_src" "$_tmp" || { rm -f "$_tmp" 2>/dev/null; return 1; }
    cmp "$_src" "$_tmp" >/dev/null 2>&1 || { rm -f "$_tmp" 2>/dev/null; return 1; }
    chmod 644 "$_tmp" 2>/dev/null || true
    chown_system "$_tmp"
    mv "$_tmp" "$_dst" || { rm -f "$_tmp" 2>/dev/null; return 1; }
    chmod 644 "$_dst" 2>/dev/null || true
    chown_system "$_dst"
    [ -x /system/bin/restorecon ] && restorecon "$_dst" 2>/dev/null
    cmp "$_src" "$_dst" >/dev/null 2>&1
}

# ---- checks ----

is_stock_app() {
    sum_eq "$APP_DIR/$1.apk" "$(stock_sum $1 apk)" && sum_eq "$APP_DIR/$1.odex" "$(stock_sum $1 odex)"
}
is_our_app() { sum_eq "$APP_DIR/$1.apk" "$(new_sum $1)"; }
# an earlier build of this package (needs its stock backup to be present)
is_prev_app() {
    local _s _live
    _live=$(file_md5 "$APP_DIR/$1.apk") || return 1
    for _s in $(eval echo "\$SUM_PREV_${1}"); do
        [ "$_live" = "$_s" ] && return 0
    done
    return 1
}

check_unit() {
    local _p _n
    _p=$(getprop ro.build.product 2>/dev/null)
    if [ "$_p" != "$PRODUCT" ]; then
        log "FAIL: this build is for $PRODUCT, this unit is '$_p'"
        return 1
    fi
    if [ ! -f "$CP_XML" ]; then
        log "FAIL: wireless CarPlay feature file missing - install HMG Leafia Plus (wireless.carplay.aa) first"
        return 1
    fi
    for _n in $APPS; do
        [ -s "files/$_n.lpd" ] || { log "FAIL: payload files/$_n.lpd missing"; return 1; }
        if is_stock_app "$_n"; then
            log "$_n: stock - ok"
        elif is_our_app "$_n"; then
            log "$_n: this package's build is already live"
        elif is_prev_app "$_n" && sum_eq "$BACKUP_DIR/$_n.apk" "$(stock_sum $_n apk)" && sum_eq "$BACKUP_DIR/$_n.odex" "$(stock_sum $_n odex)"; then
            log "$_n: earlier build of this package - will be replaced (stock backup present)"
        else
            log "live $_n.apk md5=$(file_md5 $APP_DIR/$_n.apk) odex md5=$(file_md5 $APP_DIR/$_n.odex)"
            log "FAIL: $_n is neither the stock app this build was made from nor this build"
            return 1
        fi
    done
    case "$(core_state)" in
        PATCHABLE) log "libCarPlayCore.so: Wi-Fi patch fits - ok" ;;
        APPLIED) log "libCarPlayCore.so already patched" ;;
        NATIVE) log "libCarPlayCore.so accepts Wi-Fi natively" ;;
        *) log "FAIL: libCarPlayCore.so status $(core_state)"; return 1 ;;
    esac
    if sum_eq "$AA_LIB" "$SUM_STOCK_AALIB"; then
        log "libautoreceiver_infobank.so: stock - ok"
    elif sum_eq "$AA_LIB" "$SUM_NEW_AALIB"; then
        log "libautoreceiver_infobank.so: this package's build is already live"
    elif is_prev_aalib && sum_eq "$BACKUP_DIR/libautoreceiver_infobank.so" "$SUM_STOCK_AALIB"; then
        log "libautoreceiver_infobank.so: earlier build of this package - will be replaced (stock backup present)"
    else
        log "live libautoreceiver_infobank.so md5=$(file_md5 $AA_LIB)"
        log "FAIL: libautoreceiver_infobank.so is neither stock nor this build"
        return 1
    fi
    return 0
}

# ---- apps ----

android_up() { [ "$(getprop sys.boot_completed 2>/dev/null)" = 1 ]; }

# stop the two apps while their files change, so neither restarts against half-written files
apps_hold() {
    local _p
    android_up || return 0
    touch "$HOLD_FILE" 2>/dev/null || { log "WARN: cannot record stopped apps; not stopping them"; return 0; }
    for _p in $HOLD_PKGS; do
        case " $(echo $(cat "$HOLD_FILE" 2>/dev/null)) " in *" $_p "*) ;; *) echo "$_p" >> "$HOLD_FILE" ;; esac
        if pm disable "$_p" >/dev/null 2>&1; then log "stopped $_p for the file swap"; else log "WARN: could not stop $_p"; fi
    done
    return 0
}

apps_release() {
    local _p _left=""
    [ -f "$HOLD_FILE" ] || return 0
    if ! android_up; then
        log "WARN: stopped apps start again on the next run with Android up"
        return 0
    fi
    for _p in $(cat "$HOLD_FILE"); do
        if pm enable "$_p" >/dev/null 2>&1; then log "started $_p again"; else _left="$_left $_p"; log "WARN: could not start $_p again"; fi
    done
    if [ -z "$_left" ]; then rm -f "$HOLD_FILE"; else echo "$_left" > "$HOLD_FILE"; fi
    return 0
}

wipe_dalvik() {
    local _n
    for _n in $APPS; do
        rm -f /data/dalvik-cache/*${_n}* /data/dalvik-cache/arm/*${_n}* /cache/dalvik-cache/*${_n}* 2>/dev/null
    done
    true
}

write_odex() {
    if [ -z "$BOOTCLASSPATH" ]; then
        export BOOTCLASSPATH=/system/framework/core.jar:/system/framework/conscrypt.jar:/system/framework/okhttp.jar:/system/framework/core-junit.jar:/system/framework/bouncycastle.jar:/system/framework/ext.jar:/system/framework/framework.jar:/system/framework/framework2.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/mms-common.jar:/system/framework/android.policy.jar:/system/framework/services.jar:/system/framework/apache-xml.jar:/system/framework/webviewchromium.jar:/system/framework/automotive.jar
    fi
    [ -x /system/bin/dexopt ] || return 1
    /system/bin/dexopt --preopt "$1" "$2" "m=y,u=n" || return 1
    [ -s "$2" ] || return 1
    chmod 644 "$2" 2>/dev/null || true
    chown_system "$2"
    [ -x /system/bin/restorecon ] && restorecon "$2" 2>/dev/null
    return 0
}

# the package manager looks for an APK that carries classes.dex in the Dalvik cache;
# put the odex there so the first boot does not re-optimise it
prefill_dalvik() {
    local _odex="$1" _cache="/data/dalvik-cache/system@app@${2##*/}@classes.dex"
    [ -s "$_odex" ] && [ -d /data/dalvik-cache ] || return 0
    rm -f "${_cache}.tmp" 2>/dev/null
    if ! cp -f "$_odex" "${_cache}.tmp" 2>/dev/null || ! cmp "$_odex" "${_cache}.tmp" >/dev/null 2>&1; then
        rm -f "${_cache}.tmp" 2>/dev/null
        return 0
    fi
    chmod 644 "${_cache}.tmp" 2>/dev/null || true
    chown 1000:1000 "${_cache}.tmp" 2>/dev/null || chown 1000.1000 "${_cache}.tmp" 2>/dev/null || true
    mv "${_cache}.tmp" "$_cache" 2>/dev/null || rm -f "${_cache}.tmp" 2>/dev/null
    return 0
}

snapshot_apps() {
    local _n _e
    mkdir -p "$BACKUP_DIR" || return 1
    for _n in $APPS; do
        for _e in apk odex; do
            if [ -s "$BACKUP_DIR/$_n.$_e" ]; then
                log "snapshot exists for $_n.$_e - keeping original"
                continue
            fi
            if ! sum_eq "$APP_DIR/$_n.$_e" "$(stock_sum $_n $_e)"; then
                log "FAIL: $APP_DIR/$_n.$_e is not stock, refusing to snapshot"
                return 1
            fi
            cp -f "$APP_DIR/$_n.$_e" "$BACKUP_DIR/$_n.$_e" || return 1
            sum_eq "$BACKUP_DIR/$_n.$_e" "$(stock_sum $_n $_e)" || { log "FAIL: snapshot of $_n.$_e mismatch"; return 1; }
            log "backed up $APP_DIR/$_n.$_e"
        done
    done
    return 0
}

# rebuild each app from the stock snapshot: lpatch delta (stock .odex -> modified
# classes.dex, refused unless the .odex is the exact original) + lpatch zipadd
# (stock APK + that classes.dex); the result must match the tested build
build_apps() {
    local _n _dex
    mkdir -p "$BUILD_DIR" || return 1
    _dex="$BUILD_DIR/classes.dex"
    for _n in $APPS; do
        if is_our_app "$_n"; then
            log "$_n: already this build - nothing to rebuild"
            continue
        fi
        if [ -s "$BUILD_DIR/$_n.apk" ] && sum_eq "$BUILD_DIR/$_n.apk" "$(new_sum $_n)"; then
            continue
        fi
        rm -f "$BUILD_DIR/$_n.apk" "$_dex" 2>/dev/null
        if ! "$(lp_bin)" delta "files/$_n.lpd" "$BACKUP_DIR/$_n.odex" "$_dex" >/dev/null 2>&1; then
            log "FAIL: stock $_n.odex is not the file this patch needs"
            return 1
        fi
        if ! "$(lp_bin)" zipadd "$BACKUP_DIR/$_n.apk" "$_dex" "$BUILD_DIR/$_n.apk" >/dev/null 2>&1; then
            rm -f "$_dex"
            log "FAIL: could not assemble $_n.apk"
            return 1
        fi
        rm -f "$_dex"
        if ! sum_eq "$BUILD_DIR/$_n.apk" "$(new_sum $_n)"; then
            rm -f "$BUILD_DIR/$_n.apk"
            log "FAIL: rebuilt $_n.apk does not match the tested build"
            return 1
        fi
        log "built $_n.apk from the stock files"
    done
    return 0
}

remove_build_dir() {
    case "$BUILD_DIR" in
        /data/nemesis/build/g70.carplay.bt) rm -rf "$BUILD_DIR" ;;
    esac
    true
}

apply_apps() {
    local _n _live _odex
    for _n in $APPS; do
        _live="$APP_DIR/$_n.apk"
        _odex="$APP_DIR/$_n.odex"
        if is_our_app "$_n"; then
            log "$_n: already this build"
            continue
        fi
        put_file "$BUILD_DIR/$_n.apk" "$_live" || { log "FAIL: could not write $_live"; return 1; }
        rm -f "$_odex" 2>/dev/null
        [ -f "$_odex" ] && { log "FAIL: could not delete $_odex"; return 1; }
        if write_odex "$_live" "$_odex"; then
            log "OK: $_n installed, odex written"
        else
            rm -f "$_odex" 2>/dev/null
            log "dexopt failed for $_n; boot will optimize"
        fi
    done
    wipe_dalvik
    for _n in $APPS; do
        prefill_dalvik "$APP_DIR/$_n.odex" "$APP_DIR/$_n.apk"
    done
    return 0
}

# restore_apps [force]: without force, only when this build is live
restore_apps() {
    local _n _e
    for _n in $APPS; do
        [ -s "$BACKUP_DIR/$_n.apk" ] || continue
        if [ "$1" != force ] && ! is_our_app "$_n" && ! is_prev_app "$_n" && ! [ -f "$APP_DIR/$_n.apk.g70tmp" ]; then
            if is_stock_app "$_n"; then
                log "$_n already stock"
            else
                log "WARN: live $_n is not this package's build - leaving it alone"
            fi
            continue
        fi
        for _e in apk odex; do
            if [ ! -s "$BACKUP_DIR/$_n.$_e" ]; then
                log "FAIL: incomplete snapshot for $_n"
                return 1
            fi
            put_file "$BACKUP_DIR/$_n.$_e" "$APP_DIR/$_n.$_e" || { log "FAIL: restore $_n.$_e"; return 1; }
        done
        log "restored stock $_n apk+odex"
    done
    wipe_dalvik
    return 0
}

# ---- props ----

set_prop() {
    local _got
    setprop "$1" "$2"
    _got=$(getprop "$1" 2>/dev/null)
    [ "$_got" = "$2" ] || { log "FAIL: $1 is '$_got' want '$2'"; return 1; }
    log "OK: $1=$_got"
}

snapshot_props() {
    local _prop
    mkdir -p "$BACKUP_DIR" || return 1
    [ -f "$PROP_FILE" ] && { log "snapshot exists for props - keeping original"; return 0; }
    : > "$PROP_FILE" || return 1
    for _prop in $PROPS; do
        echo "${_prop}=$(getprop "$_prop" 2>/dev/null)" >> "$PROP_FILE" || return 1
        log "backed up ${_prop}='$(getprop "$_prop" 2>/dev/null)'"
    done
}

apply_props() {
    local _prop
    for _prop in $PROPS; do
        set_prop "$_prop" "$PROP_ON" || return 1
    done
}

restore_props() {
    local _prop _val _rc=0
    [ -f "$PROP_FILE" ] || return 0
    while IFS='=' read -r _prop _val; do
        [ -n "$_prop" ] || continue
        # blank was the stock state; "f" reads the same to Iap2Server
        [ -n "$_val" ] || _val=$PROP_OFF
        set_prop "$_prop" "$_val" || _rc=1
    done < "$PROP_FILE"
    # the bridge's own switches
    setprop persist.leafia.g70.cpbridge "" 2>/dev/null
    setprop persist.leafia.g70.cpcomp "" 2>/dev/null
    return $_rc
}

# ---- libCarPlayCore.so: accept Wi-Fi sessions (Leafia recipe) ----

core_path() {
    local _p
    for _p in /system/lib/libCarPlayCore.so /vendor/lib/libCarPlayCore.so; do
        [ -s "$_p" ] && { echo "$_p"; return 0; }
    done
    return 1
}

core_state() {
    local _p
    _p=$(core_path) || { echo MISSING; return 0; }
    lp_state "$CORE_RECIPE" "$_p"
}

snapshot_core() {
    local _p
    _p=$(core_path) || return 1
    mkdir -p "$BACKUP_DIR" || return 1
    [ -s "$BACKUP_DIR/libCarPlayCore.so" ] && { log "snapshot exists for libCarPlayCore.so - keeping original"; return 0; }
    [ "$(core_state)" = PATCHABLE ] || { log "libCarPlayCore.so needs no patch - no snapshot"; return 0; }
    cp -f "$_p" "$BACKUP_DIR/libCarPlayCore.so" || return 1
    cmp "$_p" "$BACKUP_DIR/libCarPlayCore.so" >/dev/null 2>&1 || { log "FAIL: snapshot of libCarPlayCore.so mismatch"; return 1; }
    echo "$_p" > "$BACKUP_DIR/libCarPlayCore.path" || return 1
    log "backed up $_p"
}

apply_core() {
    local _p
    _p=$(core_path) || return 1
    case "$(core_state)" in
        APPLIED|NATIVE) log "libCarPlayCore.so: nothing to do"; return 0 ;;
        PATCHABLE) ;;
        *) log "FAIL: libCarPlayCore.so status $(core_state)"; return 1 ;;
    esac
    lp_apply "$CORE_RECIPE" "$_p" "$BACKUP_DIR/libCarPlayCore.patched" || { log "FAIL: lpatch could not patch $_p"; return 1; }
    if ! put_file "$BACKUP_DIR/libCarPlayCore.patched" "$_p"; then
        rm -f "$BACKUP_DIR/libCarPlayCore.patched"
        log "FAIL: could not write $_p"
        return 1
    fi
    rm -f "$BACKUP_DIR/libCarPlayCore.patched"
    [ "$(core_state)" = APPLIED ] || { log "FAIL: $_p did not verify after patching"; return 1; }
    log "OK: $_p patched (Wi-Fi CarPlay sessions allowed)"
}

restore_core() {
    local _p
    [ -s "$BACKUP_DIR/libCarPlayCore.so" ] || return 0
    _p=$(cat "$BACKUP_DIR/libCarPlayCore.path" 2>/dev/null)
    [ -n "$_p" ] || _p=$(core_path) || return 1
    if [ "$(core_state)" != APPLIED ]; then
        log "WARN: live libCarPlayCore.so is not this package's patch - leaving it alone"
        return 0
    fi
    put_file "$BACKUP_DIR/libCarPlayCore.so" "$_p" || { log "FAIL: restore $_p"; return 1; }
    log "restored stock $_p"
}

# ---- libautoreceiver_infobank.so: Android Auto turn-by-turn ----

is_prev_aalib() {
    local _s _live
    _live=$(file_md5 "$AA_LIB") || return 1
    for _s in $SUM_PREV_AALIB; do
        [ "$_live" = "$_s" ] && return 0
    done
    return 1
}

snapshot_aalib() {
    mkdir -p "$BACKUP_DIR" || return 1
    if sum_eq "$BACKUP_DIR/libautoreceiver_infobank.so" "$SUM_STOCK_AALIB"; then
        log "snapshot exists for libautoreceiver_infobank.so - keeping original"
        return 0
    fi
    sum_eq "$AA_LIB" "$SUM_STOCK_AALIB" || { log "FAIL: $AA_LIB is not stock, refusing to snapshot"; return 1; }
    cp -f "$AA_LIB" "$BACKUP_DIR/libautoreceiver_infobank.so" || return 1
    sum_eq "$BACKUP_DIR/libautoreceiver_infobank.so" "$SUM_STOCK_AALIB" || { log "FAIL: snapshot of libautoreceiver_infobank.so mismatch"; return 1; }
    log "backed up $AA_LIB"
}

apply_aalib() {
    local _tmp="$BACKUP_DIR/libautoreceiver_infobank.patched" _src="$AA_LIB"
    if sum_eq "$AA_LIB" "$SUM_NEW_AALIB"; then
        log "libautoreceiver_infobank.so: already this build"
        return 0
    fi
    # the delta applies to stock only; an earlier build is rebuilt from the backup
    sum_eq "$AA_LIB" "$SUM_STOCK_AALIB" || _src="$BACKUP_DIR/libautoreceiver_infobank.so"
    rm -f "$_tmp" 2>/dev/null
    "$(lp_bin)" delta "$AA_LPD" "$_src" "$_tmp" >/dev/null 2>&1 && sum_eq "$_tmp" "$SUM_NEW_AALIB" ||
        { rm -f "$_tmp"; log "FAIL: lpatch could not rebuild the Android Auto library"; return 1; }
    if ! put_file "$_tmp" "$AA_LIB"; then
        rm -f "$_tmp"
        log "FAIL: could not write $AA_LIB"
        return 1
    fi
    rm -f "$_tmp"
    log "OK: $AA_LIB patched (Android Auto turn-by-turn)"
}

restore_aalib() {
    [ -s "$BACKUP_DIR/libautoreceiver_infobank.so" ] || return 0
    if ! sum_eq "$AA_LIB" "$SUM_NEW_AALIB" && ! is_prev_aalib && ! [ -f "$AA_LIB.g70tmp" ]; then
        if sum_eq "$AA_LIB" "$SUM_STOCK_AALIB"; then log "libautoreceiver_infobank.so already stock"
        else log "WARN: live libautoreceiver_infobank.so is not this package's build - leaving it alone"; fi
        return 0
    fi
    put_file "$BACKUP_DIR/libautoreceiver_infobank.so" "$AA_LIB" || { log "FAIL: restore $AA_LIB"; return 1; }
    log "restored stock $AA_LIB"
}

# ---- Leafia's audio part ----

run_audio() {
    [ -f "comp/4_audio/scripts/$1.sh" ] || return 0
    log "== carplay.wifi.audio: $1"
    ( cd comp/4_audio && LP_ROOT=../.. /system/bin/sh "scripts/$1.sh" )
}

# rename our install descriptor on the USB drive so the next boot does not reinstall
retire_usb_descriptor() {
    local _d
    for _d in /storage/usb0 /storage/usb1 /storage/usb2 /mnt/media_rw/usb0 /mnt/media_rw/usb1 /mnt/media_rw/usb2; do
        [ -f "$_d/NEMESIS.data" ] || continue
        grep -q '^type=install' "$_d/NEMESIS.data" 2>/dev/null || continue
        grep -q 'g70\.carplay\.bt\.zip' "$_d/NEMESIS.data" 2>/dev/null || continue
        if mv "$_d/NEMESIS.data" "$_d/NEMESIS.data.installed" 2>/dev/null; then
            log "renamed $_d/NEMESIS.data to NEMESIS.data.installed so the next boot does not reinstall"
            # test drive: make the diagnostic probe the drive's next NEMESIS item
            if [ -f "$_d/_g70-probe/NEMESIS.sh" ] && [ -f "$_d/_g70-probe/NEMESIS.data" ]; then
                cp "$_d/_g70-probe/NEMESIS.sh" "$_d/NEMESIS.sh" 2>/dev/null &&
                    cp "$_d/_g70-probe/NEMESIS.data" "$_d/NEMESIS.data" 2>/dev/null &&
                    log "the USB drive now runs the diagnostic probe next time"
            fi
        else
            log "WARN: could not rename $_d/NEMESIS.data - remove the USB drive before the head unit restarts"
        fi
    done
    true
}

remove_backup_dir() {
    case "$BACKUP_DIR" in
        /data/nemesis/backup/g70.carplay.bt) rm -rf "$BACKUP_DIR" ;;
        *) log "FAIL: refusing to remove $BACKUP_DIR"; return 1 ;;
    esac
}
