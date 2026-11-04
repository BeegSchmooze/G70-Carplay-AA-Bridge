#!/bin/sh
# Update 23 DiPO (CarPlay lane guidance + e/v names that work on 260507) onto the no-camera
# firmware trees: 251120 = build/dipo20 itself; the ports keep their merged tree (renames done
# there) and get the recompiled bridge classes from /tmp/dipo20/smali (aa-port/build_dipo20.sh)
# plus hooks20_dipo.py. Then ports/build_port.sh checks each.
# usage: apply_dipo20.sh  (after aa-port/build_dipo20.sh, in the leafia container)
set -e
W=/work
S=/tmp/dipo20/smali/com/daudio/app/dipo
[ -f $S/LeafiaCpLane.smali ] || { echo "run aa-port/build_dipo20.sh first"; exit 1; }
rm -rf $W/build/g70-251120-nocam-dipo18
cp -r $W/build/dipo20 $W/build/g70-251120-nocam-dipo18
for fw in 250818 260507; do
    T=$W/build/g70-$fw-nocam-dipo18
    D=$T/com/daudio/app/dipo
    rm -f $D/LeafiaCpHandover*.smali $D/LeafiaCpRegister*.smali $D/LeafiaCpTurn*.smali $D/LeafiaCpLane*.smali
    cp $S/*.smali $D/
    python3 $W/aa-port/hooks20_dipo.py $T
done
for fw in 251120 250818 260507; do
    echo "######## $fw"
    sh $W/ports/build_port.sh g70-$fw-nocam 2>&1 | grep -E "^== HKMC_DiPO|problems" | head -2
done
