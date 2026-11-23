"""Prepara o modelo de um piloto com textura (Jarbas, Henrique, Ulysses) para o jogo.

Lê o modelo original de tools/personagens/originais/ (exportado do Blender com
esqueleto, poses e expressões, já em metros e nas proporções finais do encaixe piloto ×
kart) e grava assets/models/personagens/<nome>.glb:

- tira o volante e o guidão de referência (Ref_*) e os desenhos de controle (WGT_*);
- tira as cores de vértice e o segundo UV, que o jogo não usa;
- tira do esqueleto os ossos sem peso nenhum (controles de IK do Blender, alvos do
  olhar, pontas dos dedos e dos pés) — no Godot eles não fazem nada e o CharacterRig
  percorre todos os ossos a cada quadro. A raiz (Raiz) fica: é ela que, na POSE_Kart,
  desce o corpo até o assento;
- renomeia os ossos "mixamorig:Xxx" para "Xxx";
- junta as texturas (as 27 da Tripo no Jarbas, a única do Henrique, as duas do Ulysses)
  e os logos num atlas só (2048 x 2048). No Ulysses cada textura entra recortada por ilha
  de UV (as dele usam só parte da área). As partes de cor lisa (olhos, boca, luvas,
  pálpebras) apontam para um quadradinho branco do atlas e mantêm a cor no material.
  Assim o CharacterMesh junta o piloto inteiro numa superfície só (na web cada superfície
  com esqueleto custa um passe de GPU por quadro). Mapas de normal, rugosidade e metal
  saem (o shader dos pilotos não usa);
- logos: transparência recortada (alpha scissor) em vez de mistura, para caberem na
  mesma superfície;
- Henrique: a aba do boné vai para um material próprio ("SemSombra_Aba_Bone", mesma
  textura), que no jogo não projeta sombra (ela escurecia o rosto).

As animações do arquivo (expressões, piscada, POSE_Kart, POSE_Moto) vão junto. As que o
jogo usa são montadas no Godot por gerar_animacoes.gd (veja o README desta pasta).

Uso: python3 tools/personagens/build_personagem.py jarbas|henrique|ulysses|rafael
"""
import colorsys
import io
import json
import math
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageMath

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "karts"))
from gltf_util import Glb, xf_point  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
CHARACTERS = {
    "jarbas": {"src": "jarbas-piloto.glb"},
    "henrique": {
        "src": "henrique-piloto.glb",
        # A aba do boné fazia uma sombra grande no rosto (medido na tela de seleção e na
        # corrida). Ela é azul e fica na frente da testa (y 0,92 a 0,96, até z 0,20); a
        # frente da copa, logo acima, não passa de z 0,09, e a pele da testa é outro
        # material (PELE__).
        "no_shadow": [{"name": "Aba_Bone", "mesh": "Henrique_Corpo", "material": "TECIDO__tripo_mat_4699cc3b",
                       "min_y": 0.91, "min_front_z": 0.095, "hue": (0.5, 0.75), "min_saturation": 0.3}],
    },
    # Duas texturas de 4096 (cabeça da Tripo e corpo refeito) usando só 27% e 40% da área:
    # inteiras, cada uma viraria ~1000 px no atlas; por ilha de UV, o dobro.
    "ulysses": {"src": "ulysses-piloto.glb", "islands": True},
    # Rosto por shape keys (sorriso, piscada, visemas da fala), não por ossos. As pálpebras
    # à parte (Palpebras) e a cópia do corpo sem esqueleto (_REF_Corpo_original) ficam
    # escondidas no .blend: saem. As partes do corpo com shape keys vão para uma malha
    # própria (Rafael_Rosto); o resto do corpo fica sem eles.
    "rafael": {"src": "rafael-piloto.glb", "drop": ("Palpebras", "_REF_Corpo_original"),
               # A pálpebra de baixo aponta para baixo e para dentro da órbita: com a luz do
               # jogo vindo de cima, a faixa embaixo de cada olho ficava escura (parecia
               # olheira). Faixa: do contorno do olho (1,1 cm abaixo do centro) até 3,6 cm,
               # 3,4 cm para cada lado.
               "fill_under_eyes": {"mesh": "Rafael_Rosto", "eyes": ("Olho.L", "Olho.R"),
                                   "band": (0.008, 0.014, 0.026, 0.036), "half_width": (0.02, 0.034),
                                   "toward": (0.0, 0.35, 0.94), "amount": 0.7}},
}

