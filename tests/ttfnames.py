"""Extract TTF name-table family/full names (nameID 1/4/16). Stdlib only.
Usage: ttfnames.py <file.ttf> -> prints 'path|nameID|text' lines (en records only).
"""
import struct
import sys


def families(path):
    with open(path, 'rb') as f:
        data = f.read()
    num_tables = struct.unpack('>H', data[4:6])[0]
    name_off = None
    for i in range(num_tables):
        tag, _, off, _ln = struct.unpack('>4sIII', data[12 + i * 16:28 + i * 16])
        if tag == b'name':
            name_off = off
    if name_off is None:
        return
    count, storage = struct.unpack('>HH', data[name_off + 2:name_off + 6])
    for i in range(count):
        plat, _enc, lang, nid, slen, soff = struct.unpack(
            '>HHHHHH', data[name_off + 6 + i * 12:name_off + 18 + i * 12])
        if nid not in (1, 4, 16):
            continue
        raw = data[name_off + storage + soff:name_off + storage + soff + slen]
        try:
            text = raw.decode('utf-16-be')
        except Exception:
            continue
        if plat == 3 and lang != 0x409:
            continue
        print(f'{path}|{nid}|{text}')


if __name__ == '__main__':
    for p in sys.argv[1:]:
        families(p)
