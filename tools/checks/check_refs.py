#!/usr/bin/env python3
"""Check that every class/method/field referenced from the given smali files
exists in the app tree or the car's deodexed framework.

usage: check_refs.py <app smali dir> <framework smali dir> <file.smali>...
"""
import os, re, sys

REF = re.compile(r'(L[\w/$]+;)->([\w$<>]+)(\([^)]*\)\S+|:\S+)')
TYPE = re.compile(r'\[*(L[\w/$]+;)')


def scan(root, defs, sup):
    for dp, _, fs in os.walk(root):
        for f in fs:
            if not f.endswith('.smali'):
                continue
            c = None
            m = set()
            for l in open(os.path.join(dp, f), encoding='utf-8', errors='replace'):
                s = l.strip()
                if s.startswith('.class'):
                    c = s.split()[-1]
                elif s.startswith('.super'):
                    sup[c] = s.split()[-1]
                elif s.startswith('.implements'):
                    sup.setdefault(c + '#i', []).append(s.split()[-1])
                elif s.startswith('.method'):
                    m.add(s.split()[-1])
                elif s.startswith('.field'):
                    m.add(s.split(' = ')[0].split()[-1])
            if c:
                defs.setdefault(c, set()).update(m)


def has(defs, sup, c, mem, d=0):
    if d > 40 or c not in defs:
        return False
    if mem in defs[c]:
        return True
    for p in [sup.get(c)] + sup.get(c + '#i', []):
        if p and has(defs, sup, p, mem, d + 1):
            return True
    return False


def main():
    app, fw, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    defs, sup = {}, {}
    scan(fw, defs, sup)
    scan(app, defs, sup)
    bad = set()
    for f in files:
        for n, l in enumerate(open(f, encoding='utf-8'), 1):
            s = l.strip()
            if not s or s.startswith('#'):
                continue
            for c, mem, sig in REF.findall(s):
                if c not in defs:
                    bad.add('%s:%d unknown class %s' % (os.path.basename(f), n, c))
                elif not has(defs, sup, c, mem + sig):
                    bad.add('%s:%d missing %s->%s%s' % (os.path.basename(f), n, c, mem, sig))
            for t in TYPE.findall(s.split('#')[0]):
                if t not in defs:
                    bad.add('%s:%d unknown type %s' % (os.path.basename(f), n, t))
    for b in sorted(bad):
        print(b)
    print('%d problems' % len(bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
