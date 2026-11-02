import os, shutil
# update 14 GPM: update 13's tree (build/gpm13) with the new leafia classes (copied in by
# the build) and the stale wireless session restart (LeafiaAaRestart) hooked into
# WirelessExplorer.startRfcommNego.
B = '/work/build/gpm14/'
if os.path.exists(B):
    shutil.rmtree(B)
shutil.copytree('/work/build/gpm13', B)

p = B + 'com/google/android/projection/protocol/WirelessExplorer.smali'
s = open(p).read()
old = '''    const-string v1, "==> Wireless AA connection sequence is over Start, not re-init!"

    invoke-static {v0, v1}, Lcom/google/android/projection/sink/c/k;->d(Ljava/lang/String;Ljava/lang/String;)V
'''
assert s.count(old) == 1, 'startRfcommNego text'
s = s.replace(old, old + '''
    # Leafia G70: the same phone starting again while its session is still up means
    # that session is dead (the phone walked away): end it, the phone's retry starts anew
    iget-object v0, p0, Lcom/google/android/projection/protocol/WirelessExplorer;->mService:Lcom/google/android/projection/service/GalReceiverService;

    invoke-static {v0, p1}, Lcom/google/android/projection/service/LeafiaAaRestart;->staleStart(Lcom/google/android/projection/service/GalReceiverService;Landroid/bluetooth/BluetoothDevice;)V
''')
open(p, 'w').write(s)
print('ok')
