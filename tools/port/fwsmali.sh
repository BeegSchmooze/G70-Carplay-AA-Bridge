#!/bin/sh
# Deodex a port's framework odex files -> ports/<port>/fwsmali/<jar>/ (as /work/fwsmali for the G70).
W=/work
P=$W/ports/$1
F=$P/framework
BCP=""
for j in core conscrypt okhttp core-junit bouncycastle ext framework framework2 telephony-common voip-common \
         mms-common android.policy services apache-xml webviewchromium automotive; do
    [ -f $F/$j.odex ] && BCP="$BCP:$F/$j.odex"
done
for f in $F/*.odex; do case ":$BCP:" in *":$f:"*) ;; *) BCP="$BCP:$f" ;; esac; done
BCP=${BCP#:}
rm -rf $P/fwsmali
for f in $F/*.odex; do
    n=$(basename $f .odex)
    java -jar $W/bin/baksmali.jar x -a 18 -b "$BCP" -o $P/fwsmali/$n $f > /dev/null 2>&1 || echo "fail $n"
done
# jars that carry their own classes.dex (no odex), e.g. com.broadcom.bt.jar
for j in $F/*.jar; do
    n=$(basename $j .jar)
    [ -d $P/fwsmali/$n ] && continue
    unzip -l $j 2>/dev/null | grep -q classes.dex && java -jar $W/bin/baksmali.jar d -o $P/fwsmali/$n $j
done
ls $P/fwsmali | wc -l
