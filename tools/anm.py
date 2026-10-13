import struct, sys
def decode_anm(path):
    d = open(path, 'rb').read()
    pageCount = struct.unpack_from('<H', d, 6)[0]
    recordCount = struct.unpack_from('<I', d, 8)[0]
    pal = []
    for i in range(256):
        b, g, r, _ = d[256 + i*4: 256 + i*4 + 4]
        pal.append((r, g, b))
    pal[0] = (0, 0, 0)
    pds = [struct.unpack_from('<HHH', d, 256 + 1024 + i*6) for i in range(256)]
    image = bytearray(64000)
    frames = []
    for record in range(0, recordCount - 1):
        for i in range(pageCount):
            first, cnt, size = pds[i]
            if first <= record < first + cnt:
                base = 0xB00 + (i << 16)
                sizes = struct.unpack_from('<%dH' % cnt, d, base + 8)
                off = base + 8 + 2 * cnt + sum(sizes[:record - first])
                rec = d[off: off + sizes[record - first]]
                break
        p = 4; w = 0
        while p < len(rec):
            op = rec[p]; p += 1
            if op == 0:
                n, v = rec[p], rec[p+1]; p += 2
                image[w:w+n] = bytes([v]) * n; w += n
            elif op > 0x80:
                w += op - 0x80
            elif op < 0x80:
                image[w:w+op] = rec[p:p+op]; p += op; w += op
            else:
                op2 = struct.unpack_from('<H', rec, p)[0]; p += 2
                if op2 == 0: break
                elif op2 >= 0xC000:
                    n = op2 - 0xC000; v = rec[p]; p += 1
                    image[w:w+n] = bytes([v]) * n; w += n
                elif op2 < 0x8000:
                    w += op2
                else:
                    n = op2 - 0x8000
                    image[w:w+n] = rec[p:p+n]; p += n; w += n
        frames.append(bytes(image[:64000]))
    return pal, frames
if __name__ == '__main__':
    pal, frames = decode_anm(sys.argv[1])
    print(len(frames), 'frames')
    uniq = len(set(frames)); print(uniq, 'unique')
