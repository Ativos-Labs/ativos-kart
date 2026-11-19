"""Gera assets/models/moeda/moeda.glb (a moeda Ativos do jogo) a partir do modelo
original em tools/moeda/original/MOEDA.glb.

O original tem 2,4 MB, quase tudo em três texturas 2048x2048: cor, mapa de normais
(quase liso, só riscos finos) e rugosidade/metal (uma cor só). Na pista a moeda fica
com uns 100 px na tela, então:
- a textura de cor vira um JPEG de 512x512;
- o mapa de normais e o de rugosidade/metal saem (o brilho é constante no shader);
- a malha é centralizada (origem no meio da moeda, em pé, de frente para +Z), para
  ela girar no próprio eixo no shader (shaders/coin.gdshader);
- o "$" em relevo do verso é aplainado (o miolo dentro do anel vira um disco liso):
  ali o shader grava o "%" da Correção monetária.

Uso: python3 tools/moeda/build_moeda.py   (precisa do Pillow)
O Godot ignora esta pasta (tools/.gdignore).
"""
import io
import json
import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "original", "MOEDA.glb")
DST = os.path.join(HERE, "..", "..", "assets", "models", "moeda", "moeda.glb")
TEXTURE_SIZE = 512
JPEG_QUALITY = 88
# Verso (-Z, depois de centralizar): o fundo liso fica em z = BACK_FIELD_Z e o "$" sobe
# até -0,135; o anel começa em r ~0,33. Tudo dentro de FLAT_RADIUS vira o fundo liso.
FLAT_RADIUS = 0.325
BACK_FIELD_Z = -0.06


def read_glb(path):
    data = open(path, "rb").read()
    magic, _version, _length = struct.unpack("<III", data[:12])
    assert magic == 0x46546C67, "não é um .glb"
    off = 12
    chunks = []
    while off < len(data):
        size, kind = struct.unpack("<II", data[off:off + 8])
        chunks.append(data[off + 8:off + 8 + size])
        off += 8 + size
    return json.loads(chunks[0]), chunks[1]


def view_bytes(gltf, binary, view_index):
    view = gltf["bufferViews"][view_index]
    start = view.get("byteOffset", 0)
    return binary[start:start + view["byteLength"]]


def accessor_floats(gltf, binary, index, n):
    acc = gltf["accessors"][index]
    assert acc["componentType"] == 5126
    raw = view_bytes(gltf, binary, acc["bufferView"])
    count = acc["count"]
    values = struct.unpack("<%df" % (count * n), raw[:count * n * 4])
    return [values[i * n:(i + 1) * n] for i in range(count)]


def accessor_indices(gltf, binary, index):
    acc = gltf["accessors"][index]
    fmt = {5121: "B", 5123: "H", 5125: "I"}[acc["componentType"]]
    size = struct.calcsize(fmt)
    raw = view_bytes(gltf, binary, acc["bufferView"])
    return list(struct.unpack("<%d%s" % (acc["count"], fmt), raw[:acc["count"] * size]))


def main():
    gltf, binary = read_glb(SRC)
    prim = gltf["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]
    positions = accessor_floats(gltf, binary, attrs["POSITION"], 3)
    normals = accessor_floats(gltf, binary, attrs["NORMAL"], 3)
    uvs = accessor_floats(gltf, binary, attrs["TEXCOORD_0"], 2)
    indices = accessor_indices(gltf, binary, prim["indices"])

    # Centraliza: o modelo vem com a base em y = 0 e um pouco deslocado em z.
    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]
    center = [(lo[i] + hi[i]) * 0.5 for i in range(3)]
    positions = [tuple(p[i] - center[i] for i in range(3)) for p in positions]
    new_lo = [lo[i] - center[i] for i in range(3)]
    new_hi = [hi[i] - center[i] for i in range(3)]

    # Verso: tira o "$" (o "%" é desenhado no shader, em cima do disco liso; lá o shader
    # também troca a textura por uma cor só, senão o desenho do "$" continuaria na cor).
    flat = 0
    for i, p in enumerate(positions):
        if p[2] < BACK_FIELD_Z + 0.02 and (p[0] * p[0] + p[1] * p[1]) ** 0.5 < FLAT_RADIUS:
            positions[i] = (p[0], p[1], BACK_FIELD_Z)
            normals[i] = (0.0, 0.0, -1.0)
            flat += 1

    material = gltf["materials"][prim["material"]]
    color_tex = gltf["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    image = gltf["images"][color_tex["source"]]
    color = Image.open(io.BytesIO(view_bytes(gltf, binary, image["bufferView"]))).convert("RGB")
    color = color.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
    jpeg = io.BytesIO()
    color.save(jpeg, "JPEG", quality=JPEG_QUALITY, optimize=True)
    jpeg = jpeg.getvalue()

    # --- Novo .glb ----------------------------------------------------------------
    blob = bytearray()
    views = []

    def add_view(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        blob.extend(data)
        views.append(view)
        return len(views) - 1

    accessors = []

    def add_vec(values, kind, minmax=False):
        n = len(values[0])
        data = struct.pack("<%df" % (len(values) * n), *[c for v in values for c in v])
        acc = {"bufferView": add_view(data, 34962), "componentType": 5126, "count": len(values), "type": kind}
        if minmax:
            acc["min"] = new_lo
            acc["max"] = new_hi
        accessors.append(acc)
        return len(accessors) - 1

    pos_acc = add_vec(positions, "VEC3", True)
    nrm_acc = add_vec(normals, "VEC3")
    uv_acc = add_vec(uvs, "VEC2")
    big = max(indices) > 65535
    idx_data = struct.pack("<%d%s" % (len(indices), "I" if big else "H"), *indices)
    accessors.append({"bufferView": add_view(idx_data, 34963), "componentType": 5125 if big else 5123,
                      "count": len(indices), "type": "SCALAR"})
    idx_acc = len(accessors) - 1
    img_view = add_view(jpeg)

    out = {
        "asset": {"version": "2.0", "generator": "Ativos Kart tools/moeda/build_moeda.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Moeda", "mesh": 0}],
        "meshes": [{"name": "Moeda", "primitives": [{
            "attributes": {"POSITION": pos_acc, "NORMAL": nrm_acc, "TEXCOORD_0": uv_acc},
            "indices": idx_acc, "material": 0}]}],
        "materials": [{"name": "Ouro", "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": 0.65, "roughnessFactor": 0.32}}],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987}],
        "images": [{"name": "moeda_cor", "mimeType": "image/jpeg", "bufferView": img_view}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    while len(blob) % 4:
        blob.append(0)
    out["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)
    print("verso aplainado: %d vértices" % flat)
    print("moeda.glb: %d triângulos, tamanho %.2f x %.2f x %.2f m, %d KB (original %d KB)" % (
        len(indices) // 3, new_hi[0] - new_lo[0], new_hi[1] - new_lo[1], new_hi[2] - new_lo[2],
        total // 1024, os.path.getsize(SRC) // 1024))


if __name__ == "__main__":
    main()
