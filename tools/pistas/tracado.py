"""Ferramenta de traçado: gera o Curve3D (pontos + alças estilo Catmull-Rom) a partir de
pontos de controle (x, z, y[, 'flat']) e converte frações da volta antiga para a nova.

Uso como módulo: build(points) -> (data_str, samples); old_curve(tscn) -> samples;
remap(old_samples, new_samples, fracs) -> list.
"""
import math, re

K = 0.36


def _norm(v):
    l = math.sqrt(sum(c * c for c in v))
    return tuple(c / l for c in v) if l > 1e-9 else (0.0, 0.0, 0.0)


def _sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _len(v):
    return math.sqrt(sum(c * c for c in v))


def handles(points):
    """points: list of (x, z, y, flat?) -> list of (pos, in, out) in Godot xyz."""
    n = len(points)
    P = [(p[0], p[2] if len(p) > 2 else 0.0, p[1]) for p in points]
    flat = [len(p) > 3 and p[3] == 'flat' for p in points]
    out = []
    for i in range(n):
        prev = P[(i - 1) % n]
        nxt = P[(i + 1) % n]
        d = _norm(_sub(nxt, prev))
        if flat[i]:
            d = _norm((d[0], 0.0, d[2]))
        dp = _len(_sub(P[i], prev))
        dn = _len(_sub(nxt, P[i]))
        h_in = tuple(-c * dp * K for c in d)
        h_out = tuple(c * dn * K for c in d)
        out.append((P[i], h_in, h_out))
    return out


def data_string(hs):
    vals = []
    for pos, hi, ho in hs:
        vals += list(hi) + list(ho) + list(pos)
    return "PackedVector3Array(" + ", ".join(_fmt(v) for v in vals) + ")"


def _fmt(v):
    s = ("%.3f" % v).rstrip('0').rstrip('.')
    return "0" if s in ("-0", "") else s


def bezier_samples(hs, step=0.25, closed=True):
    """Pontos densos ao longo da curva: lista de (x, y, z) e comprimento acumulado."""
    pts = []
    n = len(hs)
    segs = n if closed else n - 1
    for i in range(segs):
        p0, _, o0 = hs[i]
        p3, i3, _ = hs[(i + 1) % n]
        c1 = tuple(a + b for a, b in zip(p0, o0))
        c2 = tuple(a + b for a, b in zip(p3, i3))
        est = _len(_sub(p3, p0)) * 1.3
        m = max(8, int(est / step))
        for k in range(m):
            t = k / m
            u = 1 - t
            pts.append(tuple(u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
                             for a, b, c, d in zip(p0, c1, c2, p3)))
    if closed:
        pts.append(pts[0])
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + _len(_sub(b, a)))
    return pts, cum


def parse_curve(tscn_text, ident="Curve3D_tracado"):
    m = re.search(r'id="%s".*?"points": PackedVector3Array\((.*?)\)' % ident, tscn_text, re.S)
    v = [float(x) for x in m.group(1).split(',')]
    hs = []
    for i in range(0, len(v), 9):
        hs.append(((v[i + 6], v[i + 7], v[i + 8]), (v[i], v[i + 1], v[i + 2]), (v[i + 3], v[i + 4], v[i + 5])))
    return hs


def point_at(samples, frac):
    pts, cum = samples
    L = cum[-1]
    d = (frac % 1.0) * L
    lo, hi = 0, len(cum) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if cum[mid] < d:
            lo = mid + 1
        else:
            hi = mid
    i = max(lo, 1)
    a, b = pts[i - 1], pts[i]
    seg = cum[i] - cum[i - 1]
    t = (d - cum[i - 1]) / seg if seg > 0 else 0
    p = tuple(x + (y - x) * t for x, y in zip(a, b))
    tan = _norm(_sub(b, a))
    return p, tan


def remap(old, new, frac):
    """Fração na curva nova do ponto da curva antiga em `frac` (mesmo sentido)."""
    p, tan = point_at(old, frac)
    pts, cum = new
    best, best_i = 1e18, 0
    for i in range(1, len(pts)):
        q = pts[i]
        d = (q[0] - p[0]) ** 2 + (q[2] - p[2]) ** 2
        if d < best:
            t2 = _norm(_sub(pts[i], pts[i - 1]))
            if t2[0] * tan[0] + t2[2] * tan[2] > 0.5:
                best, best_i = d, i
    return cum[best_i] / cum[-1], math.sqrt(best)


def length(samples):
    return samples[1][-1]
