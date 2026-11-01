# Adds a logging stub to the ported library: routeMessage+0xe8 -> stub (logs the
# navigation message type and length to the system log, tag LeafiaAA) -> 0x1c4120.
import struct, subprocess, sys, hashlib
src, dst = sys.argv[1:3]
d = bytearray(open(src,'rb').read())
SEG=0x1c4000; OLD_END=0x1c56ca; STUB=0x1c56cc; PLT_LOG=0xa5388; TRAMP=0x1c4120; HOOK=0xbccb0
assert len(d)==OLD_END
def asm(text):
    open('/tmp/stub.s','w').write('.syntax unified\n.thumb\n'+text+'\n')
    subprocess.check_call(['llvm-mc','-triple=thumbv7a-linux-androideabi','-filetype=obj','-o','/tmp/stub.o','/tmp/stub.s'])
    subprocess.check_call(['llvm-objcopy','-O','binary','--only-section=.text','/tmp/stub.o','/tmp/stub.bin'])
    return open('/tmp/stub.bin','rb').read()
def bl(src,dst,x):     # x=False: BL (thumb), x=True: BLX to ARM
    pc = src+4
    if x: pc &= ~3
    off = dst-pc; s = 1 if off<0 else 0; off &= 0x1ffffff
    i1=(off>>23)&1; i2=(off>>22)&1; j1=(~(i1^s))&1; j2=(~(i2^s))&1
    hi=0xf000|(s<<10)|((off>>12)&0x3ff)
    lo=(0xc000 if x else 0xd000)|(j1<<13)|(j2<<11)|((off>>1)&0x7ff)
    if x: lo &= ~1
    return struct.pack('<HH',hi,lo)
def bw(src,dst):
    off=dst-(src+4); s=1 if off<0 else 0; off&=0x1ffffff
    i1=(off>>23)&1; i2=(off>>22)&1; j1=(~(i1^s))&1; j2=(~(i2^s))&1
    return struct.pack('<HH',0xf000|(s<<10)|((off>>12)&0x3ff),0x9000|(j1<<13)|(j2<<11)|((off>>1)&0x7ff))
# layout: code, then strings at fixed offsets
pre = asm('''
    push {r0-r4, lr}
    sub sp, #8
    str r2, [sp]
    str r5, [sp, #4]
    movs r0, #3
    movs r1, #4
    .short 0xa204
    .short 0xa307
''')
assert len(pre)==16, len(pre)   # 0..15
code = bytearray(pre)
code += bl(STUB+len(code), PLT_LOG, True)      # 16..19
code += asm('add sp, #8\npop {r0-r4, lr}')     # 20..23
code += bw(STUB+len(code), TRAMP)              # 24..27
code += b'\0'*(32-len(code))
tag = b'LeafiaAA\0'; code += tag + b'\0'*(44-32-len(tag))
code += b'nav msg 0x%x len %d\0'
code += b'\0'*((-len(code))%4)
d += b'\0'*(STUB-OLD_END) + code
end = len(d)
# grow the patch PT_LOAD (9th program header at 0x1c4000 + 8*32)
ph = SEG + 8*32
t,off,va,pa,fs,ms,fl,al = struct.unpack_from('<IIIIIIII',d,ph)
assert (t,off,va,fs)==(1,SEG,SEG,OLD_END-SEG)
struct.pack_into('<IIIIIIII',d,ph,t,off,va,pa,end-SEG,end-SEG,fl,al)
assert d[HOOK:HOOK+4]==bw(HOOK,TRAMP)
d[HOOK:HOOK+4]=bw(HOOK,STUB)
open(dst,'wb').write(d)
print(len(d), hashlib.md5(d).hexdigest())
