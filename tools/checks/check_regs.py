#!/usr/bin/env python3
"""Rough Dalvik-verifier check on baksmali --register-info ALL,FULLMERGE output:
no instruction may read a register whose type before it is Conflicted or Uninit.

usage: check_regs.py <annotated.smali>... [--method NAME]
"""
import re, sys

STATE = re.compile(r'^\s*#([vp]\d+=\(.*)$')
REGS = re.compile(r'([vp]\d+)=\(([^,)]+)')


def read_regs(op, args):
    regs = re.findall(r'\b[vp]\d+\b', args.split(',')[0] if False else args)
    if op.startswith('invoke-'):
        m = re.search(r'\{([^}]*)\}', args)
        if not m:
            return []
        inner = m.group(1)
        r = re.match(r'\s*([vp])(\d+)\s*\.\.\s*([vp])(\d+)', inner)
        if r:
            return ['%s%d' % (r.group(1), i) for i in range(int(r.group(2)), int(r.group(4)) + 1)]
        return re.findall(r'[vp]\d+', inner)
    if op.startswith(('if-', 'packed-switch', 'sparse-switch', 'return', 'check-cast', 'monitor-',
                      'throw', 'iput', 'aput', 'sput', 'fill-array-data')):
        return regs
    if op.startswith(('iget', 'aget', 'array-length', 'move', 'add-', 'sub-', 'mul-', 'div-', 'rem-',
                      'and-', 'or-', 'xor-', 'shl-', 'shr-', 'ushr-', 'int-to', 'long-to', 'neg-',
                      'not-', 'new-array', 'instance-of', 'cmp')):
        if op.startswith(('move-result', 'move-exception')):
            return []
        if op.endswith('/2addr'):
            return regs
        return regs[1:]
    return []


def main():
    files = sys.argv[1:]
    only = None
    if '--method' in files:
        i = files.index('--method')
        only = files[i + 1]
        files = files[:i] + files[i + 2:]
    bad = 0
    for f in files:
        state = {}
        method = None
        fresh = True   # next state comment starts a new state (after an instruction)
        for n, l in enumerate(open(f, encoding='utf-8'), 1):
            s = l.strip()
            if s.startswith('.method'):
                method = s
                state = {}
                continue
            m = STATE.match(l)
            if m:
                regs = dict(re.findall(r'(?:^|;)([vp]\d+)=\(([^,):]+)', m.group(1)))
                if fresh:
                    state = regs
                    fresh = False
                else:
                    state.update(regs)
                continue
            if s.startswith(':') or not s:
                continue
            if not s or s.startswith(('.', ':', '#')):
                continue
            if only and only not in (method or ''):
                continue
            fresh = True
            op, _, args = s.partition(' ')
            for r in read_regs(op, args):
                t = state.get(r)
                if t in ('Conflicted', 'Uninit', None):
                    print('%s:%d %s reads %s=%s   [%s]' % (f.split('/')[-1], n, op, r, t, method))
                    bad += 1
    print('%d problems' % bad)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
