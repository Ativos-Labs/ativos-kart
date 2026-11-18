"""Dá um esqueleto ao Henrique (o modelo veio do Blender sem esqueleto e sem animações).

Lê tools/personagens/originais/henrique-piloto.glb (só malhas, em pose T) e grava
tools/personagens/henrique_esqueleto.json: o esqueleto do Jarbas (mesmos 68 ossos,
mesmos nomes) ajustado ao corpo do Henrique e os pesos de cada vértice de cada malha.
O build_personagem.py junta esse arquivo ao modelo original; daí para a frente o
Henrique segue o caminho do Jarbas (veja o README desta pasta). Só este passo precisa
do Blender.

Como o esqueleto é montado (tudo no espaço do glTF: +Y para cima, +Z para a frente,
+X = esquerda do personagem):

- Cada articulação do Jarbas (assets/models/personagens/jarbas.glb) vai para o lugar
  equivalente no corpo do Henrique. Alturas: interpolação entre pontos medidos nos dois
  corpos (chão, entreperna, eixo dos braços, boca, olhos). Dentro do corpo: a mesma
  posição relativa no corte da perna, do tronco ou do braço naquela altura.
- Mãos e dedos: as luvas do Henrique são a malha das luvas do Jarbas com outra escala e
  um giro pequeno (medidos vértice a vértice), então os ossos da mão vão junto.
- Rosto: olhos e pálpebras no centro de cada globo ocular; boca, mandíbula e
  sobrancelhas pela posição relativa a olhos e boca.
- Cada osso aponta (eixo Y) para a articulação seguinte, como no Blender; os outros
  eixos ficam o mais perto possível dos do Jarbas. Assim as animações do Jarbas
  (expressões, piscada, poses sentadas) passam para o Henrique quase sem conversão.

Pesos:
- corpo: pesos automáticos do Blender (bone heat), calculados por blender_pesos.py
  numa cópia da malha com os vértices repetidos juntados;
- rosto: mandíbula (tudo abaixo da fenda da boca, até o pescoço), lábios, cantos da
  boca e sobrancelhas com raio de influência, como os do Jarbas;
- luvas: os pesos das luvas do Jarbas, vértice a vértice;
- olhos, pálpebras, dentes e língua: presos ao osso deles;
- logos: os pesos do ponto mais próximo do corpo.

Uso (precisa de numpy; o Python do Blender tem):
  /Applications/Blender.app/Contents/Resources/5.3/python/bin/python3.13 tools/personagens/rig_henrique.py
Variável BLENDER: caminho do executável do Blender (padrão: /Applications/Blender.app).
Com --debug grava também as articulações em $TMPDIR/henrique-esqueleto-debug.json;
--only-skeleton para antes dos pesos.
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "karts"))
from gltf_util import Glb  # noqa: E402

PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "originais", "henrique-piloto.glb")
JARBAS = os.path.join(PROJ, "assets", "models", "personagens", "jarbas.glb")
DST = os.path.join(HERE, "henrique_esqueleto.json")
DEBUG_OUT = os.path.join(tempfile.gettempdir(), "henrique-esqueleto-debug.json")
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
HEAT_SCRIPT = os.path.join(HERE, "blender_pesos.py")

SIDES = (("L", "Left", 1.0), ("R", "Right", -1.0))
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")
FACE = ("Canto_Boca.L", "Canto_Boca.R", "Labio_Sup", "Labio_Inf", "Mandibula", "Olho.L", "Olho.R",
        "Palpebra_Inf.L", "Palpebra_Inf.R", "Palpebra_Sup.L", "Palpebra_Sup.R",
        "Sobrancelha_Ext.L", "Sobrancelha_Ext.R", "Sobrancelha_Int.L", "Sobrancelha_Int.R")
## Ossos com peso automático no corpo (o resto: rosto, dedos e raiz).
HEAT_BONES = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"] + [
    side + b for side in ("Left", "Right")
    for b in ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase")]


# --- Leitura -------------------------------------------------------------------------------

class Part:
    """Uma malha do glTF: posições e triângulos de todas as primitivas, em sequência."""

    def __init__(self, g, name):
        js = g.js
        self.node = next(i for i, n in enumerate(js["nodes"]) if n.get("name") == name and "mesh" in n)
        mesh = js["meshes"][js["nodes"][self.node]["mesh"]]
        world = np.array(g.world_matrices()[self.node])
        self.prims = mesh["primitives"]
        self.materials = {i: m.get("name", "") for i, m in enumerate(js.get("materials", []))}
        P, T, prim = [], [], []
        off = 0
        for k, p in enumerate(self.prims):
            pos = np.array(g.read_accessor(p["attributes"]["POSITION"]))
            pos = pos @ world[:3, :3].T + world[:3, 3]
            idx = np.array([i[0] for i in g.read_accessor(p["indices"])]).reshape(-1, 3)
            P.append(pos)
            T.append(idx + off)
            prim += [k] * len(pos)
            off += len(pos)
        self.P = np.concatenate(P)
        self.T = np.concatenate(T)
        self.prim = np.array(prim)
        self.offsets = np.cumsum([0] + [len(x) for x in P])

    def range(self, k):
        return slice(self.offsets[k], self.offsets[k + 1])

    def material_prim(self, name):
        return next(k for k, p in enumerate(self.prims)
                    if self.materials[p.get("material", -1)] == name)


def merge_ids(P, tol=1e-5):
    """Índice do vértice "juntado" (mesma posição) de cada vértice."""
    key = np.round(P / tol).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    return inv.ravel()


def components(P, T):
    inv = merge_ids(P)
    parent = np.arange(inv.max() + 1)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for t in inv[T]:
        a = find(t[0])
        parent[find(t[1])] = a
        parent[find(t[2])] = a
    return np.array([find(i) for i in inv])


def section(P, T, axis, level):
    """Pontos onde as arestas dos triângulos cruzam o plano coord[axis] = level."""
    V = P[T]
    d = V[:, :, axis] - level
    out = []
    for a, b in ((0, 1), (1, 2), (2, 0)):
        da, db = d[:, a], d[:, b]
        m = (da * db) < 0
        t = da[m] / (da[m] - db[m])
        out.append(V[m, a] + (V[m, b] - V[m, a]) * t[:, None])
    return np.concatenate(out)


def sphere_fit(P):
    A = np.c_[2 * P, np.ones(len(P))]
    b = (P ** 2).sum(1)
    c, *_ = np.linalg.lstsq(A, b, rcond=None)
    center = c[:3]
    return center, float(np.sqrt(c[3] + center @ center))


def umeyama(a, b):
    """Escala, giro e translação que levam os pontos `a` para `b` (mínimos quadrados)."""
    ma, mb = a.mean(0), b.mean(0)
    A, B = a - ma, b - mb
    U, S, Vt = np.linalg.svd(B.T @ A / len(a))
    D = np.diag([1.0, 1.0, np.sign(np.linalg.det(U @ Vt))])
    R = U @ D @ Vt
    s = (S * np.diag(D)).sum() / (A ** 2).sum() * len(a)
    return s, R, mb - s * R @ ma


def rot_between(a, b):
    """Menor giro que leva a direção `a` para `b`."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(a @ b)
    if c > 1 - 1e-12:
        return np.eye(3)
    if c < -1 + 1e-12:
        axis = np.cross(a, [1, 0, 0] if abs(a[0]) < 0.9 else [0, 1, 0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + K + K @ K / (1 + c)


# --- Pontos de referência do corpo -----------------------------------------------------------

class Body:
    """Medidas de um corpo em pose T (malha do corpo, sem luvas)."""

    def __init__(self, P, T, wrist_l, wrist_r):
        self.P, self.T = P, T
        mid = P[(np.abs(P[:, 0]) < 0.004) & (P[:, 1] > 0.15)]
        self.crotch = float(mid[:, 1].min())
        self.wrist = {1.0: wrist_l, -1.0: wrist_r}
        # Eixo de cada braço: centro dos cortes x = constante entre o meio do braço e o
        # punho (perto do tronco o corte pega o tronco também).
        self.arm = {}
        for sg in (1.0, -1.0):
            w = self.wrist[sg]
            xs = np.linspace(abs(w[0]) * 0.55, abs(w[0]) - 0.03, 8)
            centers = []
            for x in xs:
                pts = section(P, T, 0, sg * x)
                pts = pts[(np.abs(pts[:, 1] - w[1]) < 0.09) & (np.abs(pts[:, 2] - w[2]) < 0.12)]
                lo, hi = pts.min(0), pts.max(0)
                centers.append([sg * x, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, hi[1] - lo[1], hi[2] - lo[2]])
            c = np.array(centers)
            # Reta y(x), z(x) e espessura média.
            fy = np.polyfit(c[:, 0], c[:, 1], 1)
            fz = np.polyfit(c[:, 0], c[:, 2], 1)
            self.arm[sg] = (fy, fz, float(c[:, 3].mean()), float(c[:, 4].mean()))
        arm_bottom = np.polyval(self.arm[1.0][0], abs(wrist_l[0]) * 0.55) - self.arm[1.0][2] / 2
        # Lateral do tronco logo abaixo da axila.
        pts = section(P, T, 1, arm_bottom - 0.015)
        pts = pts[np.abs(pts[:, 0]) < abs(wrist_l[0]) * 0.5]
        self.torso_edge = float(np.abs(pts[:, 0]).max())
        self.arm_y = float(np.polyval(self.arm[1.0][0], self.torso_edge))

    def arm_point(self, sg, x):
        fy, fz, _, _ = self.arm[sg]
        return np.array([x, np.polyval(fy, x), np.polyval(fz, x)])

    def leg(self, sg, y):
        """Centro e tamanho (x, z) do corte da perna `sg` na altura y."""
        pts = section(self.P, self.T, 1, y)
        pts = pts[pts[:, 0] * sg > 0.004]
        lo, hi = pts.min(0), pts.max(0)
        return np.array([(lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2]), np.array([hi[0] - lo[0], hi[2] - lo[2]])

    def depth(self, y, half=0.015):
        """Costas e frente (z) do tronco no meio do corpo, na altura y."""
        pts = section(self.P, self.T, 1, y)
        pts = pts[np.abs(pts[:, 0]) < half]
        return float(pts[:, 2].min()), float(pts[:, 2].max())

    def foot(self, sg):
        """Caixa do sapato `sg`: (x min, x max), (z trás, z frente), altura do topo."""
        P = self.P
        sel = (P[:, 0] * sg > 0.0) & (P[:, 1] < self.crotch * 0.3)
        q = P[sel]
        return q


def piecewise(x, xs, ys):
    return float(np.interp(x, xs, ys, left=None, right=None)) if xs[0] <= x <= xs[-1] else \
        float(ys[0] + (x - xs[0]) * (ys[1] - ys[0]) / (xs[1] - xs[0])) if x < xs[0] else \
        float(ys[-1] + (x - xs[-1]) * (ys[-1] - ys[-2]) / (xs[-1] - xs[-2]))


# --- Esqueleto -----------------------------------------------------------------------------

class Skeleton:
    """Esqueleto lido de um glb com skin (o do Jarbas)."""

    def __init__(self, g):
        js = g.js
        W = g.world_matrices()
        skin = js["skins"][0]
        self.joints = skin["joints"]
        self.names = [js["nodes"][j]["name"] for j in self.joints]
        node_to_slot = {j: k for k, j in enumerate(self.joints)}
        self.parent = []
        for j in self.joints:
            par = [k for k, n in enumerate(js["nodes"]) if j in n.get("children", [])]
            self.parent.append(node_to_slot.get(par[0], -1) if par else -1)
        self.world = {self.names[k]: np.array(W[j]) for k, j in enumerate(self.joints)}

    def pos(self, name):
        return self.world[name][:3, 3]

    def basis(self, name):
        m = self.world[name][:3, :3]
        return m / np.linalg.norm(m, axis=0)

    def parent_name(self, name):
        p = self.parent[self.names.index(name)]
        return self.names[p] if p >= 0 else None


def build_skeleton(jb, jbody, hbody, h_parts, glove_xf):
    """Posições (espaço do glTF) das articulações do Henrique, por nome."""
    J = {n: jb.pos(n) for n in jb.names}
    H = {}
    # Rosto: centros dos olhos (Henrique: esferas dos globos oculares).
    eyes = h_parts["Olhos"]
    comp = components(eyes.P, eyes.T)
    h_eye = {}
    for c in np.unique(comp):
        center, radius = sphere_fit(eyes.P[comp == c])
        h_eye[1.0 if center[0] > 0 else -1.0] = (center, radius)
    j_eye_c = (J["Olho.L"] + J["Olho.R"]) / 2
    h_eye_c = (h_eye[1.0][0] + h_eye[-1.0][0]) / 2
    # Boca: a fenda entre os lábios (bordas abertas da malha do corpo perto do meio).
    hb = h_parts["Henrique_Corpo"]
    mouth = mouth_slit(hb, hb.material_prim("Boca_Interior"))
    j_mouth = np.array([0.0, (J["Labio_Sup"][1] + J["Labio_Inf"][1]) / 2, 0.0])
    j_mouth[2] = lip_front(jbody.P, j_mouth[1])
    h_mouth = np.array([0.0, mouth["y"], mouth["z"]])

    # Alturas: chão, entreperna, eixo dos braços (no ombro), boca, olhos.
    jy = [0.0, jbody.crotch, jbody.arm_y, j_mouth[1], j_eye_c[1]]
    hy = [0.0, hbody.crotch, hbody.arm_y, h_mouth[1], h_eye_c[1]]

    def y_map(y):
        return piecewise(y, jy, hy)

    # Tronco e cabeça: no meio, na mesma fração entre costas e frente.
    for name in ("Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"):
        p = J[name]
        y = y_map(p[1])
        jb_, jf = jbody.depth(p[1])
        hb_, hf = hbody.depth(y)
        f = (p[2] - jb_) / (jf - jb_)
        H[name] = np.array([0.0, y, hb_ + f * (hf - hb_)])
    H["Raiz"] = np.zeros(3)

    for s, long_, sg in SIDES:
        # Pernas: centro do corte da perna na altura equivalente, mais o desvio do Jarbas
        # em relação ao centro do corte dele (proporcional à largura da perna).
        for name in ("UpLeg", "Leg", "Foot"):
            p = J[long_ + name]
            y = y_map(p[1])
            # Acima da entreperna a perna já é tronco: mede um pouco abaixo dela.
            jy_cut = min(p[1], jbody.crotch - 0.03)
            hy_cut = min(y, hbody.crotch - 0.03)
            jc, jsz = jbody.leg(sg, jy_cut)
            hc, hsz = hbody.leg(sg, hy_cut)
            off = (np.array([p[0], p[2]]) - jc) / jsz * hsz
            H[long_ + name] = np.array([hc[0] + off[0], y, hc[1] + off[1]])
        # Ponta do pé: mesma fração do comprimento do sapato, na altura equivalente.
        jq, hq = jbody.foot(sg), hbody.foot(sg)
        p = J[long_ + "ToeBase"]
        fz = (p[2] - jq[:, 2].min()) / np.ptp(jq[:, 2])
        fy = p[1] / jq[:, 1].max()
        fx = (p[0] - jq[:, 0].min()) / np.ptp(jq[:, 0])
        H[long_ + "ToeBase"] = np.array([hq[:, 0].min() + fx * np.ptp(hq[:, 0]), fy * hq[:, 1].max(),
                                         hq[:, 2].min() + fz * np.ptp(hq[:, 2])])
        # Braço: x entre a lateral do tronco e o punho; altura e profundidade no eixo do
        # braço, com o desvio do Jarbas em relação ao eixo dele (proporcional à espessura).
        s_glove, R_glove, t_glove = glove_xf[s]
        H[long_ + "Hand"] = s_glove * R_glove @ J[long_ + "Hand"] + t_glove
        jw, hw = abs(J[long_ + "Hand"][0]), abs(H[long_ + "Hand"][0])
        thick = np.array([hbody.arm[sg][2] / jbody.arm[sg][2], hbody.arm[sg][3] / jbody.arm[sg][3]])
        for name in ("Arm", "ForeArm"):
            p = J[long_ + name]
            f = (abs(p[0]) - jbody.torso_edge) / (jw - jbody.torso_edge)
            x = sg * (hbody.torso_edge + f * (hw - hbody.torso_edge))
            off = (p - jbody.arm_point(sg, p[0]))[1:] * thick
            H[long_ + name] = hbody.arm_point(sg, x) + np.r_[0.0, off]
        # Clavícula: perto da coluna, na altura equivalente.
        p = J[long_ + "Shoulder"]
        y = y_map(p[1])
        jb_, jf = jbody.depth(p[1])
        hb_, hf = hbody.depth(y)
        f = (p[2] - jb_) / (jf - jb_)
        H[long_ + "Shoulder"] = np.array([p[0] * hbody.torso_edge / jbody.torso_edge, y, hb_ + f * (hf - hb_)])
        # Dedos: junto com a luva.
        for finger in FINGERS:
            for k in (1, 2, 3):
                n = "%sHand%s%d" % (long_, finger, k)
                H[n] = s_glove * R_glove @ J[n] + t_glove

    # Rosto: olhos e pálpebras no centro do globo; o resto pela posição relativa a olhos
    # e boca (escala própria em cada eixo).
    k = np.array([abs(h_eye[1.0][0][0] - h_eye[-1.0][0][0]) / abs(J["Olho.L"][0] - J["Olho.R"][0]),
                  (h_eye_c[1] - h_mouth[1]) / (j_eye_c[1] - j_mouth[1]),
                  (h_mouth[2] - h_eye_c[2]) / (j_mouth[2] - j_eye_c[2])])
    for name in FACE:
        if name.startswith(("Olho", "Palpebra")):
            H[name] = h_eye[1.0 if name.endswith(".L") else -1.0][0].copy()
        else:
            H[name] = h_mouth + (J[name] - j_mouth) * k
    info = {"eye": {s: (h_eye[sg][0].tolist(), h_eye[sg][1]) for s, _, sg in SIDES}, "mouth": mouth,
            "face_scale": k.tolist(), "j_mouth": j_mouth.tolist(), "h_mouth": h_mouth.tolist(),
            "heights_jarbas": jy, "heights_henrique": hy,
            "torso_edge": [jbody.torso_edge, hbody.torso_edge]}
    return H, info


def lip_front(P, y):
    """Frente dos lábios (z) no meio do rosto, na altura y."""
    near = P[(np.abs(P[:, 0]) < 0.02) & (np.abs(P[:, 1] - y) < 0.01) & (P[:, 2] > 0.0)]
    return float(near[:, 2].max())


def mouth_slit(body, interior_prim):
    """Fenda da boca. Os lábios continuam para dentro num tubo (material Boca_Interior)
    que abre para a cavidade da boca: a fenda é o meio desse tubo, em cada x."""
    Q = body.P[body.range(interior_prim)]
    xs = np.linspace(Q[:, 0].min(), Q[:, 0].max(), 15)
    curve = []
    for x in xs:
        q = Q[np.abs(Q[:, 0] - x) < (xs[1] - xs[0])]
        if len(q):
            curve.append([float(x), float((q[:, 1].min() + q[:, 1].max()) / 2)])
    curve = np.array(curve)
    y = float(np.interp(0.0, curve[:, 0], curve[:, 1]))
    return {"y": y, "z": lip_front(body.P, y), "corner_x": float(np.abs(Q[:, 0]).max()),
            "curve": curve.tolist(), "inner_z": float(Q[:, 2].min())}


def bone_frames(jb, H, glove_xf):
    """Base (colunas X, Y, Z) de cada osso: Y aponta para a próxima articulação e X/Z
    ficam o mais perto possível dos do Jarbas."""
    aim = {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}
    for _, long_, _ in SIDES:
        aim.update({long_ + "Shoulder": long_ + "Arm", long_ + "Arm": long_ + "ForeArm",
                    long_ + "ForeArm": long_ + "Hand", long_ + "UpLeg": long_ + "Leg",
                    long_ + "Leg": long_ + "Foot", long_ + "Foot": long_ + "ToeBase"})
    frames = {}
    for name in jb.names:
        B = jb.basis(name)
        side = "L" if name.startswith("Left") else "R" if name.startswith("Right") else None
        if side and ("Hand" in name):
            # Mão e dedos: giram junto com a luva.
            B = glove_xf[side][1] @ B
        elif name in aim:
            d = H[aim[name]] - H[name]
            B = rot_between(B[:, 1], d) @ B
        frames[name] = B
    return frames


# --- Rosto ---------------------------------------------------------------------------------

def smooth(e0, e1, x):
    """Smoothstep de e0 (0) a e1 (1); com e0 > e1 a rampa desce."""
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


class Face:
    """Medidas do rosto do Henrique usadas nos ossos e nos pesos do rosto."""

    def __init__(self, H, info, body):
        self.mouth = info["mouth"]
        curve = np.array(self.mouth["curve"])
        self.curve_x, self.curve_y = curve[:, 0], curve[:, 1]
        self.corner = self.mouth["corner_x"]
        self.front = self.mouth["z"]
        self.inner = self.mouth["inner_z"]
        self.eye = {s: np.array(info["eye"][s][0]) for s in ("L", "R")}
        self.eye_r = info["eye"]["L"][1]
        self.pivot = H["Mandibula"]
        # Embaixo do queixo (a barba): a altura mais baixa em que a frente do rosto, no
        # meio, ainda está perto da frente dos lábios.
        P = body.P
        mid = P[(np.abs(P[:, 0]) < 0.01) & (P[:, 2] > self.front - 0.025) & (P[:, 1] < self.mouth["y"])]
        self.chin_y = float(mid[:, 1].min())
        # Frente da pele nos cantos da boca.
        cx = self.corner * 0.92
        near = P[(np.abs(np.abs(P[:, 0]) - cx) < 0.004) & (np.abs(P[:, 1] - self.slit_y(cx)) < 0.006)]
        self.corner_z = float(near[:, 2].max())

    def slit_y(self, x):
        return np.interp(x, self.curve_x, self.curve_y)

    def below(self, P):
        """Quanto abaixo da fenda da boca (0 em cima, 1 embaixo). Dentro da boca a
        passagem é seca (os lábios estão separados pela fenda); dos cantos para fora ela
        se espalha pela bochecha."""
        ax = np.abs(P[:, 0])
        tw = np.interp(ax, [0.85 * self.corner, 1.6 * self.corner], [0.0015, 0.02])
        return smooth(-tw, tw, self.slit_y(P[:, 0]) - P[:, 1])

    def jaw(self, P):
        """Peso da mandíbula: abaixo da fenda, na frente da articulação (perto da orelha)
        e acima do pescoço (linha que vai de baixo do queixo até atrás do canto da
        mandíbula)."""
        y, z = P[:, 1], P[:, 2]
        ay, az = self.chin_y - 0.009, 0.0
        by, bz = self.pivot[1] - 0.07, self.pivot[2] - 0.02
        line = ay + (z - az) * (by - ay) / (bz - az)
        boundary = np.maximum(line, ay)
        fn = smooth(boundary - 0.004, boundary + 0.004, y)
        fz = smooth(self.pivot[2] - 0.035, self.pivot[2] - 0.005, z)
        return self.below(P) * fn * fz

    def front_factor(self, P):
        return smooth(self.inner - 0.008, self.inner, P[:, 2])


def lid_opening(lids, eye_center, eye_radius):
    """Abertura das pálpebras do olho esquerdo (graus, vista de lado, a partir do centro
    do globo): da borda da de cima até a borda da de baixo, na frente do olho."""
    comp = components(lids.P, lids.T)
    edges = {}
    for c in np.unique(comp):
        P = lids.P[comp == c]
        center = P.mean(0)
        if center[0] < 0:
            continue
        q = P[(np.abs(P[:, 0] - eye_center[0]) < 0.35 * eye_radius) & (P[:, 2] > eye_center[2])]
        phi = np.degrees(np.arctan2(q[:, 1] - eye_center[1], q[:, 2] - eye_center[2]))
        if center[1] > eye_center[1]:
            edges["up"] = float(phi.min())
        else:
            edges["low"] = float(phi.max())
    return edges["up"] - edges["low"], edges


def place_face_bones(H, face, brows):
    """Boca e sobrancelhas medidas no próprio Henrique (o mapa do Jarbas acerta olhos e
    mandíbula, mas a boca dele é mais estreita e as sobrancelhas, mais baixas)."""
    y = float(face.slit_y(0.0))
    H["Labio_Sup"] = np.array([0.0, y + 0.0065, face.front - 0.007])
    H["Labio_Inf"] = np.array([0.0, y - 0.0065, face.front - 0.007])
    for s, sg in (("L", 1.0), ("R", -1.0)):
        cx = face.corner * 0.92
        H["Canto_Boca." + s] = np.array([sg * cx, float(face.slit_y(sg * cx)), face.corner_z - 0.004])
        for part in ("Int", "Ext"):
            H["Sobrancelha_%s.%s" % (part, s)] = brows[s][part]


def find_brows(P, colors):
    """Sobrancelhas pintadas na textura: os pontos escuros entre os olhos e a aba do
    boné (pele ~0,55 de luminância, boné ~0,33, sobrancelha < 0,24). Cada uma vira dois
    ossos (metade de dentro e metade de fora)."""
    lum = colors[:, :3] @ np.array([0.299, 0.587, 0.114])
    dark = lum < 0.24
    out = {}
    for s, sg in (("L", 1.0), ("R", -1.0)):
        q = P[dark & (P[:, 0] * sg > 0.004)]
        ax = np.abs(q[:, 0])
        cut = np.median(ax)
        inner = q[ax <= cut]
        outer = q[ax > cut]
        back = np.array([0.0, 0.0, -0.003])
        out[s] = {"Int": inner.mean(0) + back, "Ext": outer.mean(0) + back,
                  "points": len(q), "x": [float(ax.min()), float(ax.max())],
                  "y": [float(q[:, 1].min()), float(q[:, 1].max())]}
    return out


def brow_candidates(body, uv, face, per_edge=8):
    """Pontos da pele entre os olhos e o boné (onde as sobrancelhas podem estar),
    espalhados dentro dos triângulos (a malha ali é esparsa): posições e UVs."""
    P = body.P
    eye_y = face.eye["L"][1]
    sel = (np.abs(P[:, 0]) < 0.09) & (P[:, 1] > eye_y + 0.004) & (P[:, 1] < eye_y + 0.03) \
        & (P[:, 2] > face.eye["L"][2] - 0.01) & (body.prim == body.material_prim("tripo_mat_4699cc3b"))
    tris = body.T[sel[body.T].all(1)]
    bary = np.array([(i, j, per_edge - i - j) for i in range(per_edge + 1) for j in range(per_edge + 1 - i)],
                    dtype=float) / per_edge
    pts = np.einsum("bk,tkd->tbd", bary, P[tris]).reshape(-1, 3)
    uvs = np.einsum("bk,tkd->tbd", bary, uv[tris]).reshape(-1, 2)
    return pts, uvs


# --- Pesos ---------------------------------------------------------------------------------

def heat_bones(H, frames, face, body):
    """Ossos dos pesos automáticos: (nome, cabeça, ponta), espaço do glTF."""
    tails = {"Hips": H["Spine"], "Spine": H["Spine1"], "Spine1": H["Spine2"], "Spine2": H["Neck"],
             "Neck": H["Head"]}
    eye_y = face.eye["L"][1]
    tails["Head"] = np.array([0.0, eye_y + 0.07, H["Head"][2] + 0.02])
    for _, long_, sg in SIDES:
        tails[long_ + "Shoulder"] = H[long_ + "Arm"]
        tails[long_ + "Arm"] = H[long_ + "ForeArm"]
        tails[long_ + "ForeArm"] = H[long_ + "Hand"]
        m2, m3 = H[long_ + "HandMiddle2"], H[long_ + "HandMiddle3"]
        tails[long_ + "Hand"] = m3 + (m3 - m2)
        tails[long_ + "UpLeg"] = H[long_ + "Leg"]
        tails[long_ + "Leg"] = H[long_ + "Foot"]
        tails[long_ + "Foot"] = H[long_ + "ToeBase"]
        shoe = body.P[(body.P[:, 0] * sg > 0) & (body.P[:, 1] < 0.06)]
        toe = H[long_ + "ToeBase"]
        tails[long_ + "ToeBase"] = np.array([toe[0], toe[1], shoe[:, 2].max() - 0.01])
    return [(n, H[n], tails[n]) for n in HEAT_BONES]


def to_blender(p):
    p = np.asarray(p)
    return np.stack([p[..., 0], -p[..., 2], p[..., 1]], axis=-1)


def run_blender(body, bones, image_png, uv):
    """Pesos automáticos (bone heat) do Blender na malha do corpo com os vértices
    repetidos juntados, e as cores da textura nos UVs pedidos."""
    inv = merge_ids(body.P)
    rep = np.zeros(inv.max() + 1, dtype=int)
    rep[inv] = np.arange(len(inv))
    faces = inv[body.T]
    faces = faces[(faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])]
    faces = np.unique(np.sort(faces, axis=1), axis=0)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "entrada.npz")
        dst = os.path.join(tmp, "saida.npz")
        img = os.path.join(tmp, "textura.png")
        with open(img, "wb") as f:
            f.write(image_png)
        np.savez(src, verts=to_blender(body.P[rep]), faces=faces,
                 bones=np.array([b[0] for b in bones]), heads=to_blender(np.array([b[1] for b in bones])),
                 tails=to_blender(np.array([b[2] for b in bones])), image=img, uv=uv)
        r = subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "-P", HEAT_SCRIPT,
                            "--", src, dst], capture_output=True, text=True)
        for line in (r.stdout + r.stderr).splitlines():
            if "pesos automáticos" in line or "Bone Heat" in line or "Error" in line or "rror:" in line:
                print("  blender:", line.strip())
        if r.returncode != 0:
            raise SystemExit("Blender falhou:\n" + r.stdout[-3000:] + r.stderr[-3000:])
        out = dict(np.load(dst))
    return out["weights"][inv], out["colors"]


