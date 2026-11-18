"""Prepara o modelo de um piloto com textura (Jarbas, Henrique) para o jogo.

Lê o modelo original de tools/personagens/originais/ (exportado do Blender) e grava
assets/models/personagens/<nome>.glb:

- tira o volante e o guidão de referência (Ref_*) e os desenhos de controle (WGT_*);
- Henrique: o modelo veio sem esqueleto; o esqueleto e os pesos saem de
  henrique_esqueleto.json (gerado por rig_henrique.py, que precisa do Blender) e as
  cores de vértice e o segundo UV, que o jogo não usa, saem;
- tira do esqueleto os ossos sem peso nenhum (controles de IK do Blender, alvos do
  olhar, pontas dos dedos e dos pés) — no Godot eles não fazem nada e o CharacterRig
  percorre todos os ossos a cada quadro;
- renomeia os ossos "mixamorig:Xxx" para "Xxx";
- junta as texturas (as 27 da Tripo no Jarbas, a única do Henrique) e os logos num
  atlas só (2048 x 2048). As partes de cor lisa (olhos, boca, luvas, pálpebras)
  apontam para um quadradinho branco do atlas e mantêm a cor no material. Assim o
  CharacterMesh junta o piloto inteiro numa superfície só (na web cada superfície com
  esqueleto custa um passe de GPU por quadro). Mapas de normal, rugosidade e metal
  saem (o shader dos pilotos não usa);
- logos: transparência recortada (alpha scissor) em vez de mistura, para caberem na
  mesma superfície.

As animações do arquivo do Jarbas (expressões, piscada, POSE_Kart, POSE_Moto) vão
junto. As que o jogo usa são montadas no Godot por gerar_animacoes.gd (veja o README
desta pasta); as do Henrique saem das do Jarbas.

Uso: python3 tools/personagens/build_personagem.py jarbas|henrique
"""
import io
import json
import math
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageMath

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "karts"))
from gltf_util import Glb  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
CHARACTERS = {
    "jarbas": {"src": "jarbas-piloto.glb", "skeleton": None, "root": None},
    "henrique": {"src": "henrique-piloto.glb", "skeleton": "henrique_esqueleto.json", "root": "Henrique"},
}

ATLAS = 2048
PAD = 6  # pixels entre retângulos no atlas (já na escala final)
WHITE = 8  # lado do quadradinho branco das cores lisas
DROP_NODES = ("Ref_Guidao_Moto", "Ref_Volante_Kart", "WGT_Circulo", "WGT_Olhar_Alvo")
KEEP_UNWEIGHTED = ("Raiz",)  # raiz do esqueleto (pai do quadril)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in CHARACTERS:
        raise SystemExit("uso: python3 tools/personagens/build_personagem.py %s" % "|".join(CHARACTERS))
    name = sys.argv[1]
    cfg = CHARACTERS[name]
    src = os.path.join(HERE, "originais", cfg["src"])
    dst = os.path.join(PROJ, "assets", "models", "personagens", name + ".glb")
    g = Glb(src)
    js = g.js
    drop = DROP_NODES + ((cfg["root"],) if cfg["root"] else ())
    _drop_scene_nodes(g, drop)
    if cfg["skeleton"]:
        with open(os.path.join(HERE, cfg["skeleton"])) as f:
            _add_skeleton(g, json.load(f), cfg["root"])
    _clean_skeleton(g)
    _rename_bones(js)
    _build_atlas(g)
    js["asset"]["generator"] = "Ativos Kart build_personagem.py (de: %s)" % js["asset"].get("generator", "")
    js.pop("extensionsUsed", None)
    g.compact()
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    g.save(dst)
    print("gravado", os.path.relpath(dst, PROJ), "%.1f MB" % (os.path.getsize(dst) / 1e6))


# --- Nós e esqueleto ------------------------------------------------------------------

