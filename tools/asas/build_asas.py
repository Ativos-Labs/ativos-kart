"""Gera a asa-delta do jogo a partir do modelo original (tools/asas/originais/).

    python3 tools/asas/build_asas.py [--saida pasta]

Grava em assets/models/asas/:
  asa_delta.glb   malha estática (sem esqueleto) na escala do jogo: envergadura de
                  SPAN m, frente para -Z, o ponto onde as 4 cordas se juntavam na origem.
                  A vela com a moldura é o nó "Asa"; cada corda é um nó "Corda0".."Corda3"
                  com a origem na ponta de cima (o jogo estica as cordas até a carroceria
                  do kart). Sem textura: o jogo põe a de cada asa.
  <asa>.png       textura de cada asa (atlas 1024x512, veja abaixo).

O original tem uma vela de duas camadas (a de cima virada para cima, a de baixo para
baixo) que usam o mesmo pedaço da textura. Aqui a textura vira um atlas com duas
metades iguais: a camada de cima lê a metade esquerda e a de baixo a direita. Assim
cada lado da vela tem a sua pintura e o desenho nunca aparece espelhado:
  - de cima (quem olha por cima e por trás): o "para cima" do desenho aponta para a
    frente da asa;
  - de baixo (a câmera da corrida, atrás e abaixo da vela): o "para cima" do desenho
    aponta para trás (a borda de trás da vela fica no alto da tela).

Cada asa nova troca as faixas da borda e o emblema do meio da vela (que vira o desenho
dela) e recolore a moldura de madeira, as amarrações e as cordas. A vela é pintada
pela posição 3D de cada pixel (baricêntricas dos triângulos no espaço UV), então o
desenho não deforma com o mapeamento.

O Godot ignora esta pasta (tools/.gdignore). Precisa só do Pillow.
"""
import argparse
import colorsys
import math
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "tools", "karts"))
from gltf_util import Glb, cross, sub  # noqa: E402

ORIGINAL = os.path.join(AQUI, "originais", "paraglider.glb")
TEXTURA_ORIGINAL = os.path.join(AQUI, "originais", "paraglider_textura.png")
SAIDA = os.path.join(RAIZ, "assets", "models", "asas")
## Envergadura da asa no jogo (m). Um kart tem ~1,5 m de largura.
SPAN = 3.0
## Lado de cada metade do atlas (a textura original tem 512).
HALF = 512

# Paleta da vela original (sRGB), achada por k-means nos pixels da vela.
PAL_BASE = (74, 32, 32)
PAL_EMBLEMA = (153, 133, 101)
PAL_VERDE = (24, 62, 41)
PAL_OURO = (105, 76, 0)
PAL_ESCURO = (8, 4, 4)


# --- Malha -------------------------------------------------------------------------

def carregar():
    """Lê o original e devolve (glb, posições assadas em metros, normais, uvs, triângulos)."""
    g = Glb(ORIGINAL)
    js = g.js
    prim = js["meshes"][0]["primitives"][0]
    pos = g.read_accessor(prim["attributes"]["POSITION"])
    nrm = g.read_accessor(prim["attributes"]["NORMAL"])
    uv = g.read_accessor(prim["attributes"]["TEXCOORD_0"])
    idx = [i[0] for i in g.read_accessor(prim["indices"])]
    # Pose do esqueleto = pose de ligação: cada vértice vale (osso × inversa) × v,
    # pesado pelos ossos dele. No original os 3 ossos dão a mesma escala 0,0254.
    world = g.world_matrices()
    skin = js["skins"][0]
    ibm = g.read_accessor(skin["inverseBindMatrices"])
    mats = []
    for ji, j in enumerate(skin["joints"]):
        m = [[ibm[ji][c * 4 + r] for c in range(4)] for r in range(4)]
        w = world[j]
        mats.append([[sum(w[i][k] * m[k][jj] for k in range(4)) for jj in range(4)] for i in range(4)])
    joints = g.read_accessor(prim["attributes"]["JOINTS_0"], raw=True)
    weights = g.read_accessor(prim["attributes"]["WEIGHTS_0"])
    baked = []
    normals = []
    for i, p in enumerate(pos):
        acc = [0.0, 0.0, 0.0]
        nacc = [0.0, 0.0, 0.0]
        for j, w in zip(joints[i], weights[i]):
            if w <= 0.0:
                continue
            m = mats[j]
            for r in range(3):
                acc[r] += w * (m[r][0] * p[0] + m[r][1] * p[1] + m[r][2] * p[2] + m[r][3])
                nacc[r] += w * (m[r][0] * nrm[i][0] + m[r][1] * nrm[i][1] + m[r][2] * nrm[i][2])
        baked.append(tuple(acc))
        ln = math.sqrt(sum(c * c for c in nacc)) or 1.0
        normals.append(tuple(c / ln for c in nacc))
    tris = [tuple(idx[i:i + 3]) for i in range(0, len(idx), 3)]
    return g, baked, normals, uv, tris


