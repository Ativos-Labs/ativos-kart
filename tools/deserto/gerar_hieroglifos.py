"""Gera assets/textures/hieroglifos.png: 16 hieróglifos (desenhos simples, feitos aqui)
numa grade 4x4 de células de 128 px, que ladrilha nas duas direções.

Canais (dados, não cor):
  R = o desenho do hieróglifo (1 = entalhe),
  G = as linhas que separam as colunas de escrita (bordas verticais de cada célula),
  B = número da célula (0..15) / 15, para o shader escolher a tinta de cada símbolo.

Uso: python3 tools/deserto/gerar_hieroglifos.py  (precisa do Pillow)
"""
import math
import os
from PIL import Image, ImageDraw

CELL = 256          # desenhado em 2x e reduzido para 128
N = 4
W = 9               # espessura do traço (no 2x)
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'textures', 'hieroglifos.png')


def line(d, pts, w=W):
    d.line(pts, fill=255, width=w, joint='curve')
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=255)


def ring(d, box, w=W):
    d.ellipse(box, outline=255, width=w)


def ankh(d, c):
    x, y = c
    ring(d, [x - 26, y - 78, x + 26, y - 18])
    d.rectangle([x - 52, y - 14, x + 52, y - 2], fill=255)
    d.rectangle([x - 6, y - 14, x + 6, y + 80], fill=255)


def eye(d, c):
    x, y = c
    pts = [(x - 70 + 140 * t / 20, y - 10 - 34 * math.sin(math.pi * t / 20)) for t in range(21)]
    line(d, pts)
    pts = [(x - 70 + 140 * t / 20, y - 10 + 22 * math.sin(math.pi * t / 20)) for t in range(21)]
    line(d, pts)
    d.ellipse([x - 16, y - 34, x + 16, y - 2], fill=255)
    line(d, [(x - 70, y - 48), (x, y - 62), (x + 66, y - 52)])
    line(d, [(x - 10, y + 12), (x - 18, y + 52), (x - 4, y + 70), (x + 14, y + 62)])
    line(d, [(x + 20, y + 10), (x + 54, y + 50)])


def bird(d, c):
    x, y = c
    d.ellipse([x - 40, y - 30, x + 42, y + 26], fill=255)
    d.ellipse([x + 22, y - 66, x + 58, y - 30], fill=255)
    d.polygon([(x + 56, y - 54), (x + 84, y - 44), (x + 54, y - 40)], fill=255)
    d.polygon([(x - 36, y - 10), (x - 86, y + 30), (x - 30, y + 18)], fill=255)
    line(d, [(x - 4, y + 22), (x - 10, y + 70)])
    line(d, [(x + 16, y + 22), (x + 20, y + 70)])
    line(d, [(x - 24, y + 72), (x + 32, y + 72)])


def water(d, c):
    x, y = c
    for row in (-40, 0, 40):
        pts = []
        for k in range(13):
            pts.append((x - 78 + k * 13, y + row + (-12 if k % 2 else 12)))
        line(d, pts, 8)


def reed(d, c):
    x, y = c
    pts = [(x + 10 * math.sin(t / 10 * 1.2), y + 80 - 160 * t / 10) for t in range(11)]
    line(d, pts)
    d.polygon([(x + 6, y - 82), (x + 46, y - 50), (x + 14, y - 10), (x + 2, y - 40)], fill=255)


def sun(d, c):
    x, y = c
    ring(d, [x - 60, y - 60, x + 60, y + 60], 12)
    d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=255)


def snake(d, c):
    x, y = c
    pts = [(x - 80 + 150 * t / 30, y + 26 + 18 * math.sin(t / 30 * math.pi * 3)) for t in range(31)]
    line(d, pts, 12)
    d.ellipse([x + 52, y - 14, x + 86, y + 20], fill=255)
    line(d, [(x - 80, y + 26), (x - 86, y + 50)], 8)


def loaf(d, c):
    x, y = c
    d.pieslice([x - 70, y - 40, x + 70, y + 100], 180, 360, fill=255)
    d.rectangle([x - 74, y + 30, x + 74, y + 42], fill=255)


