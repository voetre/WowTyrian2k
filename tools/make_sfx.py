# Converts tyrian.snd / voices.snd to ogg at the channel volume levels the
# original mixer uses ((vol + 1) / 8, vol in {1, 2, 4}).
import struct, subprocess, os, sys
D = sys.argv[1]; OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
def load(fn, trim, base):
    d = open(os.path.join(D, fn), 'rb').read()
    n = struct.unpack_from('<H', d, 0)[0]
    pos = [struct.unpack_from('<I', d, 2 + 4 * i)[0] for i in range(n)] + [len(d)]
    for i in range(n):
        s = d[pos[i]:pos[i + 1]]
        if trim: s = s[:-100] if len(s) >= 100 else b''
        open('tmp.raw', 'wb').write(s)
        dur = max(0.01, len(s) / 11025.0)
        fo = max(0.0, dur - 0.006)
        for vol in (1, 2, 4):
            gain = (vol + 1) / 8 * 1.3
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's8', '-ar', '11025', '-ac', '1', '-i', 'tmp.raw',
                            '-af', 'highpass=f=20,volume=%.3f,afade=t=in:d=0.003,afade=t=out:st=%.4f:d=0.006' % (gain, fo),
                            '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4',
                            os.path.join(OUT, 'sfx%02d_v%d.ogg' % (base + i + 1, vol))], check=True)
load('tyrian.snd', False, 0); load('voices.snd', True, 29); os.remove('tmp.raw')
