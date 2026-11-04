#!/bin/sh
# Assemble the merged trees of a port (build/<port>-<tree>, from ports/merge.py) and check them:
# every reference from our changed/added classes resolves in the app + the port's framework
# (check_refs), and no register is read Conflicted/Uninit (check_regs, baksmali register
# analysis against the port's framework). -> build/<port>-<tree>.dex
set -e
W=/work
PORT=$1
P=$W/ports/$PORT
BCP=$(ls $P/framework/*.odex | tr '\n' ':')
for m in HKMC_DiPO:dipo18 HKMC_GPM:gpm15 HKMC_Navi_ExSL:navi14 Iap2ServerApp:iap2; do
    a=${m%%:*}; t=${m#*:}; T=$W/build/$PORT-$t
    java -jar $W/bin/smali.jar a --api 18 -o $T.dex $T
    # our classes: the ones that differ from the port's stock
    FILES=$(cd $T && find . -name '*.smali' | while read f; do
        s=$P/smali/$a/$f
        if [ ! -f "$s" ] || ! cmp -s "$T/$f" "$s"; then echo "$T/${f#./}"; fi
    done)
    n=$(echo "$FILES" | grep -c smali)
    echo "== $a: $n classes ours, dex $(md5sum < $T.dex | cut -c1-8)"
    python3 $W/tools-g70/check_refs.py $T $P/fwsmali $FILES
    CL=$(for f in $FILES; do sed -n 's/^\.class.* \(L.*;\)$/\1/p' "$f" | head -1; done | tr '\n' ',' | sed 's/,$//')
    rm -rf /tmp/regs-$PORT-$t
    java -jar $W/bin/baksmali.jar d -r ALL,FULLMERGE -b "$BCP" -o /tmp/regs-$PORT-$t --classes "$CL" $T.dex
    python3 $W/tools-g70/check_regs.py $(find /tmp/regs-$PORT-$t -name '*.smali')
done
