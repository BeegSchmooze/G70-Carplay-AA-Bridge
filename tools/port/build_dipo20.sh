#!/bin/sh
# Update 23 DiPO: build/dipo18 + recompiled cpreg/src (new LeafiaCpLane; LeafiaCpTurn hands it
# e/u's cluster) + hooks20_dipo.py (CarPlay lane guidance) -> build/dipo20 (+ .dex), then the
# reference / register checks against the 251120 framework.
# Run in the leafia container (leafia-work at /work).
set -e
W=/work
SDK=$W/sdk/android-4.4.2/android.jar
T=/tmp/dipo20
rm -rf $T $W/build/dipo20
mkdir -p $T/stubs $T/cls $T/dex
cp -r $W/build/dipo18 $W/build/dipo20

javac -nowarn -source 7 -target 7 -encoding utf8 -cp $SDK -d $T/stubs $(find $W/aa-port/cpreg/stubs -name '*.java') \
    $W/aa-port/stubs/com/hkmc/cluster/NavigationCluster.java
javac -nowarn -source 7 -target 7 -encoding utf8 -cp $SDK:$T/stubs -d $T/cls $(find $W/aa-port/cpreg/src -name '*.java')
java -cp $W/sdk/android-11/lib/d8.jar com.android.tools.r8.D8 --release --min-api 18 --lib $SDK --classpath $T/stubs \
    --output $T/dex $(find $T/cls -name '*.class')
java -jar $W/bin/baksmali.jar d -o $T/smali $T/dex/classes.dex
rm -f $W/build/dipo20/com/daudio/app/dipo/LeafiaCpHandover*.smali $W/build/dipo20/com/daudio/app/dipo/LeafiaCpRegister*.smali \
      $W/build/dipo20/com/daudio/app/dipo/LeafiaCpTurn*.smali $W/build/dipo20/com/daudio/app/dipo/LeafiaCpLane*.smali
cp $T/smali/com/daudio/app/dipo/*.smali $W/build/dipo20/com/daudio/app/dipo/
ls $T/smali/com/daudio/app/dipo/

python3 $W/aa-port/hooks20_dipo.py $W/build/dipo20
java -jar $W/bin/smali.jar a --api 18 -o $W/build/dipo20.dex $W/build/dipo20
md5sum $W/build/dipo20.dex
# our classes + e/u against the 251120 framework
D=$W/build/dipo20/com/daudio/app/dipo
python3 $W/tools-g70/check_refs.py $W/build/dipo20 $W/fwsmali $D/LeafiaCp*.smali $D/e/u.smali
