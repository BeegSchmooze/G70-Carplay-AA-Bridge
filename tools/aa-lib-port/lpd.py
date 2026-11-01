import struct, zlib, sys, hashlib
d=open(sys.argv[1],'rb').read()
asz=struct.unpack('<I',d[4:8])[0]; bsz=struct.unpack('<I',d[24:28])[0]
print('src',hex(asz),d[8:24].hex(),'tgt',hex(bsz),d[28:44].hex())
comp,plen=struct.unpack('<II',d[44:52]); body=zlib.decompress(d[52:52+plen],-15)
n=struct.unpack('<I',body[:4])[0];p=4
ctrl=[struct.unpack('<iii',body[p+12*i:p+12*i+12]) for i in range(n)];p+=12*n
dl=struct.unpack('<I',body[p:p+4])[0];diff=body[p+4:p+4+dl];p+=4+dl
el=struct.unpack('<I',body[p:p+4])[0];extra=body[p+4:p+4+el]
print('ctrl',len(ctrl),'diff',dl,'extra',el)
op=dp=ep=0;np_=0
for x,y,z in ctrl:
    # report nonzero diff runs
    k=0
    while k<x:
        if diff[dp+k]:
            s=k
            while k<x and (diff[dp+k] or (k+1<x and diff[dp+k+1])): k+=1
            print(' diff@new %#x old %#x len %d'%(np_+s,op+s,k-s))
        k+=1
    op+=x;dp+=x;np_+=x
    if y: print(' extra@new %#x len %d'%(np_,y))
    np_+=y;ep+=y;op+=z