ATLAS = 2048
PAD = 6  # pixels entre retângulos no atlas (já na escala final)
WHITE = 8  # lado do quadradinho branco das cores lisas
DROP_NODES = ("Ref_Guidao_Moto", "Ref_Volante_Kart", "WGT_Circulo", "WGT_Olhar_Alvo")
KEEP_UNWEIGHTED = ("Raiz",)  # raiz do esqueleto (pai do quadril)
## Materiais com este prefixo não projetam sombra no jogo (CharacterMesh e
## character_textured.gdshader).
NO_SHADOW_PREFIX = "SemSombra_"


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in CHARACTERS:
        raise SystemExit("uso: python3 tools/personagens/build_personagem.py %s" % "|".join(CHARACTERS))
    name = sys.argv[1]
    cfg = CHARACTERS[name]
    src = os.path.join(HERE, "originais", cfg["src"])
    dst = os.path.join(PROJ, "assets", "models", "personagens", name + ".glb")
    g = Glb(src)
    js = g.js
    _drop_scene_nodes(g, DROP_NODES + tuple(cfg.get("drop", ())))
    _strip_unused_attributes(js)
    _split_shape_keys(g)
    _clean_skeleton(g)
    _rename_bones(js)
    for rule in cfg.get("no_shadow", []):
        _split_no_shadow(g, rule)
    if "fill_under_eyes" in cfg:
        _fill_under_eyes(g, cfg["fill_under_eyes"])
    _build_atlas(g, cfg.get("islands", False))
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


def _strip_unused_attributes(js):
    """O jogo não usa cor de vértice (o Blender exporta uma camada por atributo de cor,
    COLOR_0 a COLOR_n) nem o segundo UV."""
    for m in js["meshes"]:
        for p in m["primitives"]:
            for attr in list(p["attributes"]):
                if attr.startswith("COLOR_") or attr == "TEXCOORD_1":
                    p["attributes"].pop(attr)


def _clean_skeleton(g):
    """Tira do skin (e da cena) os ossos sem peso, remapeando JOINTS_0."""
    js = g.js
    skin = js["skins"][0]
    joints = skin["joints"]
    weighted = set()
    prims = []
    # Só as malhas que ficaram na cena (as de nós tirados saem no compact).
    for m in (js["meshes"][i] for i in sorted({n["mesh"] for n in js["nodes"] if "mesh" in n})):
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


# --- Shape keys ---------------------------------------------------------------------------

def _split_shape_keys(g):
    """Malha com shape keys (o rosto do Rafael): as primitivas que algum shape key mexe vão
    para uma malha nova, "<nó sem o _Corpo>_Rosto", num nó irmão com o mesmo esqueleto, e
    levam os shape keys e as trilhas de peso das animações; as outras (tecido, sapatos)
    ficam na malha original, sem shape keys. No jogo cada vértice de uma malha com shape
    keys passa pela mistura deles a cada quadro (na web, um passe de GPU por shape key
    ligado): assim só os ~5 mil vértices do rosto pagam isso."""
    js = g.js
    for node_index, node in enumerate(list(js["nodes"])):
        if "mesh" not in node:
            continue
        mesh = js["meshes"][node["mesh"]]
        prims = mesh["primitives"]
        if not any(p.get("targets") for p in prims):
            continue
        moving, still = [], []
        for p in prims:
            moved = any(any(x != 0 for v in g.read_accessor(acc) for x in v)
                        for t in p.get("targets", []) for key, acc in t.items() if key == "POSITION")
            (moving if moved else still).append(p)
        if not still or not moving:
            continue
        face_name = node["name"].replace("_Corpo", "") + "_Rosto"
        face_mesh = {"name": face_name, "primitives": moving}
        for key in ("extras", "weights"):
            if key in mesh:
                face_mesh[key] = mesh.pop(key)
        for p in still:
            p.pop("targets", None)
        mesh["primitives"] = still
        js["meshes"].append(face_mesh)
        face_node = {k: v for k, v in node.items() if k not in ("mesh", "children", "name")}
        face_node["name"] = face_name
        face_node["mesh"] = len(js["meshes"]) - 1
        js["nodes"].append(face_node)
        face_index = len(js["nodes"]) - 1
        parent = next((n for n in js["nodes"] if node_index in n.get("children", [])), None)
        if parent is not None:
            parent["children"].append(face_index)
        else:
            for scene in js["scenes"]:
                if node_index in scene["nodes"]:
                    scene["nodes"].append(face_index)
        for anim in js.get("animations", []):
            for ch in anim["channels"]:
                if ch["target"]["path"] == "weights" and ch["target"].get("node") == node_index:
                    ch["target"]["node"] = face_index
        names = face_mesh.get("extras", {}).get("targetNames", [])
        print("shape keys: %s -> %s (%d primitivas, %d shape keys); %d primitivas ficam sem" % (
            node["name"], face_name, len(moving), len(names), len(still)))