def _reindex_nodes(g, keep):
    """Mantém só os nós de `keep` (índices antigos) e corrige todas as referências."""
    js = g.js
    keep = sorted(keep)
    new_index = {old: new for new, old in enumerate(keep)}
    nodes = []
    for old in keep:
        n = dict(js["nodes"][old])
        if "children" in n:
            n["children"] = [new_index[c] for c in n["children"] if c in new_index]
            if not n["children"]:
                del n["children"]
        nodes.append(n)
    js["nodes"] = nodes
    for scene in js["scenes"]:
        scene["nodes"] = [new_index[r] for r in scene["nodes"] if r in new_index]
    for skin in js.get("skins", []):
        skin["joints"] = [new_index[j] for j in skin["joints"]]
        if "skeleton" in skin:
            skin["skeleton"] = new_index[skin["skeleton"]]
    for anim in js.get("animations", []):
        channels = []
        used_samplers = []
        for ch in anim["channels"]:
            node = ch["target"].get("node")
            if node in new_index:
                ch["target"]["node"] = new_index[node]
                channels.append(ch)
                used_samplers.append(ch["sampler"])
        sampler_map = {}
        samplers = []
        for s in used_samplers:
            if s not in sampler_map:
                sampler_map[s] = len(samplers)
                samplers.append(anim["samplers"][s])
        for ch in channels:
            ch["sampler"] = sampler_map[ch["sampler"]]
        anim["channels"] = channels
        anim["samplers"] = samplers


def _subtree(js, root):
    out = [root]
    for c in js["nodes"][root].get("children", []):
        out += _subtree(js, c)
    return out


def _drop_scene_nodes(g, names):
    js = g.js
    drop = set()
    for i, n in enumerate(js["nodes"]):
        if n.get("name") in names:
            drop.update(_subtree(js, i))
    _reindex_nodes(g, [i for i in range(len(js["nodes"])) if i not in drop])


def _add_skeleton(g, data, root_name):
    """Esqueleto e pesos de rig_henrique.py: nós dos ossos, skin e JOINTS_0/WEIGHTS_0
    em cada primitiva. Fica como o do Jarbas: <root> > Armature > (malhas, Raiz > ossos)."""
    js = g.js
    meshes = {n["name"]: i for i, n in enumerate(js["nodes"]) if "mesh" in n}
    missing = set(data["meshes"]) ^ set(meshes)
    if missing:
        raise SystemExit("malhas diferentes entre o modelo e o esqueleto: %s" % sorted(missing))
    first = len(js["nodes"])
    bones = data["bones"]
    for b in bones:
        js["nodes"].append({"name": b["name"], "translation": b["translation"], "rotation": b["rotation"]})
    for k, b in enumerate(bones):
        if b["parent"] >= 0:
            js["nodes"][first + b["parent"]].setdefault("children", []).append(first + k)
    roots = [first + k for k, b in enumerate(bones) if b["parent"] < 0]
    armature = len(js["nodes"])
    js["nodes"].append({"name": "Armature", "children": sorted(meshes.values()) + roots})
    js["nodes"].append({"name": root_name, "children": [armature]})
    js["scenes"][0]["nodes"] = [armature + 1]
    # Matrizes inversas de ligação: as malhas ficam na origem, então é a inversa da
    # transformação de cada osso (giro e translação, sem escala).
    world = g.world_matrices()
    ibm = []
    for k in range(len(bones)):
        m = world[first + k]
        r = [[m[i][j] for j in range(3)] for i in range(3)]
        t = [m[i][3] for i in range(3)]
        rt = [[r[j][i] for j in range(3)] for i in range(3)]
        tt = [-sum(rt[i][j] * t[j] for j in range(3)) for i in range(3)]
        inv = [rt[0] + [tt[0]], rt[1] + [tt[1]], rt[2] + [tt[2]], [0.0, 0.0, 0.0, 1.0]]
        ibm.append(tuple(inv[row][col] for col in range(4) for row in range(4)))
    js.setdefault("skins", []).append({"name": "Armature", "joints": list(range(first, first + len(bones))),
                                       "inverseBindMatrices": g.add_accessor(ibm, "MAT4", target=None)})
    skin = len(js["skins"]) - 1
    for name, node in meshes.items():
        js["nodes"][node]["skin"] = skin
        prims = js["meshes"][js["nodes"][node]["mesh"]]["primitives"]
        for p, w in zip(prims, data["meshes"][name]):
            count = js["accessors"][p["attributes"]["POSITION"]]["count"]
            if count != w["count"]:
                raise SystemExit("%s: %d vértices no modelo, %d no esqueleto" % (name, count, w["count"]))
            J = w["joints"]
            W = w["weights_1e4"]
            joints = [tuple(J[i * 4:i * 4 + 4]) for i in range(count)]
            weights = []
            for i in range(count):
                q = W[i * 4:i * 4 + 4]
                total = float(sum(q)) or 1.0
                weights.append(tuple(v / total for v in q))
            p["attributes"]["JOINTS_0"] = g.add_accessor(joints, "VEC4", component=5123)
            p["attributes"]["WEIGHTS_0"] = g.add_accessor(weights, "VEC4")
            # O jogo não usa cor de vértice nem o segundo UV.
            for attr in ("COLOR_0", "COLOR_1", "TEXCOORD_1"):
                p["attributes"].pop(attr, None)
    print("esqueleto: %d ossos, %d malhas com pesos" % (len(bones), len(meshes)))


