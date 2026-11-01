# Ports Leafia's AA turn-by-turn library patch (patches/common, US EV6 stock) to the
# G70 stock libautoreceiver_infobank.so (md5 9ee6c1d4...). See G70-PORT-NOTES.md.
import struct, hashlib, sys
STOCK='../g70-stock/lib/libautoreceiver_infobank.so'
g=bytearray(open(STOCK,'rb').read())
assert hashlib.md5(g).hexdigest()=='9ee6c1d408eaed98c43e03bef5e4866c'
ap=open('approx.so','rb').read()          # delta applied over G70 bytes (new segment = verbatim extras)
SEG=0x1c4000; END=0x1c56ca
out=bytearray(g)
# ELF header: program headers move to 0x1c4000, 9 entries
struct.pack_into('<I',out,0x1c,SEG); struct.pack_into('<H',out,0x2c,9)
out+=b'\0'*(SEG-len(out))
seg=bytearray(ap[SEG:END])
# phdrs: G70's 8 (same layout as US) with PT_PHDR moved, plus the new R+X PT_LOAD
ph=bytearray(g[0x34:0x34+8*32])
struct.pack_into('<IIIIIIII',ph,0,6,SEG,SEG,SEG,0x120,0x120,4,4)
ph+=struct.pack('<IIIIIIII',1,SEG,SEG,SEG,END-SEG,END-SEG,5,0x1000)
assert seg[:0x120]==ph, 'phdr mismatch vs Leafia layout'
# byte runs the delta copied from US stock (recovered; each found once in G70 stock)
fix={0x1c437e:'704700207047'+'38b50446',
     0x1c4418:'4ff0ff3005b0bde8f08f', 0x1c44a4:'4ff0ff3005b0bde8f08f',
     0x1c47dd:'f1000918bf4ff00109',
     0x1c56b8:'00'+b'0123456789abcdef'.hex()+'00'}
for a,h in fix.items():
    b=bytes.fromhex(h); seg[a-SEG:a-SEG+len(b)]=b
# relative table at 0x1c4160: entries are target - 0x1c4160
T=0x1c4160
tab=[0xaef3f,  # thunk NavigationStatusCallbacks::navigationNextTurnCallback
     0xaeeaf,  # thunk ...::navigationNextTurnDistanceCallback
     0xa64dd,  # _String_base range initialize (as in handleNavigationNextTurnEvent)
     0xa6455,  # _String_base::_M_deallocate_block
     0xbccb5]  # return: routeMessage+0xec
for i,t in enumerate(tab): struct.pack_into('<i',seg,T-SEG+4*i,t-T)
out+=seg
# hooks
assert out[0xb7d3e:0xb7d40]==bytes.fromhex('0426'); out[0xb7d3e]=0x06   # sendVersionRequest+0x12: minor 4 -> 6
assert out[0x144e9a:0x144e9c]==bytes.fromhex('0228'); out[0x144e9a]=0x03 # RdsType_IsValid: cmp #2 -> #3
assert out[0xbccb0:0xbccb4]==bytes.fromhex('6ff0fc04')
def bw(src,dst):
    off=dst-(src+4); s=1 if off<0 else 0; off&=0x1ffffff
    i1=(off>>23)&1; i2=(off>>22)&1; j1=(~(i1^s))&1; j2=(~(i2^s))&1
    hi=0xf000|(s<<10)|((off>>12)&0x3ff); lo=0x9000|(j1<<13)|(j2<<11)|((off>>1)&0x7ff)
    return struct.pack('<HH',hi,lo)
out[0xbccb0:0xbccb4]=bw(0xbccb0,0x1c4120)
open(sys.argv[1],'wb').write(out)
print(len(out),hashlib.md5(out).hexdigest())
