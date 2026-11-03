import sys
# update 19 DiPO: run after hooks16_dipo.py on the update 19 tree (argument: the tree, e.g. /work/build/dipo18)
B = (sys.argv[1] if len(sys.argv) > 1 else '/work/build/dipo18') + '/com/daudio/app/dipo/'

# DiPO's maneuver parser (e/u.d, analyze_ManeuverUpdate) has GetComponentIdsFromManeuverMsg inlined:
# it reads the maneuver index into a CLONE of maneuverIndex[] and then checks the original, which is
# still -1, so every RouteGuidanceManeuverUpdate is dropped ("START maneuverIndex[0] = -1") and
# updateTBTInfo never finds the current maneuver. Write the index into the array itself.
p = B + 'e/u.smali'
s = open(p).read()
old = '''    :cond_92
    invoke-virtual {v5}, [I->clone()Ljava/lang/Object;

    move-result-object v0

    check-cast v0, [I

    move-object v1, p1
'''
new = '''    :cond_92
    # Leafia G70: the maneuver index goes into maneuverIndex[] itself, not a copy of it
    move-object v0, v5

    move-object v1, p1
'''
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new, 1)
open(p, 'w').write(s)
print('ok')
