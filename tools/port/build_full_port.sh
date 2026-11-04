#!/bin/sh
# Full standalone bridge (g70.carplay.bt, update 22 scripts) for a port: the merged trees of
# ports/merge.py (build/<port>-dipo18/gpm15/navi14/iap2, checked by ports/build_port.sh), the
# Android Auto library from aa-tbt/build_lib_port.py, deltas against the port's stock files.
# -> release-<port>/dist/packages/g70.carplay.bt.zip
# usage: build_full_port.sh <port> <firmware name>
set -e
W=/work
PORT=$1; FW=$2
P=$W/ports/$PORT
LP=$W/HMG-Leafia-Plus/tools/lpatch/lpatch-host
cd $W
python3 aa-tbt/build_lib_port.py $P/lib/libautoreceiver_infobank.so \
    $(md5sum < $P/lib/libautoreceiver_infobank.so | cut -d' ' -f1) build/$PORT-libautoreceiver_infobank.so $PORT
R=$W/release-$PORT
rm -rf $R && mkdir -p $R build/out
cp -r release-u22/pkg $R/pkg
C=$R/pkg/scripts/common.sh
sum() { md5sum < "$1" | cut -d' ' -f1; }
for m in HKMC_DiPO:dipo18 HKMC_GPM:gpm15 HKMC_Navi_ExSL:navi14 Iap2ServerApp:iap2; do
    a=${m%%:*}; t=${m#*:}
    python3 HMG-Leafia-Plus/tools/mkdelta.py $P/app/$a.odex build/$PORT-$t.dex $R/pkg/files/$a.lpd
    rm -f build/out/$a-$PORT.apk
    $LP zipadd $P/app/$a.apk build/$PORT-$t.dex build/out/$a-$PORT.apk
    sed -i "s/^SUM_STOCK_${a}_apk=.*/SUM_STOCK_${a}_apk=$(sum $P/app/$a.apk)/; s/^SUM_STOCK_${a}_odex=.*/SUM_STOCK_${a}_odex=$(sum $P/app/$a.odex)/" $C
    sed -i "s/^SUM_NEW_${a}=.*/SUM_NEW_${a}=$(sum build/out/$a-$PORT.apk)/; s/^SUM_PREV_${a}=.*/SUM_PREV_${a}=\"\"/" $C
done
python3 HMG-Leafia-Plus/tools/mkdelta.py $P/lib/libautoreceiver_infobank.so build/$PORT-libautoreceiver_infobank.so \
    $R/pkg/files/libautoreceiver_infobank.tbt.lpd
sed -i "s/^SUM_STOCK_AALIB=.*/SUM_STOCK_AALIB=$(sum $P/lib/libautoreceiver_infobank.so)/; s/^SUM_NEW_AALIB=.*/SUM_NEW_AALIB=$(sum build/$PORT-libautoreceiver_infobank.so)/; s/^SUM_PREV_AALIB=.*/SUM_PREV_AALIB=\"\"/" $C
sed -i "s/^PRODUCT=.*/PRODUCT=$FW/; s/built on IKFL.USA 251120/built on $FW (port)/" $C
grep -n "^PRODUCT\|^SUM_STOCK\|^SUM_NEW\|^SUM_PREV" $C | cut -c1-110
mkdir -p $R/dist/packages
(cd $R/pkg && zip -qrX ../dist/packages/g70.carplay.bt.zip .)
md5sum $R/dist/packages/g70.carplay.bt.zip
