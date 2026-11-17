"""Resume um log do probe. Uso: python3 -I report.py <log> [<log2> ...]"""
import re
import sys

for path in sys.argv[1:]:
    print(f"===== {path}")
    stalls = []
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = raw.strip()
        m = re.match(r"\[([\d.]+)\] (.*)", line)
        if not m:
            continue
        t, body = m.groups()
        if "PERF|" not in body:
            if any(k in body for k in ("ERROR", "EXC", "CRASH", "TIMEOUT", "END", "cpu throttle", "navigated")):
                print(f"  {t:>6}s {body[:200]}")
            continue
        body = body.split("PERF|", 1)[1]
        parts = body.split("|")
        kind = parts[0]
        if kind == "STALL":
            stalls.append((parts[1], float(parts[2])))
        elif kind == "INFO":
            print("  " + " | ".join(parts[1:]))
        elif kind == "M":
            label = parts[1]
            rest = parts[2:]
            if len(rest) and "=" not in rest[0]:
                label += "/" + rest[0]
                rest = rest[1:]
            if "base_after" in label:
                continue
            kv = dict(p.split("=") for p in rest)
            print(f"  M  {label:<28} fps={float(kv['fps']):6.1f} p50={float(kv['p50']):6.2f} p95={float(kv['p95']):6.2f} "
                  f"p99={float(kv['p99']):6.2f} max={float(kv['max']):7.1f} proc={float(kv['proc']):5.2f} "
                  f"phys={float(kv['phys']):5.2f} dc={kv['dc']:>5} obj={kv['obj']:>5} prim={int(kv['prim']) // 1000:>5}k")
        elif kind == "AB":
            kv = dict(p.split("=", 1) if "=" in p else (p, "") for p in parts[3:])
            dc = [p for p in parts if p.startswith("dc ")]
            print(f"  AB {parts[1]:<6} {parts[2]:<14} base={float(kv['base_ms']):6.2f} var={float(kv['var_ms']):6.2f} "
                  f"saved={float(kv['saved_ms']):6.2f} ms  {dc[0] if dc else ''}")
        elif kind == "LOAD":
            print(f"  LOAD {parts[1]:<22} {parts[2]:<20} {parts[3]:<14} {parts[4]}")
        elif kind == "CPU":
            print(f"  CPU {parts[1]:<7} {parts[2]:<24} {' | '.join(parts[3:])}")
        elif kind == "DONE":
            print("  DONE")
    by_phase = {}
    for ph, ms in stalls:
        by_phase.setdefault(ph, []).append(ms)
    print("  STALLS (>80 ms) por fase:")
    for ph, v in by_phase.items():
        print(f"    {ph:<24} n={len(v):>2} total={sum(v):7.0f} ms  max={max(v):6.0f}  {[int(x) for x in v][:12]}")