def _clean_skeleton(g):
    """Tira do skin (e da cena) os ossos sem peso, remapeando JOINTS_0."""
    js = g.js
    skin = js["skins"][0]
    joints = skin["joints"]
    weighted = set()
    prims = []
    for m in js["meshes"]:
        for p in m["primitives"]:
            if "JOINTS_0" in p["attributes"]:
                J = g.read_accessor(p["attributes"]["JOINTS_0"], raw=True)
                W = g.read_accessor(p["attributes"]["WEIGHTS_0"])
                prims.append((p, J, W))
                for j, w in zip(J, W):
                    for k in range(4):
                        if w[k] > 0.0:
                            weighted.add(j[k])
    keep_slots = [s for s, node in enumerate(joints)
                  if s in weighted or js["nodes"][node].get("name") in KEEP_UNWEIGHTED]
    # Um osso sem peso só pode sair se não tiver filho que fica.
    keep_nodes = {joints[s] for s in keep_slots}
    changed = True
    while changed:
        changed = False
        for s, node in enumerate(joints):
            if node in keep_nodes:
                continue
            if any(c in keep_nodes for c in js["nodes"][node].get("children", [])):
                keep_nodes.add(node)
                changed = True
    keep_slots = [s for s, node in enumerate(joints) if node in keep_nodes]
    slot_map = {old: new for new, old in enumerate(keep_slots)}
    removed = [js["nodes"][joints[s]]["name"] for s in range(len(joints)) if s not in slot_map]
    print("ossos removidos (%d): %s" % (len(removed), ", ".join(removed)))

    # Matrizes inversas de ligação só dos ossos que ficam.
    ibm = g.read_accessor(skin["inverseBindMatrices"])
    skin["inverseBindMatrices"] = g.add_accessor([ibm[s] for s in keep_slots], "MAT4", target=None)
    skin["joints"] = [joints[s] for s in keep_slots]
    for p, J, W in prims:
        new_j = []
        new_w = []
        for j, w in zip(J, W):
            jj = [slot_map.get(j[k], 0) if w[k] > 0.0 else 0 for k in range(4)]
            ww = [w[k] if j[k] in slot_map else 0.0 for k in range(4)]
            total = sum(ww)
            ww = [x / total for x in ww] if total > 0 else [1.0, 0.0, 0.0, 0.0]
            new_j.append(tuple(jj))
            new_w.append(tuple(ww))
        p["attributes"]["JOINTS_0"] = g.add_accessor(new_j, "VEC4", component=5123)
        p["attributes"]["WEIGHTS_0"] = g.add_accessor(new_w, "VEC4")
    gone = {joints[s] for s in range(len(joints)) if s not in slot_map}
    _reindex_nodes(g, [i for i in range(len(js["nodes"])) if i not in gone])


def _rename_bones(js):
    for n in js["nodes"]:
        name = n.get("name", "")
        if name.startswith("mixamorig:"):
            n["name"] = name[len("mixamorig:"):]


# --- Atlas de texturas ------------------------------------------------------------------

