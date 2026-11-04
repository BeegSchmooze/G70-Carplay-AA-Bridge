import sys, subprocess, re
# Maps G70 251120 addresses in libautoreceiver_infobank.so to another build of the library:
# nearest dynamic symbol + offset, checked by comparing the bytes around the address.
A, B = sys.argv[1], sys.argv[2]
def syms(p):
    out = subprocess.check_output(['readelf', '-W', '--dyn-syms', p]).decode()
    d = {}
    for l in out.splitlines():
        f = l.split()
        if len(f) >= 8 and f[3] in ('FUNC', 'OBJECT') and f[1] != '00000000':
            d[f[7]] = (int(f[1], 16) & ~1, int(f[2]) if f[2].isdigit() else 0)
    return d
sa, sb = syms(A), syms(B)
a = open(A, 'rb').read(); b = open(B, 'rb').read()
for x in [int(v, 16) for v in sys.argv[3:]]:
    best = None
    for n, (ad, sz) in sa.items():
        if ad <= x < ad + max(sz, 1) and n in sb:
            best = (n, ad); break
    if not best:
        cand = [(x - ad, n, ad) for n, (ad, sz) in sa.items() if ad <= x and n in sb]
        cand.sort(); best = (cand[0][1], cand[0][2]) if cand else None
    if not best:
        print(hex(x), 'no symbol'); continue
    n, ad = best; off = x - ad; y = sb[n][0] + off
    ok = a[x - 8:x + 8] == b[y - 8:y + 8]
    print('%s -> %s  (%s +0x%x) bytes %s' % (hex(x), hex(y), n[:70], off, 'match' if ok else 'DIFFER'))
