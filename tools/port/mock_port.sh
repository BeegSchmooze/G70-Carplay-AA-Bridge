#!/bin/sh
# Mock installs of a port's packages on that port's own stock files (its port probe): the full
# standalone bridge and the turn-by-turn-only package, fresh install + uninstall in several
# conditions; each must leave /system byte-identical. Also: refused on the 251120 G70's files,
# turn-by-turn refused while the bridge is installed.
# usage: mock_port.sh <port> <firmware name>
W=/work
PORT=$1; FW=$2
SH=$(command -v mksh || echo /bin/sh)
S=/tmp/stock-$PORT; rm -rf $S; mkdir -p $S
cp -r $W/ports/$PORT/app $W/ports/$PORT/lib $W/ports/$PORT/framework $W/ports/$PORT/etc $W/ports/$PORT/build.prop $S/
mkdir -p $S/onebin/ikfl_us && cp $W/ports/$PORT/onebin/featurexml.cfg $S/onebin/ikfl_us/
# the audio part only checks that the AAC decoder exists (the port probe did not copy it; the
# car has its own build): the 251120 copy stands in
[ -f $S/lib/libstagefright_soft_aacdec.so ] || cp $W/g70-stock/lib/libstagefright_soft_aacdec.so $S/lib/
L=/tmp/stock-251120; rm -rf $L; cp -r $W/g70-stock $L; mkdir -p $L/onebin/ikfl_us && mv $L/onebin/featurexml.cfg $L/onebin/ikfl_us/

zipit() {  # $1 release dir, $2 package id -> $1/dist/G70.zip
    (cd $1/dist && printf '[nemesis]\nversion=1.0\ntype=install\npath=packages/%s.zip\n' $2 > NEMESIS.data \
        && rm -f G70.zip && zip -qrX G70.zip NEMESIS.data packages)
}
zipit $W/release-$PORT g70.carplay.bt
zipit $W/release-$PORT-tbt g70.tbt

t() {  # $1 label, $2 zip, $3 package id, $4 stock dir, $5 firmware, rest: env
    _l=$1; _z=$2; _id=$3; _s=$4; _f=$5; shift 5
    echo "== $_l"
    env MOCK_PKG=$_id MOCK_SH=$SH "$@" sh $W/tools-g70/mock-test.sh $_z $_f ikfl_us $_s > /tmp/mockport.out 2>&1
    grep -E "INSTALL|UNINSTALL|REFUSED|FAIL" /tmp/mockport.out | head -3
    _x=$(sed -n 's/^sandbox (logs[^)]*): //p' /tmp/mockport.out)
    grep -hE "^FAIL|: stock - ok|added /system|commented|Wi-Fi patch|persist.ium" $_x/pre.log $_x/post.log 2>/dev/null | sed "s#$_x/root##g" | sort -u | head -12
    # the bridge on factory files must switch the wireless features and the hotspot on
    case "$_id:$_l" in g70.carplay.bt:*refused*) ;; g70.carplay.bt:*)
        grep -q "commented the wireless" $_x/post.log || echo "FAIL: featurexml.cfg left as it was"
        for _p in carplay_wireless androidauto_wireless wifihotspot android.hardware.wifi; do
            grep -qE "added .*$_p|$_p.*already present" $_x/post.log || echo "FAIL: $_p feature file not added"
        done ;;
    esac
}
B=$W/release-$PORT/dist/G70.zip; T=$W/release-$PORT-tbt/dist/G70.zip
t "bridge: fresh install" $B g70.carplay.bt $S $FW
t "bridge: Android down" $B g70.carplay.bt $S $FW MOCK_ANDROID_DOWN=1
t "bridge: NEMESIS 1.15" $B g70.carplay.bt $S $FW MOCK_NEMESIS=1.15
t "bridge: install descriptor on the drive" $B g70.carplay.bt $S $FW MOCK_USB_DESCRIPTOR=1
t "bridge: on the 251120 G70's files (must be refused)" $B g70.carplay.bt $L IKFL.USA.0000.V014.011.251120
t "turn-by-turn: fresh install" $T g70.tbt $S $FW
t "turn-by-turn: Android down" $T g70.tbt $S $FW MOCK_ANDROID_DOWN=1
t "turn-by-turn: bridge installed (must be refused)" $T g70.tbt $S $FW MOCK_BRIDGE_INSTALLED=1
t "turn-by-turn: on the 251120 G70's files (must be refused)" $T g70.tbt $L IKFL.USA.0000.V014.011.251120
