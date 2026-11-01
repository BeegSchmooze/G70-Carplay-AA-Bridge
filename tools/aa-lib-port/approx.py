import struct,zlib,sys
d=open(sys.argv[1],'rb').read(); a=open(sys.argv[2],'rb').read()
comp,plen=struct.unpack('<II',d[44:52]); body=zlib.decompress(d[52:52+plen],-15)
n=struct.unpack('<I',body[:4])[0];p=4
ctrl=[struct.unpack('<iii',body[p+12*i:p+12*i+12]) for i in range(n)];p+=12*n
dl=struct.unpack('<I',body[p:p+4])[0];diff=body[p+4:p+4+dl];p+=4+dl
el=struct.unpack('<I',body[p:p+4])[0];extra=body[p+4:p+4+el]
out=bytearray();op=dp=ep=0
for x,y,z in ctrl:
    for k in range(x):
        v=diff[dp+k];o=op+k
        if 0<=o<len(a): v=(v+a[o])&255
        out.append(v)
    op+=x;dp+=x;out+=extra[ep:ep+y];ep+=y;op+=z
open(sys.argv[3],'wb').write(out)
