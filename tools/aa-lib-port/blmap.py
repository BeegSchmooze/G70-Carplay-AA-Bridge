import sys, struct, subprocess
# Matches BL/BLX call targets between two builds of a library: for each exported function present
# in both with the same size, the n-th BL in one maps to the n-th BL in the other.
A, B = sys.argv[1], sys.argv[2]
want = [int(v, 16) for v in sys.argv[3:]]
def syms(p):
    d = {}
    for l in subprocess.check_output(['readelf', '-W', '--dyn-syms', p]).decode().splitlines():
        f = l.split()
        if len(f) >= 8 and f[3] == 'FUNC' and f[1] != '00000000' and f[2].isdigit():
            d[f[7]] = (int(f[1], 16) & ~1, int(f[2]))
    return d
def bls(buf, start, size):
    out = []; i = start
    while i < start + size - 2:
        hi = struct.unpack('<H', buf[i:i + 2])[0]
        if (hi & 0xf800) == 0xf000 and i + 4 <= start + size:
            lo = struct.unpack('<H', buf[i + 2:i + 4])[0]
            if (lo & 0xd000) in (0xd000, 0xc000):
                s = (hi >> 10) & 1; j1 = (lo >> 13) & 1; j2 = (lo >> 11) & 1
                i1 = ~(j1 ^ s) & 1; i2 = ~(j2 ^ s) & 1
                off = (s << 24) | (i1 << 23) | (i2 << 22) | ((hi & 0x3ff) << 12) | ((lo & 0x7ff) << 1)
                if s: off -= 1 << 25
                t = i + 4 + off
                if (lo & 0xd000) == 0xc000: t &= ~3
                out.append(t); i += 4; continue
        i += 2
    return out
a = open(A, 'rb').read(); b = open(B, 'rb').read()
sa, sb = syms(A), syms(B)
votes = {w: {} for w in want}
for n, (ad, sz) in sa.items():
    if n not in sb or sb[n][1] != sz: continue
    la, lb = bls(a, ad, sz), bls(b, sb[n][0], sz)
    if len(la) != len(lb): continue
    for x, y in zip(la, lb):
        if x in votes: votes[x][y] = votes[x].get(y, 0) + 1
for w in want:
    v = sorted(votes[w].items(), key=lambda kv: -kv[1])
    print(hex(w), '->', ', '.join('%s (%d calls)' % (hex(y), c) for y, c in v[:3]) or 'no caller matched')
