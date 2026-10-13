#!/usr/bin/env python3
"""Converts Flight Timer Classic's flight times into Core/FlightData.lua.

Flight Timer Classic by timohausmann, https://github.com/timohausmann/FlightTimerClassic,
is licensed CC BY 2.0 (https://creativecommons.org/licenses/by/2.0/), so its data
may be shipped with attribution.  Usage:

    python3 tools/flight/convert_ftc.py path/to/FlightTimerClassic/Data.lua .

FTC keys a flight master by the x coordinate TaxiNodePosition gives on the
flight map, as floor(x * 1e8).  The output keeps those keys:
    ns.flightData[faction][from] = { to1, seconds1, to2, seconds2, ... }
"""
import os
import re
import sys

HEADER = '''--[[
 WowTyrian2k flight times, converted by tools/flight/convert_ftc.py.

 Data from Flight Timer Classic by timohausmann
 (https://github.com/timohausmann/FlightTimerClassic, commit %s),
 licensed under Creative Commons Attribution 2.0
 (https://creativecommons.org/licenses/by/2.0/).  Changes: reformatted as a
 Lua table; the times themselves are unchanged.

 ns.flightData[faction][from] = { to, seconds, to, seconds, ... } where a
 flight master is floor(x * 1e8) of its TaxiNodePosition x coordinate.
]]
local _, ns = ...
ns.flightData = {'''


def parse(path):
    s = open(path).read()
    out = {}
    for fac in ('Alliance', 'Horde'):
        i = s.find(fac + ' = {')
        if i < 0:
            continue
        j = s.find('\n  },', i)
        blk = s[i:j] if j > 0 else s[i:]
        routes = out.setdefault(fac, {})
        for m in re.finditer(r"\['(\d+)'\] = \{(.*?)\}", blk, re.S):
            dst = [(int(a), int(b)) for a, b in re.findall(r"\['(\d+)'\] = (\d+)", m.group(2))]
            routes[int(m.group(1))] = sorted(dst)
    return out


def main():
    src, addon = sys.argv[1], sys.argv[2]
    commit = sys.argv[3] if len(sys.argv) > 3 else 'unknown'
    data = parse(src)
    lines = [HEADER % commit]
    n = 0
    for fac in sorted(data):
        lines.append('\t%s = {' % fac)
        for frm in sorted(data[fac]):
            lst = data[fac][frm]
            n += len(lst)
            lines.append('\t\t[%d] = { %s },' % (frm, ', '.join('%d, %d' % p for p in lst)))
        lines.append('\t},')
    lines.append('}')
    path = os.path.join(addon, 'Core', 'FlightData.lua')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print('wrote %s: %d routes' % (path, n))


if __name__ == '__main__':
    main()