def nearest_bone(P, bones, names):
    """Fallback para vértices sem peso: o osso (segmento) mais perto."""
    best = np.full(len(P), np.inf)
    idx = np.zeros(len(P), dtype=int)
    for k, (n, a, b) in enumerate(bones):
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        m = d < best
        best[m] = d[m]
        idx[m] = names.index(n)
    return idx


def body_weights(body, W_heat, names, H, face):
    """Pesos do corpo: os automáticos, com o rosto (mandíbula, lábios, cantos da boca,
    sobrancelhas) por cima, só na cabeça."""
    P = body.P
    nb = len(names)
    ix = {n: names.index(n) for n in names}
    W = np.zeros((len(P), nb))
    for k, n in enumerate(HEAT_BONES):
        W[:, ix[n]] = W_heat[:, k]
    head_share = W[:, ix["Head"]] + W[:, ix["Neck"]]
    front = face.front_factor(P)
    below = face.below(P)
    jaw = face.jaw(P)
    d = lambda name: np.linalg.norm(P - H[name], axis=1)  # noqa: E731
    lip_sup = 0.8 * smooth(0.026, 0.008, d("Labio_Sup")) * (1.0 - below) * front
    lip_inf = np.minimum(0.8 * smooth(0.026, 0.008, d("Labio_Inf")) * below * front, jaw)
    corners = {s: 0.85 * smooth(0.022, 0.004, d("Canto_Boca." + s)) * front for s in ("L", "R")}
    above_eye = smooth(face.eye["L"][1] + 0.004, face.eye["L"][1] + 0.012, P[:, 1]) \
        * smooth(face.eye["L"][2] - 0.01, face.eye["L"][2], P[:, 2])
    brows = {}
    for s in ("L", "R"):
        for part in ("Int", "Ext"):
            n = "Sobrancelha_%s.%s" % (part, s)
            brows[n] = smooth(0.02, 0.007, d(n)) * above_eye
    # Cada ponto do rosto: a soma dos pesos do rosto não passa de 1.
    face_w = {"Mandibula": jaw - lip_inf, "Labio_Inf": lip_inf, "Labio_Sup": lip_sup,
              "Canto_Boca.L": corners["L"], "Canto_Boca.R": corners["R"], **brows}
    total = sum(face_w.values())
    scale = np.where(total > 1.0, 1.0 / np.maximum(total, 1e-9), 1.0) * head_share
    total = total * scale
    W *= (1.0 - total)[:, None]
    for n, w in face_w.items():
        W[:, ix[n]] += w * scale
    # Sombra das órbitas (dentro da cabeça, atrás dos olhos): só a cabeça.
    orb = body.range(body.material_prim("Orbita_Sombra"))
    W[orb] = 0.0
    W[orb, ix["Head"]] = 1.0
    return W