def componentes(pos, tris):
    """Agrupa os triângulos em peças (vértices na mesma posição = mesma peça)."""
    parent = {}

    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    key = lambda v: tuple(round(c, 6) for c in pos[v])
    for t in tris:
        ks = [key(v) for v in t]
        for k in ks[1:]:
            parent[find(k)] = find(ks[0])
    out = {}
    for ti, t in enumerate(tris):
        out.setdefault(find(key(t[0])), []).append(ti)
    return list(out.values())


def separar_vela(pos, tris):
    """Índices dos triângulos das duas camadas da vela: (de cima, de baixo)."""
    cima, baixo = [], []
    for comp in componentes(pos, tris):
        xs = [pos[v][0] for ti in comp for v in tris[ti]]
        zs = [pos[v][2] for ti in comp for v in tris[ti]]
        # A vela vai de ponta a ponta da envergadura e fica atrás da longarina da
        # frente (a peça de madeira que também vai de ponta a ponta tem z > 0,1).
        if max(xs) - min(xs) < 0.5 or max(zs) > 0.12 or len(comp) < 20:
            continue
        ny = sum(cross(sub(pos[tris[ti][1]], pos[tris[ti][0]]), sub(pos[tris[ti][2]], pos[tris[ti][0]]))[1] for ti in comp)
        (cima if ny > 0.0 else baixo).extend(comp)
    assert cima and baixo, "não achei as duas camadas da vela"
    return cima, baixo


def separar_cordas(pos, tris):
    """As 4 cordas (peças finas e compridas de 3 triângulos que descem da vela)."""
    cordas = []
    for comp in componentes(pos, tris):
        ys = [pos[v][1] for ti in comp for v in tris[ti]]
        if len(comp) <= 4 and max(ys) - min(ys) > 0.15:
            cordas.append(comp)
    assert len(cordas) == 4, "esperava 4 cordas, achei %d" % len(cordas)
    return cordas