def scarab(d, c):
    x, y = c
    d.ellipse([x - 34, y - 56, x + 34, y + 60], fill=255)
    d.ellipse([x - 22, y - 82, x + 22, y - 48], fill=255)
    for k in (-1, 1):
        for a in (-30, 6, 40):
            line(d, [(x + k * 30, y + a), (x + k * 70, y + a - 20), (x + k * 82, y + a + 8)], 8)


def djed(d, c):
    x, y = c
    d.rectangle([x - 14, y - 40, x + 14, y + 82], fill=255)
    for k in range(4):
        d.rectangle([x - 50, y - 80 + k * 18, x + 50, y - 70 + k * 18], fill=255)
    d.rectangle([x - 40, y + 70, x + 40, y + 84], fill=255)


def feather(d, c):
    x, y = c
    pts_l = [(x - 24 * math.sin(math.pi * t / 20), y + 84 - 168 * t / 20) for t in range(21)]
    pts_r = [(x + 34 * math.sin(math.pi * t / 20) * (1 - 0.3 * t / 20), y + 84 - 168 * t / 20) for t in range(21)]
    d.polygon(pts_l + list(reversed(pts_r)), fill=255)
    line(d, [(x, y + 92), (x + 6, y - 80)], 5)


def basket(d, c):
    x, y = c
    d.pieslice([x - 76, y - 60, x + 76, y + 70], 0, 180, fill=255)
    d.rectangle([x - 80, y - 2, x + 80, y + 10], fill=255)


def lotus(d, c):
    x, y = c
    line(d, [(x, y + 84), (x, y + 10)])
    d.polygon([(x, y - 78), (x + 20, y - 10), (x, y + 14), (x - 20, y - 10)], fill=255)
    d.polygon([(x - 64, y - 46), (x - 14, y + 4), (x - 26, y + 16)], fill=255)
    d.polygon([(x + 64, y - 46), (x + 14, y + 4), (x + 26, y + 16)], fill=255)


def was(d, c):
    x, y = c
    line(d, [(x, y + 84), (x, y - 62)], 10)
    line(d, [(x - 4, y - 62), (x + 34, y - 82), (x + 46, y - 62)], 10)
    line(d, [(x, y + 84), (x - 20, y + 64)], 8)
    line(d, [(x, y + 84), (x + 20, y + 64)], 8)


def house(d, c):
    x, y = c
    d.rectangle([x - 60, y - 56, x + 60, y + 56], outline=255, width=12)
    d.rectangle([x - 14, y + 30, x + 14, y + 60], fill=0)


def star(d, c):
    x, y = c
    pts = []
    for k in range(10):
        r = 76 if k % 2 == 0 else 26
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((x + r * math.cos(a), y + r * math.sin(a)))
    d.polygon(pts, fill=255)


GLYPHS = [ankh, eye, bird, water, reed, sun, snake, loaf, scarab, djed, feather, basket, lotus, was, house, star]


def main():
    size = CELL * N
    glyph = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(glyph)
    for i, fn in enumerate(GLYPHS):
        cx = (i % N) * CELL + CELL // 2
        cy = (i // N) * CELL + CELL // 2
        fn(d, (cx, cy))
    lines = Image.new('L', (size, size), 0)
    dl = ImageDraw.Draw(lines)
    for col in range(N):
        x0 = col * CELL
        dl.rectangle([x0, 0, x0 + 7, size], fill=255)
        dl.rectangle([x0 + CELL - 8, 0, x0 + CELL - 1, size], fill=255)
    index = Image.new('L', (size, size), 0)
    di = ImageDraw.Draw(index)
    for i in range(N * N):
        x0 = (i % N) * CELL
        y0 = (i // N) * CELL
        di.rectangle([x0, y0, x0 + CELL - 1, y0 + CELL - 1], fill=int(round(i * 255 / 15)))
    half = size // 2
    glyph = glyph.resize((half, half), Image.LANCZOS)
    lines = lines.resize((half, half), Image.LANCZOS)
    index = index.resize((half, half), Image.NEAREST)
    Image.merge('RGB', (glyph, lines, index)).save(os.path.abspath(OUT))
    print('hieroglifos.png', half, 'px')


if __name__ == '__main__':
    main()