def _build_atlas(g):
    js = g.js
    mats = js["materials"]
    # Primitivas por material e o retângulo de UV que cada textura usa.
    users = {}  # índice do material -> [primitivas]
    for m in js["meshes"]:
        for p in m["primitives"]:
            users.setdefault(p.get("material"), []).append(p)

    # Materiais que usam a mesma imagem (no Henrique, o corpo e a pele da boca) viram uma
    # peça só do atlas.
    by_image = {}
    for mi, mat in enumerate(mats):
        tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is not None and mi in users:
            by_image.setdefault(js["textures"][tex["index"]]["source"], []).append(mi)

    pieces = []  # {"mats", "img", "rect": (x0, y0, x1, y1) em px da imagem original, "mask"}
    for image_index, group in by_image.items():
        img = Image.open(io.BytesIO(g.image_bytes(image_index)))
        logo = any(mats[mi].get("alphaMode") == "BLEND" for mi in group)
        img = img.convert("RGBA")
        w, h = img.size
        tris = []
        lo = [math.inf, math.inf]
        hi = [-math.inf, -math.inf]
        for p in (p for mi in group for p in users[mi]):
            uv = g.read_accessor(p["attributes"]["TEXCOORD_0"])
            idx = [i[0] for i in g.read_accessor(p["indices"])] if "indices" in p else list(range(len(uv)))
            for t in range(0, len(idx), 3):
                tri = [(uv[idx[t + k]][0] * w, uv[idx[t + k]][1] * h) for k in range(3)]
                tris.append(tri)
                for x, y in tri:
                    lo = [min(lo[0], x), min(lo[1], y)]
                    hi = [max(hi[0], x), max(hi[1], y)]
        if logo:
            # Os UVs dos logos passam de [0, 1]: fora da imagem fica transparente (a
            # textura original era "clamp"). O retângulo cobre tudo, com margem vazia.
            rect = (math.floor(lo[0]) - 2, math.floor(lo[1]) - 2, math.ceil(hi[0]) + 2, math.ceil(hi[1]) + 2)
            canvas = Image.new("RGBA", (rect[2] - rect[0], rect[3] - rect[1]), (0, 0, 0, 0))
            canvas.paste(img, (-rect[0], -rect[1]))
            pieces.append({"mats": group, "img": canvas, "rect": rect, "scale": (w, h), "logo": True})
            continue
        rect = (max(0, math.floor(lo[0]) - 4), max(0, math.floor(lo[1]) - 4),
                min(w, math.ceil(hi[0]) + 4), min(h, math.ceil(hi[1]) + 4))
        mask = Image.new("L", (w, h), 0)
        draw = ImageDraw.Draw(mask)
        for tri in tris:
            draw.polygon(tri, fill=255, outline=255)
        crop = img.crop(rect)
        crop_mask = mask.crop(rect)
        pieces.append({"mats": group, "img": crop, "mask": crop_mask, "rect": rect, "scale": (w, h), "logo": False})

    # Escala única (a Tripo já escolhe a resolução de cada parte pelo tamanho dela; os
    # logos ficam numa escala própria, menor). Busca binária da maior que cabe.
    def pack(f):
        boxes = []
        for i, pc in enumerate(pieces):
            k = f * (0.35 if pc["logo"] else 1.0)
            bw = max(4, int(math.ceil(pc["img"].width * k)))
            bh = max(4, int(math.ceil(pc["img"].height * k)))
            boxes.append((bh, bw, i))
        boxes.sort(reverse=True)
        # "Skyline": cada peça vai no ponto mais baixo (depois mais à esquerda) onde
        # cabe. O quadradinho branco fica no canto (0, 0).
        sky = [(0, WHITE + PAD, WHITE + PAD), (WHITE + PAD, 0, ATLAS - WHITE - PAD)]  # (x, altura ocupada, largura)
        placed = {}
        for bh, bw, i in boxes:
            w_need = bw + PAD
            best = None
            for s in range(len(sky)):
                x = sky[s][0]
                if x + bw > ATLAS:
                    break
                top = 0
                width = 0
                k = s
                while width < w_need and k < len(sky):
                    top = max(top, sky[k][1])
                    width += sky[k][2]
                    k += 1
                if width < min(w_need, ATLAS - x):
                    continue
                if top + bh > ATLAS:
                    continue
                if best is None or (top, x) < (best[0], best[1]):
                    best = (top, x)
            if best is None:
                return None
            top, x = best
            placed[i] = (x, top, bw, bh)
            # Atualiza o horizonte no trecho [x, x + w_need).
            end = min(ATLAS, x + w_need)
            new = []
            for sx, sh, sw in sky:
                if sx + sw <= x or sx >= end:
                    new.append((sx, sh, sw))
                    continue
                if sx < x:
                    new.append((sx, sh, x - sx))
                if sx + sw > end:
                    new.append((end, sh, sx + sw - end))
            new.append((x, top + bh + PAD, end - x))
            new.sort()
            sky = new
        return placed

    lo_f, hi_f = 0.05, 1.0
    for _ in range(30):
        mid = (lo_f + hi_f) / 2
        if pack(mid):
            lo_f = mid
        else:
            hi_f = mid
    f = lo_f
    placed = pack(f)
    print("atlas: escala %.3f (4096 -> %d px)" % (f, int(4096 * f)))

    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 255))
    atlas.paste((255, 255, 255, 255), (0, 0, WHITE, WHITE))
    uv_xf = {}  # material -> (função de remapear UV)
    for i, pc in enumerate(pieces):
        x, y, bw, bh = placed[i]
        img = pc["img"].resize((bw, bh), Image.LANCZOS)
        if pc["logo"]:
            atlas.paste(img, (x, y))
        else:
            mask = pc["mask"].resize((bw, bh), Image.BOX)
            atlas.paste(_dilate(img.convert("RGB"), mask).convert("RGBA"), (x, y))
        rect = pc["rect"]
        w, h = pc["scale"]
        sx = bw / (rect[2] - rect[0])
        sy = bh / (rect[3] - rect[1])
        for mi in pc["mats"]:
            uv_xf[mi] = (x, y, rect[0], rect[1], sx, sy, w, h)

    # Atlas como textura 0 (PNG, com transparência por causa dos logos).
    buf = io.BytesIO()
    atlas.save(buf, "PNG", optimize=True)
    print("atlas png %.1f MB" % (len(buf.getvalue()) / 1e6))
    js["images"] = [{"bufferView": g.add_view(buf.getvalue()), "mimeType": "image/png", "name": "atlas"}]
    js["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
    js["textures"] = [{"sampler": 0, "source": 0}]

    white_uv = (WHITE * 0.5 / ATLAS, WHITE * 0.5 / ATLAS)
    for mi, mat in enumerate(mats):
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        textured = "baseColorTexture" in pbr
        pbr["baseColorTexture"] = {"index": 0}
        if textured:
            pbr.pop("baseColorFactor", None)
        pbr["metallicFactor"] = 0
        pbr.setdefault("roughnessFactor", 1.0)
        # As texturas antigas saem (o atlas é a única): mapas de metal/rugosidade, normal...
        pbr.pop("metallicRoughnessTexture", None)
        for key in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            mat.pop(key, None)
        mat.pop("extensions", None)  # KHR_materials_specular (só a sombra da órbita)
        mat["doubleSided"] = True
        if mat.get("alphaMode") == "BLEND":
            mat["alphaMode"] = "MASK"
            mat["alphaCutoff"] = 0.5
        for p in users.get(mi, []):
            if textured:
                x, y, cx, cy, sx, sy, w, h = uv_xf[mi]
                uv = g.read_accessor(p["attributes"]["TEXCOORD_0"])
                new = [((x + (u * w - cx) * sx) / ATLAS, (y + (v * h - cy) * sy) / ATLAS) for u, v in uv]
            else:
                count = g.js["accessors"][p["attributes"]["POSITION"]]["count"]
                new = [white_uv] * count
            p["attributes"]["TEXCOORD_0"] = g.add_accessor(new, "VEC2")


def _dilate(img, mask):
    """Espalha a cor das ilhas de UV para o fundo (push-pull), para o filtro bilinear e
    os mipmaps não puxarem o preto do fundo para as bordas das peças."""
    levels = [(img, mask)]
    while min(levels[-1][0].size) > 2:
        im, m = levels[-1]
        size = (max(1, im.width // 2), max(1, im.height // 2))
        # Média ponderada pela máscara: (cor * máscara) reduzida / máscara reduzida.
        premul = Image.merge("RGB", [ImageMath.lambda_eval(lambda a: a["c"] * a["m"] / 255, c=c, m=m).convert("L")
                                     for c in im.split()])
        small = premul.resize(size, Image.BOX)
        small_m = m.resize(size, Image.BOX)
        bands = [ImageMath.lambda_eval(lambda a: a["c"] * 255 / (a["m"] + (a["m"] == 0)), c=c, m=small_m).convert("L")
                 for c in small.split()]
        levels.append((Image.merge("RGB", bands), small_m.point(lambda v: 255 if v > 0 else 0)))
    filled = levels[-1][0]
    for im, m in reversed(levels[:-1]):
        up = filled.resize(im.size, Image.BILINEAR)
        filled = Image.composite(im, up, m.point(lambda v: 255 if v >= 128 else 0))
    return filled


if __name__ == "__main__":
    main()
