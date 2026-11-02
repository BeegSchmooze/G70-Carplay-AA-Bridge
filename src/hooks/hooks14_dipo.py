import re
# update 14 DiPO: hooks for the CarPlay-channel iAP2 handover (LeafiaCpHandover) in
# DiPO's own classes. Run on build/dipo14 after the bridge smali is copied in.
B = '/work/build/dipo14/com/daudio/app/dipo/'
H = 'Lcom/daudio/app/dipo/LeafiaCpHandover;'
CP = 'Lcom/daudio/app/dipo/telechips/CarPlayService;'


def hook_start(path, sig, text):
    """Insert text right after the .registers line of a method (all its p-registers are < v16)."""
    s = open(path).read()
    pat = re.compile(r'(\.method public (?:final )?' + re.escape(sig) + r'\n    \.registers (\d+)\n)')
    m = pat.findall(s)
    assert len(m) == 1, (path, sig, len(m))
    assert int(m[0][1]) <= 16, (sig, 'registers')
    s = pat.sub(lambda mm: mm.group(1) + '\n' + text + '\n', s, count=1)
    open(path, 'w').write(s)


hook_start(B + 'telechips/CarPlayService.smali', 'onSessionStarted(I)V',
           '    # Leafia G70: wireless session (transport) for the iAP2 handover\n'
           '    invoke-static {p0, p1}, ' + H + '->sessionStarted(' + CP + 'I)V')
hook_start(B + 'telechips/CarPlayService.smali', 'onSessionFinalized(I)V',
           '    # Leafia G70: end the CarPlay-channel iAP2 session with the CarPlay session\n'
           '    invoke-static {p1}, ' + H + '->sessionFinalized(I)V')
hook_start(B + 'telechips/CarPlayService.smali', 'oniAPSendMessage([BI)V',
           '    # Leafia G70: iAP2 from the iPhone on the CarPlay channel goes to the iAP2 server\n'
           '    invoke-static {p0, p1, p2}, ' + H + '->fromPhone(' + CP + '[BI)V')
hook_start(B + 'e/g.smali', 'notify(IIILcom/tcc/iap2/Iap2NotiMsg;)V',
           '    # Leafia G70: the CarPlay-channel session\'s identification is not a new phone\n'
           '    invoke-static {p1}, ' + H + '->dropNoti(I)Z\n'
           '    move-result v0\n'
           '    if-eqz v0, :leafia_keep\n'
           '    return-void\n'
           '    :leafia_keep')

# CarPlay turns drawn like the built-in navigation (LeafiaCpTurn): e/u reports the
# maneuver it looked up, and its updateTBTInfo goes through the wrapper
T = 'Lcom/daudio/app/dipo/LeafiaCpTurn;'
p = B + 'e/u.smali'
s = open(p).read()
old = '    check-cast v0, Lcom/daudio/app/dipo/e/v;\n'
assert s.count(old) == 1
s = s.replace(old, old + '\n    # Leafia G70: the maneuver about to be sent (junction angles for the drawn turn)\n'
              '    invoke-static {v0}, ' + T + '->current(Ljava/lang/Object;)V\n')
old = '    invoke-virtual/range {v0 .. v9}, Lcom/hkmc/cluster/NavigationCluster;->updateTBTInfo(IIFFIIIII)V\n'
assert s.count(old) == 1
s = s.replace(old, '    # Leafia G70: drawn turn types, side roads and the HUD distance\n'
              '    invoke-static/range {v0 .. v9}, ' + T + '->updateTBTInfo(Lcom/hkmc/cluster/NavigationCluster;IIFFIIIII)V\n')
open(p, 'w').write(s)
print('ok')
