"""Check that built modules can resolve every import against the stock kernel's export CRCs.

Usage: check_imports.py STOCK_VMLINUX_CRCS.json DIR_WITH_versions_AND_vermagic
Each module X.ko must have X.versions (raw __versions section) and X.modinfo (raw .modinfo)
extracted beside it. An import passes if the stock kernel exports it with the same CRC, or if
another module in the set exports it (per Module.symvers given as argv[3]).
"""
import json, pathlib, struct, sys

stock = {k: int(v, 16) for k, v in json.load(open(sys.argv[1])).items()}
moddir = pathlib.Path(sys.argv[2])
ours = {}
for line in open(sys.argv[3]):
    crc, sym, mod, *_ = line.rstrip('\n').split('\t')
    if mod != 'vmlinux':
        ours[sym] = (int(crc, 16), pathlib.Path(mod).name)

STOCK_VERMAGIC = '4.9.77-lab126 SMP preempt mod_unload modversions ARMv7 p2v8 '
ok = True
for ko in sorted(moddir.glob('*.ko')):
    raw = ko.with_suffix('.versions').read_bytes()
    imports = {}
    for off in range(0, len(raw), 64):
        crc, name = struct.unpack_from('<I60s', raw, off)
        imports[name.split(b'\0')[0].decode()] = crc
    info = dict(kv.split('=', 1) for kv in ko.with_suffix('.modinfo').read_bytes().decode().split('\0') if '=' in kv)
    bad = []
    for sym, crc in imports.items():
        if stock.get(sym) == crc:
            continue
        if sym in ours and ours[sym][0] == crc and ours[sym][1] != ko.stem:
            continue
        where = f'stock={stock[sym]:#010x}' if sym in stock else ('ours' if sym in ours else 'nowhere')
        bad.append(f'{sym} crc={crc:#010x} {where}')
    vm = info.get('vermagic')
    print(f'{ko.name}: imports={len(imports)} unresolved={len(bad)} vermagic_ok={vm == STOCK_VERMAGIC} depends={info.get("depends")!r}')
    for b in bad:
        print('   ', b)
    ok &= not bad and vm == STOCK_VERMAGIC
sys.exit(0 if ok else 1)
