import re, sys
# update 16 DiPO: run on build/dipo16 (a copy of build/dipo15, already hooked by hooks14/15)
B = (sys.argv[1] if len(sys.argv) > 1 else '/work/build/dipo16') + '/com/daudio/app/dipo/'
H = 'Lcom/daudio/app/dipo/LeafiaCpHandover;'

# DiPO's iAP2 listener (e/g) passes notifications on only while e/b.ai ("notify_flag") is
# set, and only connected() with a device serial sets it. The iAP2 server reports wireless
# sessions without a serial ("IAP2Listener connected serial is null"), so route guidance
# from the iPhone was dropped. For a bridged wireless session, set the flag (nothing else).
p = B + 'e/g.smali'
s = open(p).read()
head = '.method public final connected(ILjava/lang/String;)V\n    .registers 6\n'
assert s.count(head) == 1
s = s.replace(head, head + '''
    # Leafia G70: a bridged wireless iAP2 session (no serial) lets DiPO's notifications through
    invoke-static {p1, p2}, ''' + H + '''->letNotify(ILjava/lang/String;)Z

    move-result v0

    if-eqz v0, :leafia_keep

    iget-object v0, p0, Lcom/daudio/app/dipo/e/g;->mH:Lcom/daudio/app/dipo/e/a;

    iget-object v0, v0, Lcom/daudio/app/dipo/e/a;->Q:Lcom/daudio/app/dipo/e/b;

    const/4 v1, 0x1

    invoke-static {v0, v1}, Lcom/daudio/app/dipo/e/b;->a(Lcom/daudio/app/dipo/e/b;Z)Z

    :leafia_keep
''', 1)
open(p, 'w').write(s)
print('ok')
