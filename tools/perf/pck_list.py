"""Lista os arquivos de um .pck do Godot 4 por tamanho. Uso: python3 -I pck_list.py <pck> [top]"""
import struct
import sys
from collections import defaultdict

path = sys.argv[1]
top = int(sys.argv[2]) if len(sys.argv) > 2 else 40
with open(path, "rb") as f:
    assert f.read(4) == b"GDPC"
    pack_ver, vmaj, vmin, vpat, flags = struct.unpack("<5I", f.read(20))
    file_base = struct.unpack("<Q", f.read(8))[0]
    if pack_ver >= 3:
        dir_off = struct.unpack("<Q", f.read(8))[0]
        f.read(16 * 4)
        f.seek(dir_off)
    else:
        f.read(16 * 4)
    count = struct.unpack("<I", f.read(4))[0]
    rows = []
    for _ in range(count):
        n = struct.unpack("<I", f.read(4))[0]
        name = f.read(n).rstrip(b"\0").decode()
        off, size = struct.unpack("<QQ", f.read(16))
        f.read(16)
        fflags = struct.unpack("<I", f.read(4))[0]
        rows.append((size, name))
rows.sort(reverse=True)
total = sum(s for s, _ in rows)
print(f"pck v{pack_ver} godot {vmaj}.{vmin}.{vpat}: {count} arquivos, {total / 1e6:.1f} MB")
for s, n in rows[:top]:
    print(f"{s / 1e6:8.2f} MB  {n}")
groups = defaultdict(int)
for s, n in rows:
    ext = n.rsplit(".", 1)[-1]
    groups[ext] += s
print("por extensão:", {k: round(v / 1e6, 2) for k, v in sorted(groups.items(), key=lambda x: -x[1])})