def rigid(n_verts, names, bone):
    W = np.zeros((n_verts, len(names)))
    W[:, names.index(bone)] = 1.0
    return W


def part_weights(h_parts, j_parts, jg, names, H, face, body_W):
    out = {"Henrique_Corpo": body_W}
    ix = {n: names.index(n) for n in names}
    # Luvas: os pesos das luvas do Jarbas, vértice a vértice (primitivas casadas pelo
    # número de vértices).
    for s in ("L", "R"):
        hp, jp = h_parts["Mao." + s], j_parts["Mao." + s]
        W = np.zeros((len(hp.P), len(names)))
        jskin = jg.js["skins"][0]["joints"]
        jnames = [jg.js["nodes"][j]["name"] for j in jskin]
        by_count = {len(jp.P[jp.range(k)]): k for k in range(len(jp.prims))}
        for k in range(len(hp.prims)):
            p = jp.prims[by_count[hp.offsets[k + 1] - hp.offsets[k]]]
            Jt = np.array(jg.read_accessor(p["attributes"]["JOINTS_0"], raw=True))
            Wt = np.array(jg.read_accessor(p["attributes"]["WEIGHTS_0"]))
            rows = np.arange(hp.offsets[k], hp.offsets[k + 1])
            for c in range(4):
                for slot in np.unique(Jt[:, c]):
                    m = Jt[:, c] == slot
                    W[rows[m], ix[jnames[slot]]] += Wt[m, c]
        out["Mao." + s] = W
    # Olhos: cada globo no osso do olho.
    eyes = h_parts["Olhos"]
    W = np.zeros((len(eyes.P), len(names)))
    W[eyes.P[:, 0] > 0, ix["Olho.L"]] = 1.0
    W[eyes.P[:, 0] <= 0, ix["Olho.R"]] = 1.0
    out["Olhos"] = W
    # Pálpebras: quatro peças (de cima com os cílios, de baixo), cada uma no seu osso.
    lids = h_parts["Palpebras"]
    comp = components(lids.P, lids.T)
    W = np.zeros((len(lids.P), len(names)))
    for c in np.unique(comp):
        m = comp == c
        center = lids.P[m].mean(0)
        s = "L" if center[0] > 0 else "R"
        part = "Sup" if center[1] > face.eye[s][1] else "Inf"
        W[m, ix["Palpebra_%s.%s" % (part, s)]] = 1.0
    out["Palpebras"] = W
    # Boca por dentro: dentes e gengiva de cima na cabeça; de baixo e língua na mandíbula;
    # o fundo da boca se divide pela altura da fenda.
    mouth = h_parts["Boca"]
    comp = components(mouth.P, mouth.T)
    W = np.zeros((len(mouth.P), len(names)))
    fundo = mouth.material_prim("Boca_Fundo")
    for c in np.unique(comp):
        m = comp == c
        if np.all(mouth.prim[m] == fundo):
            y = face.slit_y(mouth.P[m, 0])
            jw = smooth(y + 0.004, y - 0.008, mouth.P[m, 1])
            W[m, ix["Mandibula"]] = jw
            W[m, ix["Head"]] = 1.0 - jw
        else:
            center = mouth.P[m].mean(0)
            W[m, ix["Mandibula" if center[1] < face.slit_y(center[0]) else "Head"]] = 1.0
    out["Boca"] = W
    # Logos: os pesos do ponto mais próximo do corpo.
    logos = h_parts["Logos_Ativos"]
    bodyP = h_parts["Henrique_Corpo"].P
    nearest = np.array([np.argmin(np.linalg.norm(bodyP - p, axis=1)) for p in logos.P])
    out["Logos_Ativos"] = body_W[nearest]
    return out


