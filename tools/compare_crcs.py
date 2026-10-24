"""Compare stock-module imported CRCs against a built Module.symvers."""
import json, sys

stock = {k: int(v, 16) if isinstance(v, str) else v for k, v in json.load(open(sys.argv[1])).items()}
built = {}
for line in open(sys.argv[2]):
    crc, sym, mod, *_ = line.split('\t')
    built[sym] = (int(crc, 16), mod)

match = [s for s in stock if s in built and built[s][0] == stock[s]]
mismatch = [s for s in stock if s in built and built[s][0] != stock[s]]
missing = [s for s in stock if s not in built]
print(f"stock={len(stock)} match={len(match)} mismatch={len(mismatch)} missing={len(missing)}")
for s in mismatch:
    print(f"MISMATCH {s} stock={stock[s]:#010x} built={built[s][0]:#010x} ({built[s][1]})")
for s in missing:
    print(f"MISSING {s} stock={stock[s]:#010x}")
