import re
# update 15 DiPO: run on build/dipo15 (a copy of build/dipo14, already hooked by hooks14_dipo.py)
B = '/work/build/dipo15/com/daudio/app/dipo/'

# Stock bug: CarPlayService's non-blocking iAPSendMessage thread (CarPlayService$1iAPSendMessage)
# only stores the length when its own field is outside the int range (never), so every
# message reaches TccCarPlay_iAPSendMessage with size 0 (INVALID_ARGUMENT). Unused on the
# stock US car; the CarPlay-channel iAP2 handover sends through it. Store the length.
p = B + 'telechips/CarPlayService$1iAPSendMessage.smali'
s = open(p).read()
pat = re.compile(r'(\.method private declared-synchronized setMsgDataLen\(I\)V\n).*?(\.end method)', re.S)
assert len(pat.findall(s)) == 1
s = pat.sub(lambda m: m.group(1) +
            '    .registers 2\n\n'
            '    # Leafia G70: store the length (stock compared its own field, so it stayed 0)\n'
            '    monitor-enter p0\n\n'
            '    iput p1, p0, Lcom/daudio/app/dipo/telechips/CarPlayService$1iAPSendMessage;->len:I\n\n'
            '    monitor-exit p0\n\n'
            '    return-void\n' + m.group(2), s, count=1)
open(p, 'w').write(s)

print('ok')