def gerar_malha(saida):
    g, pos, nrm, uv, tris = carregar()
    cima, baixo = separar_vela(pos, tris)
    baixo_set = set(baixo)
    cordas = separar_cordas(pos, tris)
    corda_set = {ti for c in cordas for ti in c}
    # Frente da asa = borda larga com a longarina (+Z no original). No Godot a frente
    # é -Z: gira 180° em Y. O nó das cordas (vértice mais baixo) vai para a origem.
    # O nó fica em x = 0 (as cordas se juntam no meio da envergadura).
    low = min(range(len(pos)), key=lambda i: pos[i][1])
    ly, lz = pos[low][1], -pos[low][2]
    span = max(p[0] for p in pos) - min(p[0] for p in pos)
    k = SPAN / span

    def xf(p):
        return (-p[0] * k, (p[1] - ly) * k, (-p[2] - lz) * k)

    js = g.js
    js["accessors"] = []
    g.views = []
    js["bufferViews"] = []

    def malha(nome, lista, origem=(0.0, 0.0, 0.0)):
        """Uma malha com os triângulos `lista`, vértices relativos a `origem`. Os
        vértices são duplicados por metade do atlas (a camada de baixo da vela lê a
        metade direita)."""
        out_pos, out_nrm, out_uv, out_idx = [], [], [], []
        remap = {}
        for ti in lista:
            half = 1 if ti in baixo_set else 0
            for v in tris[ti]:
                keyv = (v, half)
                if keyv not in remap:
                    remap[keyv] = len(out_pos)
                    p = xf(pos[v])
                    out_pos.append((p[0] - origem[0], p[1] - origem[1], p[2] - origem[2]))
                    n = nrm[v]
                    out_nrm.append((-n[0], n[1], -n[2]))
                    out_uv.append((uv[v][0] * 0.5 + 0.5 * half, uv[v][1]))
                out_idx.append(remap[keyv])
        js["meshes"].append({"name": nome, "primitives": [{
            "attributes": {"POSITION": g.add_accessor(out_pos, "VEC3", minmax=True),
                           "NORMAL": g.add_accessor(out_nrm, "VEC3"),
                           "TEXCOORD_0": g.add_accessor(out_uv, "VEC2")},
                "indices": g.add_indices(out_idx), "material": 0, "mode": 4}]})
        return len(js["meshes"]) - 1, len(out_idx) // 3

    js["meshes"] = []
    js["nodes"] = []
    # A vela e a moldura (tudo menos as cordas).
    corpo, n_corpo = malha("Asa", [ti for ti in range(len(tris)) if ti not in corda_set])
    js["nodes"].append({"name": "Asa", "mesh": corpo})
    # Cada corda numa malha própria, com a origem na ponta de cima (onde ela prende na
    # vela): o jogo estica a corda até um ponto do kart (GliderVisual).
    for i, comp in enumerate(cordas):
        pts = [xf(pos[v]) for ti in comp for v in tris[ti]]
        topo = max(pts, key=lambda p: p[1])
        mi, _ = malha("Corda", comp, topo)
        js["nodes"].append({"name": "Corda%d" % i, "mesh": mi, "translation": list(topo)})
    js["materials"] = [{"name": "Asa", "doubleSided": True,
                        "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}}]
    js["scenes"] = [{"name": "Asa", "nodes": list(range(len(js["nodes"])))}]
    js["scene"] = 0
    for key in ("skins", "images", "textures", "samplers", "animations"):
        js.pop(key, None)
    js["asset"] = {"version": "2.0", "generator": "tools/asas/build_asas.py", "extras": g.js["asset"].get("extras", {})}
    g.save(os.path.join(saida, "asa_delta.glb"))

    # Para pintar: triângulos de cada camada em pixels do atlas e em 3D (já no jogo).
    def camada(lista, half):
        out = []
        for ti in lista:
            t = tris[ti]
            uvp = [((uv[v][0] * 0.5 + 0.5 * half) * HALF * 2, uv[v][1] * HALF) for v in t]
            out.append((uvp, [xf(pos[v]) for v in t]))
        return out

    print("asa_delta.glb: %d triângulos na vela e moldura + 4 cordas, envergadura %.2f m, altura %.2f m" % (
        n_corpo, SPAN, max(xf(p)[1] for p in pos)))
    return camada(cima, 0), camada(baixo, 1)


# --- Textura ------------------------------------------------------------------------

def rasterizar(tris_uv3d, w, h, folga=1.5):
    """{(x, y): posição 3D} dos pixels cobertos pelos triângulos (com uma folga de
    `folga` px em volta, para o mipmap não puxar a cor velha da borda)."""
    out = {}
    for uvp, p3 in tris_uv3d:
        (x0, y0), (x1, y1), (x2, y2) = uvp
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        # Folga em baricêntricas: ~folga px nas bordas.
        per = math.sqrt(abs(den))
        e = folga / max(per, 1.0)
        xs, ys = (x0, x1, x2), (y0, y1, y2)
        for y in range(max(int(min(ys) - folga), 0), min(int(max(ys) + folga) + 1, h)):
            for x in range(max(int(min(xs) - folga), 0), min(int(max(xs) + folga) + 1, w)):
                px, py = x + 0.5, y + 0.5
                a = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
                b = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
                c = 1.0 - a - b
                if a < -e or b < -e or c < -e:
                    continue
                inside = a >= 0 and b >= 0 and c >= 0
                if not inside and (x, y) in out:
                    continue
                aa, bb, cc = max(a, 0), max(b, 0), max(c, 0)
                s = aa + bb + cc
                aa, bb, cc = aa / s, bb / s, cc / s
                out[(x, y)] = tuple(aa * p3[0][i] + bb * p3[1][i] + cc * p3[2][i] for i in range(3))
    return out


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def pesos_paleta(c):
    """Quanto o pixel da vela original é de cada cor da paleta (soma 1)."""
    pal = (PAL_BASE, PAL_EMBLEMA, PAL_VERDE, PAL_OURO, PAL_ESCURO)
    ws = []
    for p in pal:
        d2 = sum((c[i] - p[i]) ** 2 for i in range(3))
        ws.append(math.exp(-d2 / (2 * 22.0 ** 2)))
    s = sum(ws)
    if s < 1e-6:
        # Longe de todas: vale a mais perto.
        k = min(range(len(pal)), key=lambda i: sum((c[j] - pal[i][j]) ** 2 for j in range(3)))
        return [1.0 if i == k else 0.0 for i in range(len(pal))]
    return [w / s for w in ws]


def classe_peca(c):
    """Classe de um pixel fora da vela: 'madeira', 'azul' (amarrações e cordas),
    'bege' (tiras amarradas) ou None (preto e o resto, fica igual)."""
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    h *= 360
    if v < 0.06:
        return None
    if 185 <= h <= 230 and s > 0.45:
        return "azul"
    if s < 0.32 and v > 0.38:
        return "bege"
    if 8 <= h <= 48 and s >= 0.25:
        return "madeira"
    return None


MEDIAS = {"madeira": 88.0, "azul": 32.0, "bege": 150.0}


def recolorir_peca(c, classe, cores):
    alvo = cores.get(classe)
    if alvo is None:
        return c
    # Mantém o sombreado e os veios: brilho relativo à média da classe.
    rel = lum(c) / MEDIAS[classe]
    rel = 0.55 + 0.45 * min(max(rel, 0.2), 1.8)
    return tuple(min(255.0, alvo[i] * rel) for i in range(3))


def coords_desenho(p3, lado, vela):
    """(u, v) do desenho num ponto 3D da vela: u de -1 (esquerda de quem olha) a 1,
    v de 0 (base do desenho) a `vela['prof']` (topo), na mesma escala de u."""
    half_span = vela["half_span"]
    u = p3[0] / half_span
    if lado == 0:
        # De cima: o topo do desenho fica na frente da asa (-Z).
        v = (vela["z_tras"] - p3[2]) / half_span
    else:
        # De baixo, olhando por trás: o topo do desenho fica na borda de trás (+Z).
        v = (p3[2] - vela["z_frente"]) / half_span
    return u, v


def pintar(base, camadas, vela, estilo):
    img = base.copy()
    px = img.load()
    w, h = img.size
    masks = [rasterizar(cam, w, h) for cam in camadas]
    vela_px = set(masks[0]) | set(masks[1])
    # Peças (moldura, amarrações, cordas): fora da vela, nas duas metades.
    for y in range(h):
        for x in range(w):
            if (x, y) in vela_px:
                continue
            c = px[x, y][:3]
            cl = classe_peca(c)
            if cl:
                px[x, y] = tuple(int(round(v)) for v in recolorir_peca(c, cl, estilo["pecas"])) + (255,)
    orig = base.load()
    for lado, mask in enumerate(masks):
        for (x, y), p3 in mask.items():
            c = orig[x, y][:3]
            wb, we, wv, wo, wd = pesos_paleta(c)
            u, v = coords_desenho(p3, lado, vela)
            desenho = estilo["desenho"](u, v, vela)
            # Contorno escuro do emblema original some (vira desenho); só o contorno
            # perto das faixas fica (as faixas vêm escuras nas bordas).
            perto_faixa = wv + wo > 0.02
            if not perto_faixa:
                we, wb, wd = we + wd, wb, 0.0
            col = [0.0, 0.0, 0.0]
            for wgt, cor in ((wb + we, desenho), (wv, estilo["faixa_verde"]), (wo, estilo["faixa_ouro"]),
                             (wd, estilo["contorno"])):
                for i in range(3):
                    col[i] += wgt * cor[i]
            px[x, y] = tuple(int(round(min(max(cc, 0), 255))) for cc in col) + (255,)
    return img


# --- Desenhos -------------------------------------------------------------------------

def _logo_ativos():
    logo = Image.open(os.path.join(RAIZ, "assets", "logos", "ativos_icone.png")).convert("RGBA")
    return logo, logo.load()


_LOGO = None


def amostra_logo(lu, lv):
    """Cor e alfa do logo "at" em (lu, lv) de 0 a 1 (lv = 0 no topo)."""
    global _LOGO
    if _LOGO is None:
        _LOGO = _logo_ativos()
    img, px = _LOGO
    if not (0.0 <= lu < 1.0 and 0.0 <= lv < 1.0):
        return None, 0.0
    # Bilinear simples.
    fx, fy = lu * (img.width - 1), lv * (img.height - 1)
    x0, y0 = int(fx), int(fy)
    x1, y1 = min(x0 + 1, img.width - 1), min(y0 + 1, img.height - 1)
    tx, ty = fx - x0, fy - y0
    acc = [0.0] * 4
    for (xx, yy, ww) in ((x0, y0, (1 - tx) * (1 - ty)), (x1, y0, tx * (1 - ty)), (x0, y1, (1 - tx) * ty), (x1, y1, tx * ty)):
        c = px[xx, yy]
        for i in range(4):
            acc[i] += c[i] * ww
    return tuple(acc[:3]), acc[3] / 255.0


AZUL_ATIVOS = (38, 61, 191)
AMARELO = (255, 206, 26)
BRANCO = (246, 247, 252)


def desenho_ativos(u, v, vela):
    meio = vela["prof"] * 0.5
    # Fundo: azul Ativos, um pouco mais claro no meio da vela.
    d = math.hypot(u, (v - meio) * 1.3)
    cor = mix(AZUL_ATIVOS, (58, 92, 222), smooth(1.1, 0.0, d) * 0.6)
    # Logo "at" no meio (o azul do logo vira branco e a setinha, amarela).
    lw = 1.08
    lh = lw / 1.643
    lu = (u + lw * 0.5) / lw
    lv = (meio + lh * 0.5 - v) / lh
    c, a = amostra_logo(lu, lv)
    if a > 0.0:
        claro = smooth(110, 160, lum(c))  # a seta do logo é mais clara que o resto
        cor = mix(cor, mix(BRANCO, AMARELO, claro), a)
    return cor


def desenho_bandeirada(u, v, vela):
    meio = vela["prof"] * 0.5
    # Quadriculado de chegada, um pouco ondulado (bandeira tremulando).
    lado = 0.19
    uu = u + 0.025 * math.sin(v * 9.0)
    vv = v + 0.02 * math.sin(u * 7.0)
    par = (math.floor(uu / lado) + math.floor((vv - meio) / lado)) % 2
    # Bordas dos quadrados suavizadas (meio pixel do atlas ~ 0,004).
    fu = abs(((uu / lado) % 1.0) - 0.5)
    fv = abs((((vv - meio) / lado) % 1.0) - 0.5)
    borda = min(smooth(0.5, 0.47, fu), smooth(0.5, 0.47, fv))
    claro, escuro = (238, 238, 236), (24, 24, 28)
    cor = mix(escuro, claro, par)
    cor = mix(mix(escuro, claro, 0.5), cor, borda)
    # Medalhão no meio: disco vermelho com aro branco e estrela branca.
    du, dv = u, v - meio
    r = math.hypot(du, dv)
    if r < 0.36:
        aro = smooth(0.33, 0.345, r) * (1.0 - smooth(0.355, 0.36, r))
        cor = mix(VERMELHO, BRANCO, aro) if r > 0.30 else VERMELHO
        if r > 0.30:
            cor = mix(mix(VERMELHO, BRANCO, smooth(0.30, 0.31, r)), escuro, smooth(0.355, 0.36, r))
        if estrela(du, dv, 0.24):
            cor = BRANCO
    return cor


VERMELHO = (214, 36, 40)


def estrela(x, y, raio):
    """Ponto dentro de uma estrela de 5 pontas (ponta para cima)."""
    ang = math.atan2(x, y)  # 0 = para cima
    r = math.hypot(x, y)
    setor = (ang % (2 * math.pi / 5)) / (2 * math.pi / 5)
    # Raio da borda: interpola entre a ponta e o vale (forma de estrela).
    interno = raio * 0.42
    t = abs(setor - 0.5) * 2.0  # 1 na ponta, 0 no vale
    lim = interno + (raio - interno) * (t ** 1.6)
    return r < lim


def desenho_por_do_sol(u, v, vela):
    prof = vela["prof"]
    t = min(max(v / prof, 0.0), 1.0)
    # Céu: laranja no horizonte (base do desenho), rosa e roxo no alto.
    if t < 0.5:
        ceu = mix((255, 128, 36), (238, 66, 112), t / 0.5)
    else:
        ceu = mix((238, 66, 112), (104, 38, 138), (t - 0.5) / 0.5)
    # Raios de sol saindo do horizonte.
    ang = math.atan2(u, v + 0.08)
    raio = 0.5 + 0.5 * math.cos(ang * 18.0)
    cor = mix(ceu, mix(ceu, (255, 236, 160), 0.35), smooth(0.55, 0.62, raio) * (1.0 - t * 0.6))
    # Sol: meio disco amarelo no horizonte, com as faixas horizontais vazadas.
    r = math.hypot(u, v + 0.08)
    if r < 0.62:
        sol = mix((255, 230, 96), (255, 160, 48), min(max(v / 0.55, 0.0), 1.0) * 0.0 + (1.0 - min(max((v + 0.08) / 0.7, 0.0), 1.0)) * 0.7)
        k = smooth(0.62, 0.605, r)
        faixa = 1.0
        if v < 0.32:
            # Faixas que afinam para o alto (estilo "sol retrô").
            per = 0.075
            fase = (v / per) % 1.0
            largura = 0.42 * (1.0 - v / 0.32)
            faixa = smooth(largura - 0.04, largura + 0.04, fase)
        cor = mix(cor, sol, k * faixa)
    # Gaivotas (dois "v" escuros) no alto.
    for (gu, gv, gs) in ((-0.48, prof * 0.74, 0.07), (-0.3, prof * 0.82, 0.05), (0.5, prof * 0.7, 0.06)):
        dx, dy = (u - gu) / gs, (v - gv) / gs
        if abs(dx) < 1.0:
            curva = 0.35 * (abs(dx) ** 0.8) - 0.1
            if abs(dy - curva) < 0.12 * (1.0 - abs(dx) * 0.6):
                cor = mix(cor, (60, 20, 70), 0.9)
    return cor


ESTILOS = {
    "asa_ativos": {
        "desenho": desenho_ativos,
        "faixa_verde": (120, 196, 255),
        "faixa_ouro": AMARELO,
        "contorno": (14, 22, 58),
        # Moldura pintada de branco, amarrações amarelas e cordas, tiras cinza-azuladas.
        "pecas": {"madeira": (228, 232, 242), "azul": (255, 200, 30), "bege": (196, 206, 228)},
    },
    "bandeirada": {
        "desenho": desenho_bandeirada,
        "faixa_verde": (246, 246, 246),
        "faixa_ouro": VERMELHO,
        "contorno": (18, 18, 20),
        # Moldura de metal escuro, amarrações vermelhas, tiras brancas.
        "pecas": {"madeira": (92, 96, 108), "azul": (220, 40, 44), "bege": (236, 236, 236)},
    },
    "por_do_sol": {
        "desenho": desenho_por_do_sol,
        "faixa_verde": (52, 186, 176),
        "faixa_ouro": (255, 196, 70),
        "contorno": (52, 14, 60),
        # Madeira mais escura e avermelhada, amarrações roxas, tiras creme.
        "pecas": {"madeira": (128, 66, 44), "azul": (126, 52, 160), "bege": (252, 226, 186)},
    },
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("nomes", nargs="*", help="asas a gerar (padrão: todas)")
    ap.add_argument("--saida", default=SAIDA)
    args = ap.parse_args()
    os.makedirs(args.saida, exist_ok=True)
    camadas = gerar_malha(args.saida)
    # Medidas da vela (já na escala do jogo) para os desenhos.
    pts = [p for cam in camadas for _, p3 in cam for p in p3]
    zs = [p[2] for p in pts]
    xs = [abs(p[0]) for p in pts]
    vela = {"half_span": max(xs), "z_frente": min(zs), "z_tras": max(zs)}
    vela["prof"] = (vela["z_tras"] - vela["z_frente"]) / vela["half_span"]

    orig = Image.open(TEXTURA_ORIGINAL).convert("RGBA").resize((HALF, HALF), Image.LANCZOS)
    base = Image.new("RGBA", (HALF * 2, HALF))
    base.paste(orig, (0, 0))
    base.paste(orig, (HALF, 0))
    nomes = args.nomes or ["asa_rubra"] + list(ESTILOS)
    for nome in nomes:
        destino = os.path.join(args.saida, nome + ".png")
        if nome == "asa_rubra":
            img = base
        else:
            img = pintar(base, camadas, vela, ESTILOS[nome])
        img.convert("RGB").save(destino, optimize=True)
        print(destino)


if __name__ == "__main__":
    main()
