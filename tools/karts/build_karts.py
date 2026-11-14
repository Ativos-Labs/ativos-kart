#!/usr/bin/env python3
"""Gera os karts novos em assets/models/karts/ a partir dos modelos originais.

    python3 tools/karts/build_karts.py

O que faz em cada modelo (os originais ficam em tools/karts/originais/):
- Troca os adesivos que vieram com o modelo pelas logos da Ativos (assets/logos/).
- Bólido (kart azul, sem textura): separa as rodas (vêm fundidas numa malha só) para
  elas girarem e esterçarem, e cola adesivos da Ativos (malhas finas que acompanham a
  carroceria, com a logo projetada).
- Cometa: troca o emblema de raio da lateral pelo "at" brilhando e corrige a UV de um
  dos lados para a logo não sair espelhada.
- Motoca: troca o emblema de espada do tanque pelo "at".
- Bugre: apaga os adesivos (textos, mascotes, desenhos) e cola as logos da Ativos nas
  laterais, no capô, na asa e nas aletas da asa.
- Renomeia as rodas (RodaFrenteEsq, RodaFrenteDir, RodaTrasEsq, RodaTrasDir) para os
  .tres de data/karts/ acharem.

Precisa de Python 3 com Pillow (pip install pillow). Depois de rodar, abra o Godot (ou
`Godot --headless --path . --import`) para reimportar os .glb.
"""
import io
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_util import (Glb, add, cross, dot, mul, norm, sub, triangles, xf_dir,  # noqa: E402
                       xf_point)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ORIG = os.path.join(HERE, "originais")
OUT = os.path.join(ROOT, "assets", "models", "karts")
LOGOS = os.path.join(ROOT, "assets", "logos")

ATIVOS_BLUE = (40, 62, 192)
WHITE = (255, 255, 255)


# --- Logos e adesivos --------------------------------------------------------------

def logo(name):
    return Image.open(os.path.join(LOGOS, name)).convert("RGBA")


def pad(img, px):
    out = Image.new("RGBA", (img.width + 2 * px, img.height + 2 * px), (0, 0, 0, 0))
    out.paste(img, (px, px))
    return out


def die_cut(img, border=0.07, edge=(205, 212, 228)):
    """Adesivo recortado: a logo sobre um fundo branco no formato dela (com os buracos
    das letras preenchidos) e uma borda fininha cinza para destacar em fundo claro."""
    b = max(2, int(min(img.size) * border))
    img = pad(img, b * 2 + 8)
    alpha = img.getchannel("A").point(lambda a: 255 if a > 20 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(b * 2 + 1))
    # Preenche os buracos: tudo o que não é alcançável a partir da borda vira fundo.
    flood = grown.copy()
    ImageDraw.floodfill(flood, (0, 0), 128)
    backing = flood.point(lambda v: 0 if v == 128 else 255)
    backing = backing.filter(ImageFilter.GaussianBlur(1.2))
    ring = backing.filter(ImageFilter.MaxFilter(5))
    out = Image.new("RGBA", img.size, edge + (0,))
    out.putalpha(ring)
    white = Image.new("RGBA", img.size, WHITE + (0,))
    white.putalpha(backing)
    out = Image.alpha_composite(out, white)
    out = Image.alpha_composite(out, img)
    return out.crop(out.getbbox())


