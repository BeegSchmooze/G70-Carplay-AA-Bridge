import os, sys
# Update 23 DiPO hooks: CarPlay lane guidance (LeafiaCpLane). In e/u (route guidance analyzer):
#   e(Object)       onLaneGuidanceInformation (only logs in stock): -> LeafiaCpLane.lanes(msg)
#   nS()            stopTurnByTurn                                 -> LeafiaCpLane.clear()
#   disconnected()                                                 -> LeafiaCpLane.clear()
# Each method is found by its signature and checked by its stock log string first, so a firmware
# where the names moved fails here instead of hooking the wrong method.
# usage: hooks20_dipo.py <DiPO smali tree>
tree = sys.argv[1]
p = os.path.join(tree, 'com/daudio/app/dipo/e/u.smali')
lines = open(p, encoding='utf-8').read().split('\n')
HOOKS = [
    ('.method public static e(Ljava/lang/Object;)V', 'onLaneGuidanceInformation obj is null',
     '    invoke-static {p0}, Lcom/daudio/app/dipo/LeafiaCpLane;->lanes(Ljava/lang/Object;)V'),
    ('.method public final nS()V', 'stopTurnByTurn()',
     '    invoke-static {}, Lcom/daudio/app/dipo/LeafiaCpLane;->clear()V'),
    ('.method public final disconnected()V', None,
     '    invoke-static {}, Lcom/daudio/app/dipo/LeafiaCpLane;->clear()V'),
]
for head, check, call in HOOKS:
    idx = [i for i, l in enumerate(lines) if l.strip() == head]
    assert len(idx) == 1, 'method not found once: ' + head
    i = idx[0]
    end = next(j for j in range(i, len(lines)) if lines[j].strip() == '.end method')
    body = '\n'.join(lines[i:end])
    if 'LeafiaCpLane' in body:
        print('already hooked:', head)
        continue
    if check:
        assert check in body, 'not the expected method (no "%s"): %s' % (check, head)
    # after the directives (.registers/.param/.annotation/.prologue), before the first instruction
    j = i + 1
    in_ann = False
    at = None
    while j < end:
        s = lines[j].strip()
        if in_ann:
            if s.startswith('.end annotation') or s.startswith('.end param'):
                in_ann = False
        elif s.startswith('.annotation'):
            in_ann = True
        elif s.startswith('.prologue'):
            at = j + 1
            break
        elif s and not s.startswith('.') and not s.startswith('#'):
            at = j
            break
        j += 1
    assert at is not None, 'no code in ' + head
    lines[at:at] = ['    # Leafia G70: CarPlay lane guidance on the cluster / HUD', call, '']
    print('hooked:', head)
open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
