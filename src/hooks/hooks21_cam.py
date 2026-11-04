import sys
# Camera alerts: GPM starts LeafiaCam in GalReceiverService.onCreate; the car navigation's
# sendClusterData asks LeafiaNavCam first. argv: gpm tree, navi tree.
gpm, navi = sys.argv[1], sys.argv[2]

p = gpm + '/com/google/android/projection/service/GalReceiverService.smali'
s = open(p).read()
old = '''    invoke-super {p0}, Lcom/hkmc/app/HKMCService;->onCreate()V
'''
assert s.count(old) == 1, 'onCreate'
s = s.replace(old, old + '''
    # Leafia G70: speed / red-light camera alerts (GPS -> sys.leafia.cam)
    invoke-static {p0}, Lcom/google/android/projection/leafia/LeafiaCam;->start(Landroid/content/Context;)V
''')
open(p, 'w').write(s)

p = navi + '/com/mnsoft/navi/e/a.smali'
s = open(p).read()
old = '''    invoke-static/range {p0 .. p4}, Lcom/mnsoft/navi/LeafiaNavLog;->logData(I[I[D[Ljava/lang/String;[B)V
'''
assert s.count(old) == 1, 'sendClusterData'
s = s.replace(old, old + '''
    # Leafia G70: camera alerts (the camera put into trap frames, own distance held back)
    invoke-static {p0, p1}, Lcom/mnsoft/navi/LeafiaNavCam;->frame(I[I)Z

    move-result v1

    if-eqz v1, :cond_leafia_cam

    return-void

    :cond_leafia_cam
''')
open(p, 'w').write(s)
print('ok')
