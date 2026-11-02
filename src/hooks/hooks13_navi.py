import shutil, os
SRC = '/work/build/navi'
B = '/work/build/navi13/'
if os.path.exists(B):
    shutil.rmtree(B)
shutil.copytree(SRC, B)
M = 'Lcom/mnsoft/navi/LeafiaTbtMute;'

p = B + 'com/mnsoft/navi/LeafiaTbtMute.smali'
s = open(p).read()
assert 'logFrame' not in s
s = s.replace('.field private static sMuted:Z', '''.field private static sMuted:Z

# G70 diagnostic: the last turn-list frame logged
.field private static sLastFrame:Ljava/lang/String;''', 1)
s += '''
# G70 diagnostic: log the navigation's own turn-list frames (sendClusterData type
# 0x66 -> updateTPTurnListNew) as hex when they change, so the HUD street line can be
# matched for Android Auto. Logging only: nothing sent changes.
.method public static logFrame(I[B)V
    .locals 6

    const/16 v0, 0x66
    if-ne p0, v0, :cond_ret
    if-eqz p1, :cond_ret

    :try_start
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    array-length v2, p1
    const/4 v3, 0x0

    :goto_loop
    if-ge v3, v2, :cond_done
    aget-byte v4, p1, v3
    and-int/lit16 v4, v4, 0xff
    or-int/lit16 v4, v4, 0x100
    invoke-static {v4}, Ljava/lang/Integer;->toHexString(I)Ljava/lang/String;
    move-result-object v5
    const/4 v4, 0x1
    invoke-virtual {v5, v4}, Ljava/lang/String;->substring(I)Ljava/lang/String;
    move-result-object v5
    invoke-virtual {v1, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    add-int/lit8 v3, v3, 0x1
    goto :goto_loop

    :cond_done
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    sget-object v2, ''' + M + '''->sLastFrame:Ljava/lang/String;
    invoke-virtual {v1, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v2
    if-nez v2, :cond_ret
    sput-object v1, ''' + M + '''->sLastFrame:Ljava/lang/String;

    new-instance v3, Ljava/lang/StringBuilder;
    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V
    const-string v4, "Leafia: navigation turn list frame "
    invoke-virtual {v3, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v3
    const-string v2, "LeafiaTBT"
    invoke-static {v2, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :cond_ret

    :cond_ret
    return-void
.end method
'''
open(p, 'w').write(s)

p = B + 'com/mnsoft/navi/e/a.smali'
s = open(p).read()
old = '''    invoke-static {p0}, ''' + M + '''->dropClusterData(I)Z
'''
assert s.count(old) == 1
s = s.replace(old, '''    # G70 diagnostic: log every cluster message the navigation sends (before the mute)
    invoke-static/range {p0 .. p4}, Lcom/mnsoft/navi/LeafiaNavLog;->logData(I[I[D[Ljava/lang/String;[B)V

''' + old)
open(p, 'w').write(s)
print('ok')