# --- Luz embaixo dos olhos --------------------------------------------------------------

def _smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def _fill_under_eyes(g, rule):
    """Gira as normais da faixa embaixo de cada olho para `toward` (para a frente e um
    pouco para cima), como uma luz de preenchimento: a malha não muda, só como ela recebe
    luz. Peso por vértice: em altura, de 0 no contorno do olho (`band[0]` abaixo do
    centro) a 1 entre `band[1]` e `band[2]`, de volta a 0 em `band[3]`; para os lados, 1
    até `half_width[0]` e 0 em `half_width[1]`. Os shape keys somam o deslocamento de
    normal deles por cima (a piscada continua igual)."""
    js = g.js
    world = g.world_matrices()
    eyes = [xf_point(world[i], (0.0, 0.0, 0.0)) for i, n in enumerate(js["nodes"]) if n.get("name") in rule["eyes"]]
    mesh = next(m for m in js["meshes"] if m["name"] == rule["mesh"])
    b0, b1, b2, b3 = rule["band"]
    w0, w1 = rule["half_width"]
    tx, ty, tz = rule["toward"]
    tl = math.sqrt(tx * tx + ty * ty + tz * tz)
    toward = (tx / tl, ty / tl, tz / tl)
    total = 0
    for p in mesh["primitives"]:
        pos = g.read_accessor(p["attributes"]["POSITION"])
        nor = g.read_accessor(p["attributes"]["NORMAL"])
        out = []
        moved = 0
        for v, n in zip(pos, nor):
            w = 0.0
            for e in eyes:
                if v[2] < e[2] - 0.01:
                    continue
                below = e[1] - v[1]
                wy = _smooth(b0, b1, below) * (1.0 - _smooth(b2, b3, below))
                wx = 1.0 - _smooth(w0, w1, abs(v[0] - e[0]))
                w = max(w, wy * wx)
            if w <= 0.0:
                out.append(n)
                continue
            k = w * rule["amount"]
            m = [n[i] + (toward[i] - n[i]) * k for i in range(3)]
            ml = math.sqrt(sum(c * c for c in m)) or 1.0
            out.append(tuple(c / ml for c in m))
            moved += 1
        if moved:
            p["attributes"]["NORMAL"] = g.add_accessor(out, "VEC3")
            total += moved
    print("luz embaixo dos olhos: %d vértices" % total)


# --- Partes sem sombra ------------------------------------------------------------------

