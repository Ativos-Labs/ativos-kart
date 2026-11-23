"""Leitura e escrita de arquivos .glb (glTF binário) sem dependências externas.

Usado por build_karts.py para trocar texturas, separar rodas e colar adesivos.
O Godot ignora esta pasta (tools/.gdignore).
"""
import json
import math
import struct

COMP_FMT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963


# --- Matrizes 4x4 (listas de linhas) -------------------------------------------

IDENTITY = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def quat_to_rows(q):
    x, y, z, w = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def node_local(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    r = quat_to_rows(n.get("rotation", [0, 0, 0, 1]))
    s = n.get("scale", [1, 1, 1])
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def xf_point(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


def xf_dir(m, d):
    return tuple(m[i][0] * d[0] + m[i][1] * d[1] + m[i][2] * d[2] for i in range(3))


# --- Vetores ----------------------------------------------------------------------

def sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def mul(a, s):
    return tuple(x * s for x in a)


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = math.sqrt(dot(a, a))
    return tuple(x / length for x in a) if length > 1e-12 else (0.0, 0.0, 0.0)


class Glb:
    def __init__(self, path):
        data = open(path, "rb").read()
        magic, _version, length = struct.unpack_from("<III", data, 0)
        assert magic == 0x46546C67, "não é um .glb"
        off = 12
        self.js = None
        binc = b""
        while off < length:
            clen, ctype = struct.unpack_from("<II", data, off)
            chunk = data[off + 8: off + 8 + clen]
            if ctype == 0x4E4F534A:
                self.js = json.loads(chunk)
            elif ctype == 0x004E4942:
                binc = chunk
            off += 8 + clen
        self.views = []
        for bv in self.js.get("bufferViews", []):
            start = bv.get("byteOffset", 0)
            self.views.append(bytes(binc[start: start + bv["byteLength"]]))

    # --- Buffers e accessors ------------------------------------------------------

    def add_view(self, data, target=None):
        bv = {"buffer": 0, "byteLength": len(data)}
        if target:
            bv["target"] = target
        self.js.setdefault("bufferViews", []).append(bv)
        self.views.append(bytes(data))
        return len(self.views) - 1

    def read_accessor(self, index, raw=False):
        """Valores do accessor (tuplas). Accessors esparsos (os shape keys que o Blender
        exporta: só os vértices que mexem) voltam completos, com zero no resto."""
        a = self.js["accessors"][index]
        if "bufferView" in a:
            out = self._read_dense(a, raw)
        else:
            zero = (0.0 if a["componentType"] == 5126 else 0,) * TYPE_N[a["type"]]
            out = [zero] * a["count"]
        sparse = a.get("sparse")
        if sparse:
            si = sparse["indices"]
            sv = sparse["values"]
            idx = self._unpack(si["bufferView"], si.get("byteOffset", 0), si["componentType"], 1, sparse["count"])
            vals = self._unpack(sv["bufferView"], sv.get("byteOffset", 0), a["componentType"], TYPE_N[a["type"]],
                                sparse["count"])
            out = list(out)
            for i, v in zip(idx, vals):
                out[i[0]] = v
        return out

    def _unpack(self, view, offset, component, n, count):
        fmt = COMP_FMT[component]
        size = struct.calcsize(fmt) * n
        data = self.views[view]
        return [struct.unpack_from("<" + fmt * n, data, offset + i * size) for i in range(count)]

    def _read_dense(self, a, raw=False):
        bv = self.js["bufferViews"][a["bufferView"]]
        raw = self.views[a["bufferView"]]
        n = TYPE_N[a["type"]]
        fmt = COMP_FMT[a["componentType"]]
        size = struct.calcsize(fmt)
        stride = bv.get("byteStride", size * n)
        base = a.get("byteOffset", 0)
        out = []
        for i in range(a["count"]):
            vals = struct.unpack_from("<" + fmt * n, raw, base + i * stride)
            if a.get("normalized") and not raw:
                if fmt == "B":
                    vals = tuple(v / 255.0 for v in vals)
                elif fmt == "H":
                    vals = tuple(v / 65535.0 for v in vals)
            out.append(vals)
        return out

    def add_accessor(self, values, acc_type, component=5126, target=ARRAY_BUFFER, minmax=False):
        n = TYPE_N[acc_type]
        fmt = COMP_FMT[component]
        flat = []
        for v in values:
            if n == 1 and not isinstance(v, (tuple, list)):
                v = (v,)
            flat.extend(v)
        data = struct.pack("<" + fmt * len(flat), *flat)
        view = self.add_view(data, target)
        acc = {"bufferView": view, "componentType": component, "count": len(values), "type": acc_type}
        if minmax and values:
            acc["min"] = [min(v[k] for v in values) for k in range(n)]
            acc["max"] = [max(v[k] for v in values) for k in range(n)]
        self.js["accessors"].append(acc)
        return len(self.js["accessors"]) - 1

    def add_indices(self, indices):
        return self.add_accessor(list(indices), "SCALAR", 5125, ELEMENT_ARRAY_BUFFER)

    # --- Imagens ------------------------------------------------------------------

    def image_bytes(self, index):
        return self.views[self.js["images"][index]["bufferView"]]

    def set_image(self, index, png_bytes):
        img = self.js["images"][index]
        img["bufferView"] = self.add_view(png_bytes)
        img["mimeType"] = "image/png"

    def add_texture(self, png_bytes, clamp=True):
        js = self.js
        view = self.add_view(png_bytes)
        js.setdefault("images", []).append({"bufferView": view, "mimeType": "image/png"})
        sampler = {"magFilter": 9729, "minFilter": 9987}
        if clamp:
            sampler["wrapS"] = 33071
            sampler["wrapT"] = 33071
        js.setdefault("samplers", []).append(sampler)
        js.setdefault("textures", []).append({"sampler": len(js["samplers"]) - 1, "source": len(js["images"]) - 1})
        return len(js["textures"]) - 1

    # --- Cena ---------------------------------------------------------------------

    def world_matrices(self):
        """Matriz de cada nó no espaço da cena."""
        nodes = self.js["nodes"]
        out = {}

        def walk(i, parent):
            m = matmul(parent, node_local(nodes[i]))
            out[i] = m
            for c in nodes[i].get("children", []):
                walk(c, m)

        for r in self.js["scenes"][0]["nodes"]:
            walk(r, IDENTITY)
        return out

    def find_node(self, name):
        for i, n in enumerate(self.js["nodes"]):
            if n.get("name") == name:
                return i
        raise KeyError(name)

    def prims_of_node(self, node_index):
        n = self.js["nodes"][node_index]
        if "mesh" not in n:
            return []
        return self.js["meshes"][n["mesh"]]["primitives"]

    def add_root_node(self, node):
        self.js["nodes"].append(node)
        index = len(self.js["nodes"]) - 1
        self.js["scenes"][0]["nodes"].append(index)
        return index

    # --- Gravação -----------------------------------------------------------------

    def save(self, path):
        js = self.js
        binc = bytearray()
        for i, data in enumerate(self.views):
            while len(binc) % 4:
                binc.append(0)
            js["bufferViews"][i]["byteOffset"] = len(binc)
            js["bufferViews"][i]["byteLength"] = len(data)
            binc.extend(data)
        while len(binc) % 4:
            binc.append(0)
        js["buffers"] = [{"byteLength": len(binc)}]
        j = json.dumps(js, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        while len(j) % 4:
            j += b" "
        total = 12 + 8 + len(j) + 8 + len(binc)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(j), 0x4E4F534A))
            f.write(j)
            f.write(struct.pack("<II", len(binc), 0x004E4942))
            f.write(binc)

    def compact(self):
        """Remove bufferViews, accessors, imagens e malhas que nada mais usa."""
        js = self.js
        used_meshes = sorted({n["mesh"] for n in js["nodes"] if "mesh" in n})
        mesh_map = {old: new for new, old in enumerate(used_meshes)}
        js["meshes"] = [js["meshes"][i] for i in used_meshes]
        for n in js["nodes"]:
            if "mesh" in n:
                n["mesh"] = mesh_map[n["mesh"]]
        used_acc = set()
        for m in js["meshes"]:
            for p in m["primitives"]:
                used_acc.update(p["attributes"].values())
                if "indices" in p:
                    used_acc.add(p["indices"])
                for t in p.get("targets", []):
                    used_acc.update(t.values())
        for s in js.get("skins", []):
            if "inverseBindMatrices" in s:
                used_acc.add(s["inverseBindMatrices"])
        for a in js.get("animations", []):
            for smp in a["samplers"]:
                used_acc.update((smp["input"], smp["output"]))
        acc_list = sorted(used_acc)
        acc_map = {old: new for new, old in enumerate(acc_list)}
        js["accessors"] = [js["accessors"][i] for i in acc_list]
        for m in js["meshes"]:
            for p in m["primitives"]:
                p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
                if "indices" in p:
                    p["indices"] = acc_map[p["indices"]]
                p["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in p.get("targets", [])]
                if not p["targets"]:
                    del p["targets"]
        for s in js.get("skins", []):
            if "inverseBindMatrices" in s:
                s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
        for a in js.get("animations", []):
            for smp in a["samplers"]:
                smp["input"] = acc_map[smp["input"]]
                smp["output"] = acc_map[smp["output"]]
        # Materiais / texturas / imagens usados.
        used_mat = sorted({p["material"] for m in js["meshes"] for p in m["primitives"] if "material" in p})
        mat_map = {old: new for new, old in enumerate(used_mat)}
        js["materials"] = [js["materials"][i] for i in used_mat]
        for m in js["meshes"]:
            for p in m["primitives"]:
                if "material" in p:
                    p["material"] = mat_map[p["material"]]
        used_tex = set()

        def collect(obj):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if k.endswith("Texture") and isinstance(v, dict) and "index" in v:
                        used_tex.add(v["index"])
                    collect(v)
            elif isinstance(obj, list):
                for v in obj:
                    collect(v)

        collect(js["materials"])
        tex_list = sorted(used_tex)
        tex_map = {old: new for new, old in enumerate(tex_list)}
        js["textures"] = [js["textures"][i] for i in tex_list] if js.get("textures") else []

        def remap(obj):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if k.endswith("Texture") and isinstance(v, dict) and "index" in v:
                        v["index"] = tex_map[v["index"]]
                    remap(v)
            elif isinstance(obj, list):
                for v in obj:
                    remap(v)

        remap(js["materials"])
        used_img = sorted({t["source"] for t in js["textures"]})
        img_map = {old: new for new, old in enumerate(used_img)}
        js["images"] = [js["images"][i] for i in used_img] if js.get("images") else []
        for t in js["textures"]:
            t["source"] = img_map[t["source"]]
        for key in ("textures", "images", "materials"):
            if not js.get(key):
                js.pop(key, None)
        # Regrava cada accessor num bufferView próprio e enxuto (os originais costumam
        # dividir um bloco grande, que ficaria inteiro no arquivo) e mantém só as imagens.
        index_accs = {p["indices"] for m in js["meshes"] for p in m["primitives"] if "indices" in p}
        views, bvs = [], []
        for ai, a in enumerate(js["accessors"]):
            if a.get("sparse") is not None:
                # Esparso (shape keys): continua esparso, só com os valores que não são zero.
                vals = self.read_accessor(ai, raw=True)
                fmt = COMP_FMT[a["componentType"]]
                nz = [i for i, v in enumerate(vals) if any(x != 0 for x in v)]
                a.pop("bufferView", None)
                a.pop("byteOffset", None)
                a.pop("sparse")
                if nz:
                    idx_data = struct.pack("<%dI" % len(nz), *nz)
                    flat = [x for i in nz for x in vals[i]]
                    val_data = struct.pack("<" + fmt * len(flat), *flat)
                    a["sparse"] = {"count": len(nz),
                                   "indices": {"bufferView": len(views), "componentType": 5125},
                                   "values": {"bufferView": len(views) + 1}}
                    views += [idx_data, val_data]
                    bvs += [{"buffer": 0, "byteLength": len(idx_data)}, {"buffer": 0, "byteLength": len(val_data)}]
                continue
            if "bufferView" not in a:
                continue
            vals = self.read_accessor(ai, raw=True)
            fmt = COMP_FMT[a["componentType"]]
            flat = [x for v in vals for x in v]
            data = struct.pack("<" + fmt * len(flat), *flat)
            # Cada elemento de vértice precisa começar em múltiplo de 4 bytes.
            elem = struct.calcsize(fmt) * TYPE_N[a["type"]]
            bv = {"buffer": 0, "byteLength": len(data)}
            if a.get("sparse") is None:
                if ai in index_accs:
                    bv["target"] = ELEMENT_ARRAY_BUFFER
                elif elem % 4 == 0:
                    bv["target"] = ARRAY_BUFFER
            a["bufferView"] = len(views)
            a.pop("byteOffset", None)
            views.append(data)
            bvs.append(bv)
        for img in js.get("images", []):
            if "bufferView" in img:
                old = img["bufferView"]
                img["bufferView"] = len(views)
                views.append(self.views[old])
                bvs.append({"buffer": 0, "byteLength": len(self.views[old])})
        js["bufferViews"] = bvs
        self.views = views


def triangles(glb, prim):
    """Lista de índices (a, b, c) dos triângulos de uma primitiva."""
    if "indices" in prim:
        idx = [v[0] for v in glb.read_accessor(prim["indices"])]
    else:
        count = glb.js["accessors"][prim["attributes"]["POSITION"]]["count"]
        idx = list(range(count))
    return [tuple(idx[t: t + 3]) for t in range(0, len(idx) - 2, 3)]
