import re
B = '/work/build/gpm12/'
AA = 'Lcom/google/android/projection/leafia/LeafiaAa;'

def rd(p):
    return open(B + p).read()

def wr(p, s):
    open(B + p, 'w').write(s)

def replace_method(p, sig, body):
    s = rd(p)
    pat = re.compile(r'\.method public ' + re.escape(sig) + r'\n.*?\.end method\n', re.S)
    assert len(pat.findall(s)) == 1, (p, sig)
    s = pat.sub(lambda m: body, s)
    wr(p, s)

def insert_before(p, needle, text, count=None):
    s = rd(p)
    lines = s.split('\n')
    out, n = [], 0
    for ln in lines:
        if needle in ln:
            ind = ln[:len(ln) - len(ln.lstrip())]
            out.append(ind + text)
            out.append('')
            n += 1
        out.append(ln)
    assert n >= 1 and (count is None or n == count), (p, needle, n)
    wr(p, '\n'.join(out))
    return n

NS = 'com/google/android/projection/protocol/NavigationStatus.smali'
replace_method(NS, 'navigationNextTurnCallback(Ljava/lang/String;II[BII)V', '''.method public navigationNextTurnCallback(Ljava/lang/String;II[BII)V
    .registers 7

    # Leafia G70: Android Auto turn-by-turn runs in the HMG-API AaTurns port
    # (com.google.android.projection.leafia), not in GPM's own manager
    invoke-static/range {p1 .. p6}, ''' + AA + '''->nextTurn(Ljava/lang/String;II[BII)V

    return-void
.end method
''')
replace_method(NS, 'navigationNextTurnDistanceCallback(IIII)V', '''.method public navigationNextTurnDistanceCallback(IIII)V
    .registers 5

    # Leafia G70: to the AaTurns port (distance, turns ahead 0x200, remaining trip 0x100)
    invoke-static {p1, p2, p3, p4}, ''' + AA + '''->distance(IIII)V

    return-void
.end method
''')
s = rd(NS)
old = '''.method public navigationStatusCallback(I)V
    .registers 3
'''
assert s.count(old) == 1
s = s.replace(old, old + '''
    # Leafia G70: the AaTurns port needs the navigation status too
    invoke-static {p1}, ''' + AA + '''->status(I)V
''')
wr(NS, s)

# the car's navigation took the focus: forget the phone's turn
n = insert_before('com/google/android/projection/service/GalConnectionSession$6.smali',
                  'Lcom/google/android/projection/sink/navigation/GpmNaviTBTManager;->stop()V',
                  'invoke-static {}, ' + AA + '->focusNative()V', 1)
# the connection ends (session teardown stops / destroys GPM's manager)
n2 = insert_before('com/google/android/projection/service/GalConnectionSession.smali',
                   'Lcom/google/android/projection/sink/navigation/GpmNaviTBTManager;->destroy()V',
                   'invoke-static {}, ' + AA + '->sessionEnd()V')
# vehicle speed (km/h) for the count-down
p = 'com/google/android/projection/sink/b/i.smali'
s = rd(p)
old = '''.method public final onVehicleSpeedChanged(I)V
    .registers 5
'''
assert s.count(old) == 1
s = s.replace(old, old + '''
    # Leafia G70: km/h for the turn-distance count-down
    invoke-static {p1}, ''' + AA + '''->speed(I)V
''')
wr(p, s)
print('ok focus', n, 'end', n2)