def white_bar(img, aspect, height_pad=0.16, color=(22, 28, 64)):
    """Logo (versão branca) no meio de uma faixa escura arredondada (largura/altura = aspect)."""
    ph = int(img.height * height_pad)
    h = img.height + ph * 2
    w = max(int(h * aspect), img.width + ph * 3)
    bar = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2.6, fill=color + (255,),
                                          outline=(255, 255, 255, 255), width=max(3, h // 22))
    bar.alpha_composite(img, ((w - img.width) // 2, (h - img.height) // 2))
    return bar


def glow_emblem(icon, size=512):
    """Emblema futurista: disco escuro, aro azul brilhando e o "at" claro com brilho."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    c = size / 2
    d.ellipse((0, 0, size - 1, size - 1), fill=(14, 22, 44, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r1 = size * 0.42
    gd.ellipse((c - r1, c - r1, c + r1, c + r1), outline=(70, 170, 255, 255), width=int(size * 0.05))
    out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.03)))
    out.alpha_composite(glow)
    # Logo clara (silhueta do ícone) com brilho azul.
    inner = int(size * 0.6)
    ic = icon.copy()
    ic.thumbnail((inner, inner), Image.LANCZOS)
    a = ic.getchannel("A")
    light = Image.new("RGBA", ic.size, (215, 240, 255, 0))
    light.putalpha(a)
    halo = Image.new("RGBA", ic.size, (60, 160, 255, 0))
    halo.putalpha(a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(size * 0.02)))
    pos = ((size - ic.width) // 2, (size - ic.height) // 2)
    out.alpha_composite(halo, pos)
    out.alpha_composite(halo, pos)
    out.alpha_composite(light, pos)
    return out


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


# --- Malhas: leitura em espaço da cena -------------------------------------------

class Prim:
    """Uma primitiva com vértices no espaço da cena (já com a matriz do nó)."""

    def __init__(self, glb, node_index, prim_index, matrix):
        self.glb = glb
        self.node = node_index
        self.prim = glb.prims_of_node(node_index)[prim_index]
        self.matrix = matrix
        attrs = self.prim["attributes"]
        self.local = glb.read_accessor(attrs["POSITION"])
        self.pos = [xf_point(matrix, p) for p in self.local]
        self.normals = None
        if "NORMAL" in attrs:
            self.normals = [norm(xf_dir(matrix, n)) for n in glb.read_accessor(attrs["NORMAL"])]
        self.uv = glb.read_accessor(attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else None
        self.tris = triangles(glb, self.prim)


def prims_named(glb, names):
    mats = glb.world_matrices()
    out = []
    for name in names:
        i = glb.find_node(name)
        for k in range(len(glb.prims_of_node(i))):
            out.append(Prim(glb, i, k, mats[i]))
    return out


def tri_geometry(p, t):
    a, b, c = (p.pos[i] for i in t)
    n = cross(sub(b, a), sub(c, a))
    area = math.sqrt(dot(n, n)) / 2
    return a, b, c, n, area


# --- Pintar uma logo na textura, pela UV de um trecho do modelo ----------------------

def uv_frame(p, tris, tex_size):
    """Centro (px), centro 3D, normal e jacobiana (3D por pixel da textura) de um
    grupo de triângulos de uma ilha da UV."""
    W, H = tex_size
    total = 0.0
    c3 = (0.0, 0.0, 0.0)
    cuv = [0.0, 0.0]
    nrm = (0.0, 0.0, 0.0)
    ju = (0.0, 0.0, 0.0)
    jv = (0.0, 0.0, 0.0)
    for t in tris:
        a, b, c, n, area = tri_geometry(p, t)
        ua, ub, uc = ((p.uv[i][0] * W, p.uv[i][1] * H) for i in t)
        d1 = (ub[0] - ua[0], ub[1] - ua[1])
        d2 = (uc[0] - ua[0], uc[1] - ua[1])
        det = d1[0] * d2[1] - d1[1] * d2[0]
        if area < 1e-12 or abs(det) < 1e-9:
            continue
        e1, e2 = sub(b, a), sub(c, a)
        # [e1 e2] = J [d1 d2]  ->  J = [e1 e2] inv([d1 d2])
        i00, i01, i10, i11 = d2[1] / det, -d2[0] / det, -d1[1] / det, d1[0] / det
        tju = add(mul(e1, i00), mul(e2, i10))
        tjv = add(mul(e1, i01), mul(e2, i11))
        total += area
        c3 = add(c3, mul(add(add(a, b), c), area / 3))
        cuv[0] += area * (ua[0] + ub[0] + uc[0]) / 3
        cuv[1] += area * (ua[1] + ub[1] + uc[1]) / 3
        nrm = add(nrm, mul(n, 0.5))
        ju = add(ju, mul(tju, area))
        jv = add(jv, mul(tjv, area))
    assert total > 0, "nenhum triângulo na região"
    return (cuv[0] / total, cuv[1] / total), mul(c3, 1 / total), norm(nrm), mul(ju, 1 / total), mul(jv, 1 / total)


def solve_uv(ju, jv, vec):
    """Vetor 3D -> deslocamento (du, dv) em pixels (mínimos quadrados)."""
    a, b, c = dot(ju, ju), dot(ju, jv), dot(jv, jv)
    det = a * c - b * b
    x, y = dot(ju, vec), dot(jv, vec)
    return ((c * x - b * y) / det, (a * y - b * x) / det)


def uv_mask(p, tris, tex_size, grow=3):
    W, H = tex_size
    m = Image.new("L", tex_size, 0)
    d = ImageDraw.Draw(m)
    for t in tris:
        d.polygon([(p.uv[i][0] * W, p.uv[i][1] * H) for i in t], fill=255)
    return m.filter(ImageFilter.MaxFilter(grow * 2 + 1)) if grow else m


def paint_logo(tex, p, tris, art, width, up, center_uv=None, shift=(0.0, 0.0), clip=True):
    """Pinta `art` na textura `tex` sobre o trecho `tris` da primitiva `p`.

    width: largura da arte em unidades do modelo. up: direção 3D do "para cima" da arte
    (é projetada no plano da superfície). shift: deslocamento (direita, cima) em
    unidades do modelo a partir do centro do trecho. Retorna a textura nova."""
    cuv, _c3, n, ju, jv = uv_frame(p, tris, tex.size)
    if center_uv:
        cuv = center_uv
    up = norm(sub(up, mul(n, dot(up, n))))
    right = cross(up, n)
    k = width / art.width  # unidades do modelo por pixel da arte
    a = solve_uv(ju, jv, mul(right, k))
    b = solve_uv(ju, jv, mul(up, -k))
    # Desloca o centro.
    sr = solve_uv(ju, jv, right)
    su = solve_uv(ju, jv, up)
    cuv = (cuv[0] + sr[0] * shift[0] + su[0] * shift[1], cuv[1] + sr[1] * shift[0] + su[1] * shift[1])
    # Reduz a arte para ~1 pixel da textura por pixel da arte antes de girar (sem serrilhado).
    scale = math.hypot(*a)
    if scale < 1.0:
        art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
        a = (a[0] / scale, a[1] / scale)
        b = (b[0] / scale, b[1] / scale)
    det = a[0] * b[1] - a[1] * b[0]
    m00, m01, m10, m11 = b[1] / det, -b[0] / det, -a[1] / det, a[0] / det
    hw, hh = art.width / 2, art.height / 2
    data = (m00, m01, -m00 * cuv[0] - m01 * cuv[1] + hw,
            m10, m11, -m10 * cuv[0] - m11 * cuv[1] + hh)
    layer = art.transform(tex.size, Image.AFFINE, data, resample=Image.BICUBIC)
    if clip:
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), uv_mask(p, tris, tex.size)))
    return Image.alpha_composite(tex, layer)


def tris_on_blob(p, old_tex, tex_size, bbox):
    """Triângulos cujo centro (na UV) cai num pixel opaco de `old_tex` dentro de `bbox`
    (x0, y0, x1, y1 em pixels de `tex_size`)."""
    W, H = tex_size
    sx, sy = old_tex.width / W, old_tex.height / H
    alpha = old_tex.getchannel("A").load()
    out = []
    for t in p.tris:
        u = sum(p.uv[i][0] for i in t) / 3 * W
        v = sum(p.uv[i][1] for i in t) / 3 * H
        if bbox[0] <= u <= bbox[2] and bbox[1] <= v <= bbox[3]:
            if alpha[min(int(u * sx), old_tex.width - 1), min(int(v * sy), old_tex.height - 1)] > 40:
                out.append(t)
    if not out:
        return out
    # Vizinhos da mesma ilha que o adesivo antigo não cobria (senão a logo nova sai
    # cortada): UV na mesma caixa, perto no 3D e virados para o mesmo lado.
    _cuv, c3, n, _ju, _jv = uv_frame(p, out, tex_size)
    reach = max(math.sqrt(dot(sub(p.pos[i], c3), sub(p.pos[i], c3))) for t in out for i in t) * 1.15
    chosen = set(out)
    for t in p.tris:
        if t in chosen:
            continue
        u = sum(p.uv[i][0] for i in t) / 3 * W
        v = sum(p.uv[i][1] for i in t) / 3 * H
        if not (bbox[0] <= u <= bbox[2] and bbox[1] <= v <= bbox[3]):
            continue
        _a, _b, _c, fn, area = tri_geometry(p, t)
        if area < 1e-12 or dot(norm(fn), n) < 0.7:
            continue
        if all(math.sqrt(dot(sub(p.pos[i], c3), sub(p.pos[i], c3))) <= reach for i in t):
            out.append(t)
    return out


def clean_transparent(img, rgb=WHITE):
    """Pixels transparentes ficam brancos (evita borda escura nos mipmaps)."""
    a = img.getchannel("A")
    base = Image.new("RGBA", img.size, rgb + (0,))
    base.paste(img, mask=a.point(lambda v: 255 if v > 0 else 0))
    return base


# --- Adesivos como malha (karts sem textura) ---------------------------------------

def add_decal(glb, targets, center, normal, up, width, art, name, offset, depth, min_facing=0.35,
              roughness=0.45):
    """Cola `art` na superfície das primitivas `targets`: copia os triângulos que ficam
    sob o retângulo do adesivo (olhando na direção -normal), afasta-os um pouco da
    superfície e projeta a imagem neles."""
    n = norm(normal)
    up = norm(sub(up, mul(n, dot(up, n))))
    right = cross(up, n)
    height = width * art.height / art.width
    hw, hh = width / 2, height / 2
    pos, nrm, uvs, idx = [], [], [], []
    for p in targets:
        remap = {}
        for t in p.tris:
            a, b, c, fn, area = tri_geometry(p, t)
            if area < 1e-12 or dot(norm(fn), n) < min_facing:
                continue
            local = [sub(p.pos[i], center) for i in t]
            rs = [dot(v, right) for v in local]
            us = [dot(v, up) for v in local]
            ds = [dot(v, n) for v in local]
            if max(rs) < -hw or min(rs) > hw or max(us) < -hh or min(us) > hh:
                continue
            if min(abs(d) for d in ds) > depth:
                continue
            for i, r, u in zip(t, rs, us):
                if i not in remap:
                    vn = p.normals[i] if p.normals else norm(fn)
                    remap[i] = len(pos)
                    pos.append(add(p.pos[i], mul(vn, offset)))
                    nrm.append(vn)
                    uvs.append((0.5 + r / width, 0.5 - u / height))
                idx.append(remap[i])
    assert idx, "adesivo '%s' não achou superfície" % name
    # Adesivos com a mesma arte dividem textura e material.
    cache = glb.__dict__.setdefault("_decal_materials", {})
    if id(art) not in cache:
        small = art.copy()
        small.thumbnail((512, 512), Image.LANCZOS)
        small = pad(small, 6)  # borda transparente (a textura é "clamp")
        tex = glb.add_texture(png_bytes(clean_transparent(small)), clamp=True)
        glb.js["materials"].append({
            "name": "adesivo_" + name,
            "alphaMode": "BLEND",
            "pbrMetallicRoughness": {"baseColorTexture": {"index": tex}, "metallicFactor": 0.0,
                                     "roughnessFactor": roughness},
        })
        cache[id(art)] = (len(glb.js["materials"]) - 1, small.size)
    material, (aw, ah) = cache[id(art)]
    # As UVs foram calculadas para a arte sem a borda: corrige para a arte com borda.
    sx = (aw - 12) / aw
    sy = (ah - 12) / ah
    uvs = [((u - 0.5) * sx + 0.5, (v - 0.5) * sy + 0.5) for u, v in uvs]
    prim = {
        "attributes": {
            "POSITION": glb.add_accessor(pos, "VEC3", minmax=True),
            "NORMAL": glb.add_accessor(nrm, "VEC3"),
            "TEXCOORD_0": glb.add_accessor(uvs, "VEC2"),
        },
        "indices": glb.add_indices(idx),
        "material": material,
    }
    glb.js["meshes"].append({"name": "Adesivo_" + name, "primitives": [prim]})
    glb.add_root_node({"name": "Adesivo_" + name, "mesh": len(glb.js["meshes"]) - 1})


# --- Separar rodas de malhas fundidas ------------------------------------------------

def components(p):
    """Grupos de triângulos conectados (vértices na mesma posição contam como ligados)."""
    parent = list(range(len(p.pos)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    seen = {}
    for i, v in enumerate(p.pos):
        key = (round(v[0], 3), round(v[1], 3), round(v[2], 3))
        if key in seen:
            parent[find(i)] = find(seen[key])
        else:
            seen[key] = i
    for a, b, c in p.tris:
        ra = find(a)
        parent[find(b)] = ra
        parent[find(c)] = ra
    groups = {}
    for t in p.tris:
        groups.setdefault(find(t[0]), []).append(t)
    return list(groups.values())


def compact_prim(glb, prim, tris):
    """Refaz a primitiva só com os triângulos `tris` e os vértices que eles usam."""
    used = sorted({i for t in tris for i in t})
    remap = {old: new for new, old in enumerate(used)}
    new_attrs = {}
    for key, acc in prim["attributes"].items():
        info = glb.js["accessors"][acc]
        vals = glb.read_accessor(acc)
        new_attrs[key] = glb.add_accessor([vals[i] for i in used], info["type"], info["componentType"],
                                          minmax=(key == "POSITION"))
        if info.get("normalized"):
            glb.js["accessors"][new_attrs[key]]["normalized"] = True
    prim["attributes"] = new_attrs
    prim["indices"] = glb.add_indices([remap[i] for t in tris for i in t])


def split_wheels(glb, source_nodes, wheels):
    """Tira das malhas `source_nodes` as peças que ficam dentro de cada roda e cria um nó
    por roda (origem no centro da roda, para girar e esterçar).

    wheels: lista de (nome, centro, raio, meia_largura)."""
    parts = {w[0]: [] for w in wheels}
    kept = []
    for p in prims_named(glb, source_nodes):
        keep = []
        for comp in components(p):
            vs = [p.pos[i] for t in comp for i in t]
            mn = [min(v[k] for v in vs) for k in range(3)]
            mx = [max(v[k] for v in vs) for k in range(3)]
            owner = None
            for name, c, r, hw in wheels:
                if (c[0] - hw <= mn[0] and mx[0] <= c[0] + hw
                        and c[1] - r <= mn[1] and mx[1] <= c[1] + r
                        and c[2] - r <= mn[2] and mx[2] <= c[2] + r):
                    owner = name
                    break
            if owner:
                parts[owner].append((p, comp))
            else:
                keep.extend(comp)
        kept.append((p, keep))
    for name, c, _r, _hw in wheels:
        # Uma superfície por material (cada peça separada seria um draw call a mais).
        by_material = {}
        for p, comp in parts[name]:
            by_material.setdefault(p.prim.get("material"), []).append((p, comp))
        prims = []
        for material, pieces in by_material.items():
            keys = set.intersection(*(set(p.prim["attributes"]) for p, _ in pieces))
            keys = sorted(k for k in keys if k in ("POSITION", "NORMAL", "TANGENT") or k.startswith("TEXCOORD"))
            cols = {k: [] for k in keys}
            idx = []
            for p, comp in pieces:
                used = sorted({i for t in comp for i in t})
                remap = {old: len(cols["POSITION"]) + new for new, old in enumerate(used)}
                vals = {k: glb.read_accessor(p.prim["attributes"][k]) for k in keys}
                for i in used:
                    for k in keys:
                        if k == "POSITION":
                            cols[k].append(sub(p.pos[i], c))
                        elif k == "NORMAL":
                            cols[k].append(norm(xf_dir(p.matrix, vals[k][i])))
                        elif k == "TANGENT":
                            cols[k].append(norm(xf_dir(p.matrix, vals[k][i][:3])) + (vals[k][i][3],))
                        else:
                            cols[k].append(vals[k][i])
                idx.extend(remap[i] for t in comp for i in t)
            acc_type = {"POSITION": "VEC3", "NORMAL": "VEC3", "TANGENT": "VEC4"}
            attrs = {k: glb.add_accessor(v, acc_type.get(k, "VEC2"), minmax=(k == "POSITION"))
                     for k, v in cols.items()}
            prim = {"attributes": attrs, "indices": glb.add_indices(idx)}
            if material is not None:
                prim["material"] = material
            prims.append(prim)
        glb.js["meshes"].append({"name": name, "primitives": prims})
        glb.add_root_node({"name": name, "translation": list(c), "mesh": len(glb.js["meshes"]) - 1})
    # O que sobrou fica na malha original (só com os vértices usados); primitivas
    # vazias saem (e a malha do nó, se ficou sem nenhuma).
    for p, keep in kept:
        if keep:
            compact_prim(glb, p.prim, keep)
        else:
            p.prim["_vazia"] = True
    for node_name in source_nodes:
        node = glb.js["nodes"][glb.find_node(node_name)]
        if "mesh" not in node:
            continue
        mesh = glb.js["meshes"][node["mesh"]]
        mesh["primitives"] = [p for p in mesh["primitives"] if not p.get("_vazia")]
        if not mesh["primitives"]:
            del node["mesh"]


# --- Corrigir UV espelhada num lado -------------------------------------------------

def mirror_uv_island(glb, prim_obj, tris, center_u):
    """Espelha na horizontal (em volta de `center_u`, 0..1) a UV dos triângulos `tris`,
    duplicando os vértices para não mexer nos vizinhos."""
    p = prim_obj
    attrs = p.prim["attributes"]
    data = {k: glb.read_accessor(v) for k, v in attrs.items()}
    used = sorted({i for t in tris for i in t})
    base = len(data["POSITION"])
    remap = {old: base + n for n, old in enumerate(used)}
    for key, vals in data.items():
        for i in used:
            v = vals[i]
            if key == "TEXCOORD_0":
                v = (2 * center_u - v[0], v[1])
            vals.append(v)
    new_attrs = {}
    for key, vals in data.items():
        info = glb.js["accessors"][attrs[key]]
        new_attrs[key] = glb.add_accessor(vals, info["type"], info["componentType"],
                                          minmax=(key == "POSITION"))
        if info.get("normalized"):
            glb.js["accessors"][new_attrs[key]]["normalized"] = True
    p.prim["attributes"] = new_attrs
    tri_set = set(tris)
    idx = []
    for t in p.tris:
        idx.extend(remap[i] for i in t) if t in tri_set else idx.extend(t)
    p.prim["indices"] = glb.add_indices(idx)


def rename(glb, old, new):
    glb.js["nodes"][glb.find_node(old)]["name"] = new


def image(glb, index):
    return Image.open(io.BytesIO(glb.image_bytes(index))).convert("RGBA")


# --- Receitas ------------------------------------------------------------------------

def build_bolido(icon, mark):
    """Kart azul clássico (sem textura). Rodas separadas e adesivos colados."""
    glb = Glb(os.path.join(ORIG, "crash_team_racing_nitro-fueled_kart.glb"))
    # Rodas (centros medidos nos pneus; +X = direita do kart, frente = -Z).
    front_z, rear_z = 175.6, 221.5
    wheels = [
        ("RodaFrenteDir", (29.7, -9.8, front_z), 10.6, 9.6),
        ("RodaFrenteEsq", (-29.7, -9.8, front_z), 10.6, 9.6),
        ("RodaTrasDir", (28.2, -9.3, rear_z), 11.0, 9.6),
        ("RodaTrasEsq", (-28.2, -9.3, rear_z), 11.0, 9.6),
    ]
    split_wheels(glb, ["Object_7", "Object_10", "Object_13", "Object_14", "Object_15",
                       "Object_17", "Object_18", "Object_19"], wheels)
    rename(glb, "Object_12", "Volante")
    # O bico fica sem adesivo (pedido do usuário); o emblema original continua cinza.
    body = prims_named(glb, ["Object_6"])
    seat = prims_named(glb, ["Object_16"])
    icon_sticker = die_cut(icon)
    mark_sticker = die_cut(mark, border=0.1)
    # Laterais, entre as rodas.
    for side, sx in (("dir", 1.0), ("esq", -1.0)):
        add_decal(glb, body, (12.0 * sx, -11.6, 198.5), (sx, 0.0, 0.0), (0.0, 1.0, 0.0), 19.0,
                  mark_sticker, "lateral_" + side, offset=0.12, depth=3.0)
    # Encosto do banco, de costas (é o que a câmera vê de quem vai na frente).
    add_decal(glb, seat, (0.0, 13.5, 212.5), (0.0, 0.25, 1.0), (0.0, 1.0, -0.25), 9.0,
              icon_sticker, "encosto", offset=0.12, depth=3.0)
    return glb


def build_cometa(icon):
    """Kart futurista. O emblema de raio das laterais vira o "at" brilhando."""
    glb = Glb(os.path.join(ORIG, "kartrider_olypios.glb"))
    body = prims_named(glb, ["mesh_15.nr_mat_22.002_0"])[0]
    tex = image(glb, 0)
    W, H = tex.size
    # Ilha do emblema (o disco das duas laterais): UV dentro da caixa e |z| > 0.3.
    box = (466 / 1024, 149 / 1024, 571 / 1024, 268 / 1024)
    island = [t for t in body.tris
              if all(box[0] <= body.uv[i][0] <= box[2] and box[1] <= body.uv[i][1] <= box[3] for i in t)
              and abs(sum(body.pos[i][2] for i in t) / 3) > 0.3]
    us = [body.uv[i][0] for t in island for i in t]
    vs = [body.uv[i][1] for t in island for i in t]
    cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
    size = int(min(max(us) - min(us), max(vs) - min(vs)) * W * 1.04)
    em = glow_emblem(icon, 512).resize((size, size), Image.LANCZOS)
    tex.alpha_composite(em, (round(cu * W - size / 2), round(cv * H - size / 2)))
    glb.set_image(0, png_bytes(tex.convert("RGB")))
    # No lado +Z a UV está espelhada (a logo sairia ao contrário): espelha a ilha.
    mirror_uv_island(glb, body, [t for t in island if sum(body.pos[i][2] for i in t) > 0], cu)
    # O Cometa entra girado +90° (frente = +X no modelo): o lado -Z do modelo é a esquerda.
    for old, new in (("mesh_17.nr", "RodaFrenteEsq"), ("mesh_17.nr.001", "RodaFrenteDir"),
                     ("mesh_19.nr", "RodaTrasEsq"), ("mesh_19.nr.001", "RodaTrasDir")):
        rename(glb, old, new)
    return glb


def build_motoca(icon):
    """Moto. Os emblemas de espada do tanque viram o "at"."""
    glb = Glb(os.path.join(ORIG, "pink_excalibur.glb"))
    overlay = prims_named(glb, ["mesh_11.nr_mat_4.001_0"])[0]
    old = image(glb, 2)
    tex = Image.new("RGBA", old.size, (0, 0, 0, 0))
    # A malha de adesivo do tanque não cobre a parte de baixo do círculo: um adesivo
    # recortado (sem disco) cabe inteiro, sobre o disco vermelho da pintura.
    sticker = die_cut(icon, border=0.09)
    for bb in ((108, 460, 300, 656), (728, 460, 920, 660)):
        tris = tris_on_blob(overlay, old, tex.size, bb)
        tex = paint_logo(tex, overlay, tris, sticker, 0.16, (0.0, 1.0, 0.0),
                         center_uv=((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2), shift=(0.0, 0.012),
                         clip=False)
    glb.set_image(2, png_bytes(clean_transparent(tex)))
    rename(glb, "mesh_13.nr", "RodaFrente")
    rename(glb, "mesh_14.nr", "RodaTras")
    return glb


def build_bugre(icon, mark, mark_white):
    """Buggy. Apaga todos os adesivos e cola as logos da Ativos."""
    glb = Glb(os.path.join(ORIG, "thermal_buggy.glb"))
    overlay = prims_named(glb, ["mesh_4.nr.001_mat_1.005_0"])[0]
    old = image(glb, 3)
    # Mesma resolução do original (1024): em 2048 a textura ocuparia ~22 MB de vídeo.
    tex = Image.new("RGBA", old.size, (0, 0, 0, 0))
    up = (0.0, 1.0, 0.0)
    fwd = (-1.0, 0.0, 0.0)  # frente do buggy no modelo
    icon_sticker = die_cut(icon)
    mark_sticker = die_cut(mark, border=0.1)

    def spot(bbox):
        return tris_on_blob(overlay, old, tex.size, bbox)

    # Laterais (onde ficavam "Crazy Racing" e o painel "KartRider").
    tex = paint_logo(tex, overlay, spot((664, 520, 840, 856)), mark_sticker, 0.5, up)
    tex = paint_logo(tex, overlay, spot((160, 352, 372, 996)), mark_sticker, 0.5, up, shift=(0.03, 0.0))
    # Capô: "at" lido de frente (como o adesivo original).
    tex = paint_logo(tex, overlay, spot((404, 848, 616, 988)), icon_sticker, 0.23, mul(fwd, -1))
    # Asa traseira: faixa escura com a marca branca, lida de trás.
    tex = paint_logo(tex, overlay, spot((244, 16, 784, 128)), white_bar(mark_white, 5.2), 1.0, fwd)
    # Aletas da asa.
    for bbox in ((20, 72, 92, 148), (932, 72, 1004, 148)):
        tex = paint_logo(tex, overlay, spot(bbox), icon_sticker, 0.13, up)
    glb.set_image(3, png_bytes(clean_transparent(tex)))
    for old_name, new in (("mesh_1.nr", "RodaFrenteDir"), ("mesh_1.nr.001", "RodaFrenteEsq"),
                          ("mesh_18.nr", "RodaTrasDir"), ("mesh_18.nr.001", "RodaTrasEsq")):
        rename(glb, old_name, new)
    return glb


def main():
    icon = logo("ativos_icone.png")
    mark = logo("ativos_marca.png")
    mark_white = logo("ativos_marca_branca.png")
    only = set(sys.argv[1:])
    out_dir = OUT
    if "--saida" in only:
        i = sys.argv.index("--saida")
        out_dir = sys.argv[i + 1]
        only -= {"--saida", out_dir}
    jobs = {
        "bolido": lambda: build_bolido(icon, mark),
        "cometa": lambda: build_cometa(icon),
        "motoca": lambda: build_motoca(icon),
        "bugre": lambda: build_bugre(icon, mark, mark_white),
    }
    for name, job in jobs.items():
        if only and name not in only:
            continue
        glb = job()
        glb.compact()
        path = os.path.join(out_dir, name + ".glb")
        glb.save(path)
        print("ok", path, "%.1f MB" % (os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    main()