def _split_no_shadow(g, rule):
    """Passa os triângulos de uma parte (a aba do boné do Henrique) para uma primitiva
    própria, com uma cópia do material chamada NO_SHADOW_PREFIX + nome. A cópia usa a
    mesma textura (vai para a mesma peça do atlas), então nada muda na aparência; no
    jogo ela só deixa de projetar sombra.

    Um triângulo é da parte se o centro dele fica acima de `min_y`, se algum vértice
    passa de `min_front_z` para a frente e se a cor da textura no centro tem a matiz em
    `hue` e saturação de `min_saturation` para cima. (A aba tem poucos triângulos, que vão
    da borda até a raiz, já em cima da testa e da copa: por isso o vértice mais à frente
    e a cor no centro, e não todos os vértices.)"""
    js = g.js
    mesh = next(m for m in js["meshes"] if m["name"] == rule["mesh"])
    mat_index = next(i for i, m in enumerate(js["materials"]) if m.get("name") == rule["material"])
    prim = next(p for p in mesh["primitives"] if p.get("material") == mat_index)
    tex = js["materials"][mat_index]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = Image.open(io.BytesIO(g.image_bytes(js["textures"][tex]["source"]))).convert("RGB")
    w, h = img.size

    pos = g.read_accessor(prim["attributes"]["POSITION"])
    uv = g.read_accessor(prim["attributes"]["TEXCOORD_0"])
    idx = [i[0] for i in g.read_accessor(prim["indices"])]
    keep, moved = [], []
    for t in range(0, len(idx), 3):
        tri = idx[t:t + 3]
        y = sum(pos[i][1] for i in tri) / 3.0
        ok = y > rule["min_y"] and max(pos[i][2] for i in tri) > rule["min_front_z"]
        if ok:
            u = sum(uv[i][0] for i in tri) / 3.0
            v = sum(uv[i][1] for i in tri) / 3.0
            r, gr, b = img.getpixel((min(w - 1, max(0, int(u * w))), min(h - 1, max(0, int(v * h)))))
            hue, sat, _ = colorsys.rgb_to_hsv(r / 255.0, gr / 255.0, b / 255.0)
            ok = rule["hue"][0] <= hue <= rule["hue"][1] and sat >= rule["min_saturation"]
        (moved if ok else keep).extend(tri)
    if not moved:
        raise SystemExit("%s: nenhum triângulo da parte sem sombra" % rule["name"])

    def subset(tris):
        """Primitiva só com os vértices que os triângulos usam (todos os atributos,
        inclusive o esqueleto)."""
        used = sorted(set(tris))
        remap = {old: new for new, old in enumerate(used)}
        attrs = {}
        for name, acc in prim["attributes"].items():
            a = js["accessors"][acc]
            vals = g.read_accessor(acc, raw=True)
            attrs[name] = g.add_accessor([vals[i] for i in used], a["type"], a["componentType"],
                                         minmax=(name == "POSITION"))
            if a.get("normalized"):
                js["accessors"][attrs[name]]["normalized"] = True
        return attrs, g.add_indices([remap[i] for i in tris])

    mat = json.loads(json.dumps(js["materials"][mat_index]))
    mat["name"] = NO_SHADOW_PREFIX + rule["name"]
    js["materials"].append(mat)
    part_attrs, part_indices = subset(moved)
    prim["attributes"], prim["indices"] = subset(keep)
    mesh["primitives"].append({"attributes": part_attrs, "indices": part_indices,
                               "material": len(js["materials"]) - 1})
    ys = [pos[i][1] for i in moved]
    zs = [pos[i][2] for i in moved]
    print("sem sombra: %s, %d triângulos (y %.3f a %.3f, z %.3f a %.3f)" % (
        mat["name"], len(moved) // 3, min(ys), max(ys), min(zs), max(zs)))


# --- Atlas de texturas ------------------------------------------------------------------

def _build_atlas(g, islands=False):
    """Junta as texturas num atlas. `islands`: cada textura entra recortada por ilha de UV
    (veja _island_pieces) em vez de pelo retângulo que todos os UVs dela ocupam."""
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
        # Logos: material com transparência (os modelos antigos vinham com BLEND; os
        # refeitos para o encaixe piloto × kart já vêm com MASK). Sem isso a logo entra
        # como textura comum, perde a transparência e aparece com o fundo da imagem.
        logo = any(mats[mi].get("alphaMode") in ("BLEND", "MASK") for mi in group)
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
        if islands:
            pieces += _island_pieces(g, group, [p for mi in group for p in users[mi]], img)
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
    vert_xf = {}  # id(primitiva) -> {vértice: (função de remapear UV)} (ilhas de UV)
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
        xf = (x, y, rect[0], rect[1], sx, sy, w, h)
        if "verts" in pc:
            # Ilha de UV: o remapeamento é por vértice.
            for pid, verts in pc["verts"].items():
                per_vertex = vert_xf.setdefault(pid, {})
                for v in verts:
                    per_vertex[v] = xf
        else:
            for mi in pc["mats"]:
                uv_xf[mi] = xf
    if islands:
        # Os vãos entre as peças pegam a cor das bordas (senão os mipmaps de longe puxam
        # o preto do fundo para as costuras de tantas ilhas pequenas).
        occupied = Image.new("L", (ATLAS, ATLAS), 0)
        occupied.paste(255, (0, 0, WHITE, WHITE))
        for x, y, bw, bh in placed.values():
            occupied.paste(255, (x, y, x + bw, y + bh))
        rgb = _dilate(atlas.convert("RGB"), occupied)
        atlas = Image.merge("RGBA", rgb.split() + (atlas.getchannel("A"),))

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
        if mat.get("alphaMode") in ("BLEND", "MASK"):
            mat["alphaMode"] = "MASK"
            mat["alphaCutoff"] = 0.5
        for p in users.get(mi, []):
            if textured and id(p) in vert_xf:
                per_vertex = vert_xf[id(p)]
                fallback = next(iter(per_vertex.values()))  # vértice sem triângulo
                uv = g.read_accessor(p["attributes"]["TEXCOORD_0"])
                new = []
                for k, (u, v) in enumerate(uv):
                    x, y, cx, cy, sx, sy, w, h = per_vertex.get(k, fallback)
                    new.append(((x + (u * w - cx) * sx) / ATLAS, (y + (v * h - cy) * sy) / ATLAS))
            elif textured:
                x, y, cx, cy, sx, sy, w, h = uv_xf[mi]
                uv = g.read_accessor(p["attributes"]["TEXCOORD_0"])
                new = [((x + (u * w - cx) * sx) / ATLAS, (y + (v * h - cy) * sy) / ATLAS) for u, v in uv]
            else:
                count = g.js["accessors"][p["attributes"]["POSITION"]]["count"]
                new = [white_uv] * count
            p["attributes"]["TEXCOORD_0"] = g.add_accessor(new, "VEC2")


def _island_pieces(g, group, prims, img, margin=4):
    """Peças do atlas por ilha de UV de uma textura: os triângulos ligados (vértices em
    comum, ou no mesmo ponto do UV, nas costuras) formam uma ilha. Ilhas cujos retângulos
    juntos não ocupam mais área que separados (uma dentro da outra, ou quase) viram uma
    peça só. Cada peça leva os vértices que usam ela ("verts": id(primitiva) -> índices)."""
    w, h = img.size
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    data = []
    same_uv = {}
    for pi, p in enumerate(prims):
        uv = g.read_accessor(p["attributes"]["TEXCOORD_0"])
        idx = [i[0] for i in g.read_accessor(p["indices"])] if "indices" in p else list(range(len(uv)))
        for k in range(len(uv)):
            parent[(pi, k)] = (pi, k)
        for t in range(0, len(idx), 3):
            union((pi, idx[t]), (pi, idx[t + 1]))
            union((pi, idx[t]), (pi, idx[t + 2]))
        for k, (u, v) in enumerate(uv):
            key = (round(u * w * 8), round(v * h * 8))
            if key in same_uv:
                union(same_uv[key], (pi, k))
            else:
                same_uv[key] = (pi, k)
        data.append((p, uv, idx))

    by_root = {}
    for pi, (p, uv, idx) in enumerate(data):
        for t in range(0, len(idx), 3):
            tri = idx[t:t + 3]
            isl = by_root.setdefault(find((pi, tri[0])), {"tris": [], "verts": {}, "box": [math.inf, math.inf, -math.inf, -math.inf]})
            pts = [(uv[i][0] * w, uv[i][1] * h) for i in tri]
            isl["tris"].append(pts)
            isl["verts"].setdefault(id(p), set()).update(tri)
            box = isl["box"]
            for x, y in pts:
                box[0], box[1] = min(box[0], x), min(box[1], y)
                box[2], box[3] = max(box[2], x), max(box[3], y)
    found = len(by_root)

    def area(b):
        return (b[2] - b[0] + 2 * margin) * (b[3] - b[1] + 2 * margin)

    boxes = list(by_root.values())
    merged = True
    while merged:
        merged = False
        boxes.sort(key=lambda b: -area(b["box"]))
        i = 0
        while i < len(boxes):
            a = boxes[i]
            j = i + 1
            while j < len(boxes):
                b = boxes[j]
                ab, bb = a["box"], b["box"]
                u = [min(ab[0], bb[0]), min(ab[1], bb[1]), max(ab[2], bb[2]), max(ab[3], bb[3])]
                if area(u) <= area(ab) + area(bb):
                    a["box"] = u
                    a["tris"] += b["tris"]
                    for pid, verts in b["verts"].items():
                        a["verts"].setdefault(pid, set()).update(verts)
                    del boxes[j]
                    merged = True
                    j = i + 1  # a caixa cresceu: confere de novo as que ficaram
                    continue
                j += 1
            i += 1

    pieces = []
    for isl in boxes:
        lo_x, lo_y, hi_x, hi_y = isl["box"]
        rect = (max(0, math.floor(lo_x) - margin), max(0, math.floor(lo_y) - margin),
                min(w, math.ceil(hi_x) + margin), min(h, math.ceil(hi_y) + margin))
        mask = Image.new("L", (rect[2] - rect[0], rect[3] - rect[1]), 0)
        draw = ImageDraw.Draw(mask)
        for tri in isl["tris"]:
            draw.polygon([(x - rect[0], y - rect[1]) for x, y in tri], fill=255, outline=255)
        pieces.append({"mats": group, "img": img.crop(rect), "mask": mask, "rect": rect, "scale": (w, h),
                       "logo": False, "verts": isl["verts"]})
    used = sum((p["rect"][2] - p["rect"][0]) * (p["rect"][3] - p["rect"][1]) for p in pieces)
    print("ilhas: %d -> %d peças, %.0f%% da textura %dx%d" % (found, len(pieces), 100.0 * used / (w * h), w, h))
    return pieces


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
