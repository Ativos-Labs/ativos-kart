"""Gera o rótulo da garrafa de cerveja do Rafael (o gesto de escolha "SEXTOUU!"):
assets/textures/personagens/garrafa_rotulo.png.

A garrafa (scripts/garrafa_cerveja.gd) é uma long neck verde de vidro, com tampinha verde.
O rótulo lembra o de uma lager famosa sem copiar nome nem marca: oval com aro prateado,
faixa verde-escura com o texto em arco ("CERVEJA ORIGINAL" / "PURO MALTE · LAGER"),
estrela vermelha no meio ("EST." / "6ª FEIRA") e a faixa branca com o nome, SEXTOU.

O desenho é feito na proporção de verdade do pedaço de rótulo na garrafa (160° do corpo de
2,9 cm de raio por 8,8 cm de altura: 0,92 : 1) e gravado em 1024 x 1024 (a malha estica de
volta). Fora do oval é transparente (no jogo, recorte com alpha scissor).

Uso: python3 tools/personagens/build_garrafa.py   (precisa do Pillow; fontes do macOS)
O Godot ignora esta pasta (tools/.gdignore).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "textures", "personagens", "garrafa_rotulo.png")
FONTS = "/System/Library/Fonts/Supplemental/"
SIZE = 1024
# Desenho em 2x da proporção de verdade (largura do arco : altura).
W, H = 1840, 2000

SILVER = (214, 221, 223, 255)
SILVER_DARK = (128, 138, 141, 255)
GREEN_RING = (8, 74, 36, 255)
GREEN_FIELD = (14, 112, 52, 255)
GREEN_LIGHT = (40, 150, 76, 255)
RED = (226, 35, 26, 255)
WHITE = (250, 250, 246, 255)
INK = (10, 70, 34, 255)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def ellipse_box(inset):
    return (inset, inset, W - inset, H - inset)


def star(draw, cx, cy, r_out, r_in, fill, rotation=-math.pi / 2):
    pts = []
    for k in range(10):
        r = r_out if k % 2 == 0 else r_in
        a = rotation + k * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=fill)


def arc_text(img, text, fnt, inset, top, fill, spacing=1.0):
    """Texto em arco por dentro de uma elipse (`inset` do canto), em cima (lido da
    esquerda para a direita, letras em pé) ou embaixo (também da esquerda para a direita,
    com o pé das letras para fora)."""
    a = W / 2 - inset
    b = H / 2 - inset
    cx, cy = W / 2, H / 2
    widths = [fnt.getlength(ch) * spacing for ch in text]
    total = sum(widths)
    # Comprimento de arco aproximado: raio médio.
    r_mean = (a + b) / 2
    span = total / r_mean
    start = (-math.pi / 2 - span / 2) if top else (math.pi / 2 + span / 2)
    acc = 0.0
    for ch, w in zip(text, widths):
        mid = acc + w / 2
        ang = start + (mid / r_mean if top else -mid / r_mean)
        x = cx + a * math.cos(ang)
        y = cy + b * math.sin(ang)
        # Normal da elipse nesse ponto (para fora).
        nx, ny = math.cos(ang) / a, math.sin(ang) / b
        tilt = math.degrees(math.atan2(ny, nx))
        size = int(fnt.size * 1.6)
        glyph = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glyph)
        gd.text((size / 2, size / 2), ch, font=fnt, fill=fill, anchor="mm")
        rot = -(tilt + 90) if top else -(tilt - 90)
        glyph = glyph.rotate(rot, resample=Image.BICUBIC)
        img.alpha_composite(glyph, (int(x - size / 2), int(y - size / 2)))
        acc += w


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Aro prateado (com a borda escura) e a faixa verde-escura dos textos.
    d.ellipse(ellipse_box(4), fill=SILVER_DARK)
    d.ellipse(ellipse_box(16), fill=SILVER)
    d.ellipse(ellipse_box(46), fill=GREEN_RING)
    ring_mid = 46 + 150
    # Linha prateada fina e o campo verde com o meio mais claro.
    d.ellipse(ellipse_box(342), fill=SILVER)
    d.ellipse(ellipse_box(358), fill=GREEN_FIELD)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W * 0.28, H * 0.22, W * 0.72, H * 0.78), fill=GREEN_LIGHT)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    field_mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(field_mask).ellipse(ellipse_box(358), fill=255)
    img.paste(Image.alpha_composite(img, glow), (0, 0), field_mask)
    d = ImageDraw.Draw(img)

    arc = font("Arial Black.ttf", 150)
    arc_text(img, "CERVEJA ORIGINAL", arc, ring_mid, True, WHITE, 1.08)
    arc_text(img, "PURO MALTE · LAGER", arc, ring_mid, False, WHITE, 1.04)
    # Estrela vermelha com "EST." e "6ª FEIRA" dos lados.
    star_cy = H * 0.33
    star(d, W / 2, star_cy, 215, 86, (255, 255, 255, 255))
    star(d, W / 2, star_cy + 4, 192, 76, RED)
    small = font("Arial Bold.ttf", 82)
    d.text((W / 2 - 330, star_cy + 40), "EST.", font=small, fill=WHITE, anchor="mm")
    d.text((W / 2 + 360, star_cy + 40), "6ª FEIRA", font=small, fill=WHITE, anchor="mm")

    # Faixa branca com o nome (passa por cima do aro, com as pontas dobradas).
    band_top, band_bottom = int(H * 0.47), int(H * 0.66)
    fold = 70
    for side in (-1, 1):
        x_out = W / 2 + side * (W / 2 - 60)
        x_in = W / 2 + side * (W / 2 - 250)
        d.polygon([(x_out, band_top + fold), (x_in, band_top + fold), (x_in, band_bottom + fold),
                   (x_out, band_bottom + fold), (x_out + side * -60, (band_top + band_bottom) / 2 + fold)],
                  fill=(196, 204, 206, 255))
        d.polygon([(x_in, band_bottom), (x_in, band_bottom + fold), (x_in - side * 90, band_bottom)],
                  fill=(120, 128, 130, 255))
    d.rectangle((260, band_top, W - 260, band_bottom), fill=WHITE)
    d.line((260, band_top + 14, W - 260, band_top + 14), fill=SILVER_DARK, width=6)
    d.line((260, band_bottom - 14, W - 260, band_bottom - 14), fill=SILVER_DARK, width=6)
    name = font("Georgia Bold.ttf", 330)
    d.text((W / 2, (band_top + band_bottom) / 2 + 8), "Sextou", font=name, fill=INK, anchor="mm")

    # Embaixo da faixa.
    under = font("Arial Bold.ttf", 92)
    d.text((W / 2, H * 0.715), "CERVEJA LAGER", font=under, fill=WHITE, anchor="mm")
    tiny = font("Arial Bold.ttf", 50)
    d.text((W / 2, H * 0.765), "GELADA DESDE O EXPEDIENTE", font=tiny, fill=(200, 230, 205, 255), anchor="mm")

    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT, optimize=True)
    print("gravado", os.path.relpath(OUT, os.path.join(HERE, "..", "..")), "%d KB" % (os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
