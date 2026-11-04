#!/system/bin/sh
# G70 camera list: copies cameras.csv from this drive to /data/leafia/cameras.csv, where the
# bridge's camera alerts (update 21 and later) read it; they pick a new file up within seconds.
# CSV: lat,lon,type,speed,heading,f2,category (type "redlight" = red-light camera, anything else
# = speed camera). With no cameras.csv on the drive the list on the car is removed instead
# (alerts off). Result: G70CAMERAS-<n>/result.txt on this drive.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin

_n=1
while [ -e "$(pwd)/G70CAMERAS-$_n" ]; do _n=$((_n + 1)); done
OUT=$(pwd)/G70CAMERAS-$_n
mkdir -p "$OUT" || exit 1
D=/data/leafia
F=$D/cameras.csv
(
    echo "g70-cameras $(date)"
    if [ -f "$(pwd)/cameras.csv" ]; then
        mkdir -p $D && chmod 755 $D
        cp "$(pwd)/cameras.csv" $F && chmod 644 $F && sync
        echo "copied: $(ls -l $F)"
    else
        rm -f $F
        echo "no cameras.csv on the drive: camera list removed (alerts off)"
    fi
    echo "sys.leafia.cam=$(getprop sys.leafia.cam)"
    logcat -d -s LeafiaCAM 2>/dev/null | tail -20
) > "$OUT/result.txt" 2>&1
sync
exit 0