def top4(W):
    """Os 4 maiores pesos de cada vértice, normalizados."""
    idx = np.argsort(-W, axis=1)[:, :4]
    w = np.take_along_axis(W, idx, axis=1)
    w[w < 0.002] = 0.0
    total = w.sum(1, keepdims=True)
    w = np.where(total > 0, w / np.maximum(total, 1e-9), np.array([[1.0, 0, 0, 0]]))
    idx = np.where(w > 0, idx, 0)
    return idx, w


def quat_from_matrix(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def skeleton_json(jb, H, frames):
    bones = []
    world = {}
    for n in jb.names:
        M = np.eye(4)
        M[:3, :3] = frames[n]
        M[:3, 3] = H[n]
        world[n] = M
    for n in jb.names:
        par = jb.parent_name(n)
        local = np.linalg.inv(world[par]) @ world[n] if par else world[n]
        R = local[:3, :3]
        U, _, Vt = np.linalg.svd(R)
        R = U @ Vt
        bones.append({"name": n, "parent": jb.names.index(par) if par else -1,
                      "translation": [round(float(v), 6) for v in local[:3, 3]],
                      "rotation": [round(float(v), 7) for v in quat_from_matrix(R)]})
    return bones


# --- Main ----------------------------------------------------------------------------------

def main():
    debug = "--debug" in sys.argv
    g = Glb(SRC)
    jg = Glb(JARBAS)
    jb = Skeleton(jg)
    h_parts = {n: Part(g, n) for n in ("Henrique_Corpo", "Mao.L", "Mao.R", "Olhos", "Palpebras", "Boca", "Logos_Ativos")}
    j_parts = {n: Part(jg, n) for n in ("Jarbas_Corpo", "Mao.L", "Mao.R")}

    # Luvas: escala, giro e translação do Jarbas para o Henrique (mesma malha).
    glove_xf = {}
    for s in ("L", "R"):
        jp, hp = j_parts["Mao." + s], h_parts["Mao." + s]
        order_j = sorted(range(len(jp.prims)), key=lambda k: jp.offsets[k + 1] - jp.offsets[k])
        order_h = sorted(range(len(hp.prims)), key=lambda k: hp.offsets[k + 1] - hp.offsets[k])
        a = np.concatenate([jp.P[jp.range(k)] for k in order_j])
        b = np.concatenate([hp.P[hp.range(k)] for k in order_h])
        sc, R, t = umeyama(a, b)
        res = np.linalg.norm(sc * a @ R.T + t - b, axis=1)
        glove_xf[s] = (sc, R, t)
        print("luva %s: escala %.4f, giro %.1f°, erro médio %.1f mm (máx %.1f)" % (
            s, sc, np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))), res.mean() * 1000, res.max() * 1000))

    jbody = Body(j_parts["Jarbas_Corpo"].P, j_parts["Jarbas_Corpo"].T, jb.pos("LeftHand"), jb.pos("RightHand"))
    hw = {s: glove_xf[s][0] * glove_xf[s][1] @ jb.pos(long_ + "Hand") + glove_xf[s][2] for s, long_, _ in SIDES}
    hbody = Body(h_parts["Henrique_Corpo"].P, h_parts["Henrique_Corpo"].T, hw["L"], hw["R"])
    print("entreperna: Jarbas %.3f, Henrique %.3f" % (jbody.crotch, hbody.crotch))
    print("lateral do tronco: Jarbas %.3f, Henrique %.3f; eixo do braço: %.3f / %.3f" % (
        jbody.torso_edge, hbody.torso_edge, jbody.arm_y, hbody.arm_y))

    H, info = build_skeleton(jb, jbody, hbody, h_parts, glove_xf)
    frames = bone_frames(jb, H, glove_xf)
    body = h_parts["Henrique_Corpo"]
    face = Face(H, info, body)
    print("boca: fenda y %.4f, frente z %.4f, cantos x ±%.3f (z %.3f); queixo y %.3f; escala do rosto %s" % (
        face.slit_y(0.0), face.front, face.corner, face.corner_z, face.chin_y, np.round(info["face_scale"], 3)))

    if "--only-skeleton" not in sys.argv:
        # Pesos automáticos do corpo e cores da textura onde podem estar as sobrancelhas.
        uv = np.concatenate([np.array(g.read_accessor(p["attributes"]["TEXCOORD_0"])) for p in body.prims])
        brow_pts, brow_uv = brow_candidates(body, uv, face)
        mat = g.js["materials"][body.prims[body.material_prim("tripo_mat_4699cc3b")]["material"]]
        image = g.js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
        bones = heat_bones(H, frames, face, body)
        W_heat, colors = run_blender(body, bones, g.image_bytes(image), brow_uv)
        empty = W_heat.sum(1) < 1e-4
        if empty.any():
            fallback = nearest_bone(body.P[empty], bones, [b[0] for b in bones])
            W_heat[np.nonzero(empty)[0], fallback] = 1.0
            print("  %d vértices sem peso automático: osso mais perto" % empty.sum())
        W_heat /= W_heat.sum(1, keepdims=True)
        brows = find_brows(brow_pts, colors)
        for s in ("L", "R"):
            b = brows[s]
            print("sobrancelha %s: %d pontos, x %.3f a %.3f, y %.3f a %.3f" % (s, b["points"], *b["x"], *b["y"]))
        place_face_bones(H, face, brows)
        frames = bone_frames(jb, H, glove_xf)
        body_W = body_weights(body, W_heat, jb.names, H, face)
        weights = part_weights(h_parts, j_parts, jg, jb.names, H, face, body_W)

        # Pálpebras: o quanto cada uma gira para fechar sai da piscada do Jarbas, na
        # proporção das aberturas (as do Henrique são mais caídas).
        je = Part(jg, "Olhos")
        comp = components(je.P, je.T)
        _, j_eye_r = sphere_fit(je.P[comp == comp[np.argmax(je.P[:, 0])]])
        j_open, j_edges = lid_opening(Part(jg, "Palpebras"), jb.pos("Olho.L"), j_eye_r)
        h_open, h_edges = lid_opening(h_parts["Palpebras"], face.eye["L"], face.eye_r)
        print("pálpebras abertas: Jarbas %.1f° (%+.0f° a %+.0f°), Henrique %.1f° (%+.0f° a %+.0f°)" % (
            j_open, j_edges["up"], j_edges["low"], h_open, h_edges["up"], h_edges["low"]))
        out = {"source": os.path.relpath(SRC, PROJ), "reference": os.path.relpath(JARBAS, PROJ),
               "bones": skeleton_json(jb, H, frames), "meshes": {},
               "face": {"slit_y": float(face.slit_y(0.0)), "lip_front_z": face.front,
                        "corner_x": face.corner, "chin_y": face.chin_y,
                        "eye_center": {s: face.eye[s].tolist() for s in ("L", "R")}, "eye_radius": face.eye_r,
                        "face_scale": info["face_scale"], "lid_opening": h_open, "lid_opening_reference": j_open,
                        "lid_scale": h_open / j_open}}
        for name, W in weights.items():
            part = h_parts[name]
            prims = []
            for k in range(len(part.prims)):
                idx, w = top4(W[part.range(k)])
                prims.append({"count": int(len(idx)), "joints": idx.ravel().tolist(),
                              "weights_1e4": np.round(w * 10000).astype(int).ravel().tolist()})
            out["meshes"][name] = prims
        with open(DST, "w") as f:
            json.dump(out, f, separators=(",", ":"))
        print("gravado", os.path.relpath(DST, PROJ), "%.1f MB" % (os.path.getsize(DST) / 1e6))

    if debug:
        out = {"joints": {n: H[n].tolist() for n in jb.names},
               "frames": {n: frames[n].tolist() for n in jb.names},
               "parent": {n: jb.parent_name(n) for n in jb.names}}
        with open(DEBUG_OUT, "w") as f:
            json.dump(out, f, indent=1)
        for n in jb.names:
            print("  %-20s %s" % (n, np.round(H[n], 3)))


if __name__ == "__main__":
    main()
