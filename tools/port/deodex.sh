#!/bin/sh
# Deodex a port probe's apps against its own framework (baksmali x -a 18, the BOOTCLASSPATH
# order then every other framework odex; Navi with the odex's own dependency list) ->
# ports/<name>/smali/<App>, then compare with the G70 251120 stock smali (g70/<App>).
W=/work
P=$W/ports/$1
F=$P/framework
mkdir -p $P/smali
BCP=""
for j in core conscrypt okhttp core-junit bouncycastle ext framework framework2 telephony-common voip-common \
         mms-common android.policy services apache-xml webviewchromium automotive; do
    [ -f $F/$j.odex ] && BCP="$BCP:$F/$j.odex"
done
for f in $F/*.odex; do
    case ":$BCP:" in *":$f:"*) ;; *) BCP="$BCP:$f" ;; esac
done
BCP=${BCP#:}
for a in HKMC_DiPO HKMC_GPM HKMC_Navi_ExSL Iap2ServerApp; do
    rm -rf $P/smali/$a
    if [ $a = HKMC_Navi_ExSL ]; then
        java -jar $W/bin/baksmali.jar x -a 18 -d $F -o $P/smali/$a $P/app/$a.odex > $P/smali/$a.err 2>&1
    else
        java -jar $W/bin/baksmali.jar x -a 18 -b "$BCP" -o $P/smali/$a $P/app/$a.odex > $P/smali/$a.err 2>&1
    fi
    o=$(cd $W/g70/$a && find . -name '*.smali' | wc -l); t=$(cd $P/smali/$a && find . -name '*.smali' | wc -l)
    ch=$(diff -rq --strip-trailing-cr $W/g70/$a $P/smali/$a | grep -c "differ")
    on=$(diff -rq --strip-trailing-cr $W/g70/$a $P/smali/$a | grep -c "^Only in")
    lines=$(diff -r --strip-trailing-cr $W/g70/$a $P/smali/$a | grep -c "^[<>]")
    echo "$a: ours $o classes, theirs $t, changed $ch, only one side $on, diff lines $lines, errors $(grep -c Error $P/smali/$a.err)"
done
