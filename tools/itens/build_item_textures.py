"""Gera as texturas dos itens em assets/textures/itens/:

Velocidade
- rpv_guia.png      guia de pagamento verde da RPV (vira o foguete embaixo do kart);
- oficio.png        o ofício da Superpreferência (papel, cabeçalho, texto e assinatura);
- oficio_carimbo.png o carimbo vermelho "PRIORIDADE" (com transparência; o shader do
                    ofício o "bate" em cima do papel);
- nota.png          a nota de dinheiro que sai da maleta da Antecipação Celer.

Ataque
- indeferido.png        a marca vermelha "INDEFERIDO" (transparente) que fica estampada
                        atrás do kart atingido pelo Carimbo;
- carimbo_etiqueta.png  a etiqueta no alto do cabo do carimbo voador;
- intimacao_frente.png / intimacao_verso.png  os dois lados do envelope da Intimação;
- asa.png               a asinha de penas (transparente) do envelope e da Constituição;
- constituicao_capa.png a capa da Constituição gigante da PEC dos Precatórios;
- paginas.png           as bordas das páginas (listras) dos lados do livro;
- calculadora.png       a frente da calculadora da Impugnação dos cálculos (o visor fica
                        vazio: os números são desenhados no jogo);
- numeros.png           4 x 4 algarismos e sinais da chuva de números da explosão.

Armadilha
- pendencia_folha.png   a folha da pilha da Pendência documental (lista do que falta e o
                        carimbo PENDENTE); também as folhas que voam em quem escorrega;
- senha.png             a senha "AGUARDE SUA VEZ" da Fila do tribunal (transparente fora
                        do papel; o número é desenhado no jogo).

Defesa
- liminar.png           o escudo-documento com o carimbo LIMINAR DEFERIDA (transparente
                        fora do brasão).

Uso: python3 tools/itens/build_item_textures.py   (precisa do Pillow)
As fontes são as do macOS (Arial, Arial Black, Courier New). O Godot ignora esta pasta
(tools/.gdignore); os PNGs gerados entram no jogo como texturas comuns.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "textures", "itens")
FONTS = "/System/Library/Fonts/Supplemental/"


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def text_center(draw, xy, text, fnt, fill, anchor="mm"):
    draw.text(xy, text, font=fnt, fill=fill, anchor=anchor)


def barcode(draw, box, rng, color):
    x0, y0, x1, y1 = box
    x = x0
    while x < x1 - 3:
        w = rng.choice([1, 2, 2, 3, 4])
        if rng.random() < 0.62:
            draw.rectangle([x, y0, min(x + w - 1, x1), y1], fill=color)
        x += w


# --- RPV ----------------------------------------------------------------------------

def rotated_text(text, fnt, fill, stroke, stroke_fill, angle):
    """Texto num quadro transparente, girado `angle` graus (anti-horário)."""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    box = probe.textbbox((0, 0), text, font=fnt, stroke_width=stroke)
    w, h = box[2] - box[0] + 8, box[3] - box[1] + 8
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((4 - box[0], 4 - box[1]), text, font=fnt, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    return img.rotate(angle, expand=True, resample=Image.BICUBIC)


def paste_center(img, piece, cx, cy):
    img.paste(piece, (int(cx - piece.width / 2), int(cy - piece.height / 2)), piece)


def rpv_guia():
    """Guia verde de 512 x 256. No foguete, x vai ao longo do corpo (x = 0 no bico,
    512 na cauda) e y dá a volta nele: y = 128 é o alto do tubo, 64 o lado direito do
    kart, 192 o esquerdo e as bordas (0 e 256) ficam embaixo. Por isso o "RPV" aparece
    três vezes: deitado em cada lado (legível de quem olha aquele lado) e girado no alto
    da cauda (legível da câmera, que vem atrás)."""
    w, h = 512, 256
    img = Image.new("RGB", (w, h), (214, 240, 205))
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    # Fundo de segurança: linhas onduladas verde-claras.
    for k in range(0, h, 9):
        pts = [(x, k + 3 * math.sin(x / 23.0 + k)) for x in range(0, w + 8, 8)]
        d.line(pts, fill=(194, 228, 184), width=2)
    dark = (24, 120, 62)
    mid = (52, 160, 92)
    # Faixas de baixo do tubo (as bordas da guia).
    d.rectangle([0, 0, w, 22], fill=dark)
    d.rectangle([0, h - 22, w, h], fill=dark)
    band = font("Arial Bold.ttf", 12)
    text_center(d, (w // 2, 11), "GUIA DE PAGAMENTO  ·  REQUISIÇÃO DE PEQUENO VALOR  ·  CRÉDITO RÁPIDO", band, (235, 255, 238))
    text_center(d, (w // 2, h - 11), "PAGÁVEL EM ATÉ 60 DIAS  ·  RPV  ·  PAGÁVEL EM ATÉ 60 DIAS", band, (235, 255, 238))
    # Campos e código de barras perto do bico (fica embaixo do kart).
    small = font("Arial Bold.ttf", 11)
    value = font("Arial Black.ttf", 17)
    for i, (label, val) in enumerate((("VENCIMENTO", "60 DIAS"), ("VALOR", "R$ 9.999"))):
        y = 92 + i * 40
        d.rounded_rectangle([14, y, 136, y + 34], 5, outline=mid, width=2, fill=(232, 248, 226))
        d.text((22, y + 3), label, font=small, fill=mid)
        d.text((22, y + 14), val, font=value, fill=dark)
    # "RPV" deitado nos dois lados do tubo (o do lado direito de cabeça para baixo na
    # textura, para ficar em pé visto daquele lado).
    side = font("Arial Black.ttf", 50)
    piece = rotated_text("RPV", side, (255, 255, 255), 4, dark, 0)
    paste_center(img, piece, 250, 192)
    paste_center(img, piece.rotate(180), 250, 64)
    barcode(d, (148, 112, 200, 146), rng, (20, 40, 28))
    # "RPV" girado no alto da cauda, para a câmera de trás.
    tail = font("Arial Black.ttf", 30)
    paste_center(img, rotated_text("RPV", tail, (255, 255, 255), 3, dark, -90), 452, 128)
    # Setas de "vai" dos dois lados da cauda.
    for cy in (64, 192):
        for k in range(2):
            x = 352 + k * 18
            d.polygon([(x + 14, cy - 18), (x, cy), (x + 14, cy + 18), (x + 8, cy)], fill=mid)
    img.save(os.path.join(OUT, "rpv_guia.png"))


# --- Ofício ---------------------------------------------------------------------------

BODY = (
    "Senhor Diretor,\n"
    "Requer-se a imediata inclusão do credor na ordem de pagamento, com "
    "preferência sobre todos os demais, nos termos da lei, por se tratar de "
    "pessoa idosa e portadora de doença grave, conforme laudo anexo. "
    "Considerando-se o caráter alimentar do crédito, outrossim, solicita-se que "
    "o presente ofício passe à frente da fila, independentemente da data de "
    "expedição dos precatórios anteriores. Data venia, não há tempo a perder: "
    "o credor já está na pista. Sem mais para o momento, renovamos os votos de "
    "estima e consideração."
)


def wrap(draw, text, fnt, width):
    lines = []
    for para in text.split("\n"):
        line = ""
        for word in para.split(" "):
            test = (line + " " + word).strip()
            if draw.textlength(test, font=fnt) <= width:
                line = test
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def oficio():
    """Ofício em pé, 512 x 724 (proporção A4). O topo da folha fica para a frente do
    kart: da câmera de trás o texto aparece em pé."""
    w, h = 512, 724
    img = Image.new("RGB", (w, h), (251, 248, 238))
    d = ImageDraw.Draw(img)
    navy = (22, 30, 70)
    gray = (70, 74, 92)
    # Borda azul fina e o brasão (selo redondo com estrelas).
    d.rectangle([14, 14, w - 15, h - 15], outline=(160, 168, 196), width=2)
    cx, cy = w // 2, 70
    d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], outline=navy, width=4)
    d.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], outline=navy, width=2)
    for k in range(5):
        a = -math.pi / 2 + k * math.tau / 5
        sx, sy = cx + math.cos(a) * 14, cy + math.sin(a) * 14
        star = []
        for j in range(10):
            r = 6 if j % 2 == 0 else 2.6
            b = a + j * math.pi / 5
            star.append((sx + math.cos(b) * r, sy + math.sin(b) * r))
        d.polygon(star, fill=navy)
    text_center(d, (w // 2, 122), "REPÚBLICA DA PISTA", font("Arial Bold.ttf", 15), navy)
    text_center(d, (w // 2, 140), "Tribunal de Corrida de Kart", font("Arial.ttf", 13), gray)
    d.line([40, 156, w - 40, 156], fill=navy, width=2)
    title = font("Courier New Bold.ttf", 30)
    d.text((40, 172), "OFÍCIO Nº 0001/2026", font=title, fill=navy)
    sub = font("Courier New Bold.ttf", 19)
    d.text((40, 214), "Assunto: SUPERPREFERÊNCIA", font=sub, fill=navy)
    d.text((40, 238), "Urgente - fura a fila", font=font("Courier New.ttf", 17), fill=gray)
    body = font("Courier New.ttf", 17)
    y = 278
    for line in wrap(d, BODY, body, w - 80):
        d.text((40, y), line, font=body, fill=(40, 42, 56))
        y += 22
    y += 18
    d.text((40, y), "Atenciosamente,", font=body, fill=(40, 42, 56))
    # Assinatura (rabisco) e a linha.
    sy = y + 76
    pts = []
    for k in range(120):
        t = k / 119.0
        pts.append((150 + t * 210, sy - 18 + 14 * math.sin(t * 19.0) * (0.6 + 0.4 * math.sin(t * 5.0)) - 10 * t))
    d.line(pts, fill=(20, 40, 120), width=3, joint="curve")
    d.line([130, sy + 6, 382, sy + 6], fill=gray, width=2)
    text_center(d, (256, sy + 22), "Desembargador Relator", font("Arial.ttf", 13), gray)
    img.save(os.path.join(OUT, "oficio.png"))


def ink_stamp(w, h, draw_shape, seed):
    """Carimbo de tinta (w x h, fundo transparente, vermelho) com falhas de tinta.
    `draw_shape(d)` desenha a forma em branco numa imagem "L" (255 = tinta)."""
    ink = Image.new("L", (w, h), 0)
    draw_shape(ImageDraw.Draw(ink))
    # Falhas de tinta: manchas que tiram um pouco da cor.
    rng = random.Random(seed)
    holes = Image.new("L", (w, h), 0)
    hd = ImageDraw.Draw(holes)
    for _ in range(int(900 * w * h / (512 * 224))):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(0.6, 2.6)
        hd.ellipse([x - r, y - r, x + r, y + r], fill=rng.randint(90, 255))
    holes = holes.filter(ImageFilter.GaussianBlur(0.6))
    alpha = Image.composite(Image.new("L", (w, h), 0), ink, holes.point(lambda v: 255 if v > 150 else 0))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    img = Image.new("RGBA", (w, h), (214, 34, 40, 0))
    img.putalpha(alpha)
    # Cor também onde é transparente (o filtro não puxa preto para a borda).
    return img


def carimbo():
    """Carimbo vermelho "PRIORIDADE" (512 x 224, fundo transparente) com falhas de tinta."""
    w, h = 512, 224

    def shape(d):
        d.rounded_rectangle([8, 8, w - 9, h - 9], 22, outline=255, width=10)
        d.rounded_rectangle([26, 26, w - 27, h - 27], 14, outline=255, width=4)
        text_center(d, (w // 2, 100), "PRIORIDADE", font("Arial Black.ttf", 58), 255)
        text_center(d, (w // 2, 166), "IDOSO  ·  DOENÇA GRAVE", font("Arial Bold.ttf", 26), 255)

    ink_stamp(w, h, shape, 3).save(os.path.join(OUT, "oficio_carimbo.png"))


# --- Nota -----------------------------------------------------------------------------

def nota():
    """Nota de 100 (256 x 128) verde com o "C" da Celer no selo."""
    w, h = 256, 128
    img = Image.new("RGB", (w, h), (120, 196, 132))
    d = ImageDraw.Draw(img)
    dark = (24, 96, 52)
    for k in range(-h, w, 7):
        d.line([(k, 0), (k + h, h)], fill=(132, 206, 142), width=2)
    d.rectangle([3, 3, w - 4, h - 4], outline=dark, width=5)
    d.rectangle([12, 12, w - 13, h - 13], outline=(70, 150, 90), width=2)
    # Selo redondo no meio com o "C".
    cx, cy = w // 2, h // 2
    d.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], fill=(232, 246, 226), outline=dark, width=4)
    text_center(d, (cx, cy + 2), "C", font("Arial Black.ttf", 52), dark)
    num = font("Arial Black.ttf", 30)
    text_center(d, (44, 36), "100", num, dark)
    text_center(d, (w - 44, h - 36), "100", num, dark)
    text_center(d, (w - 50, 30), "CELER", font("Arial Bold.ttf", 16), dark)
    text_center(d, (50, h - 28), "CELER", font("Arial Bold.ttf", 16), dark)
    img.save(os.path.join(OUT, "nota.png"))


# --- Ataque: Carimbo INDEFERIDO ------------------------------------------------------

def indeferido_shape(w, h):
    def shape(d):
        d.rounded_rectangle([8, 8, w - 9, h - 9], 20, outline=255, width=11)
        d.rounded_rectangle([27, 27, w - 28, h - 28], 12, outline=255, width=4)
        text_center(d, (w // 2, h * 0.47), "INDEFERIDO", font("Arial Black.ttf", int(h * 0.255)), 255)
        text_center(d, (w // 2, h * 0.76), "ARQUIVE-SE  ·  CUMPRA-SE", font("Arial Bold.ttf", int(h * 0.11)), 255)
    return shape


def indeferido():
    """Marca "INDEFERIDO" (512 x 208, transparente) estampada atrás do kart atingido."""
    w, h = 512, 208
    ink_stamp(w, h, indeferido_shape(w, h), 11).save(os.path.join(OUT, "indeferido.png"))


def carimbo_etiqueta():
    """Etiqueta de papel (256 x 160) no alto do carimbo voador, com a marca impressa."""
    w, h = 256, 160
    img = Image.new("RGBA", (w, h), (247, 241, 222, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(190, 176, 140), width=6)
    mark = ink_stamp(512, 208, indeferido_shape(512, 208), 5).resize((224, 91), Image.LANCZOS)
    img.alpha_composite(mark, (16, 34))
    img.convert("RGB").save(os.path.join(OUT, "carimbo_etiqueta.png"))


# --- Ataque: Intimação -----------------------------------------------------------------

ENVELOPE = (236, 214, 168)
ENVELOPE_DARK = (196, 166, 112)


def scales(d, cx, cy, s, color):
    """Balança da justiça simplificada (centro em cx, cy; s = meia largura)."""
    d.line([cx, cy - s * 0.9, cx, cy + s * 0.8], fill=color, width=max(2, int(s * 0.12)))
    d.line([cx - s, cy - s * 0.6, cx + s, cy - s * 0.6], fill=color, width=max(2, int(s * 0.1)))
    for side in (-1, 1):
        px = cx + side * s
        d.line([px, cy - s * 0.6, px - s * 0.35, cy + s * 0.15], fill=color, width=max(1, int(s * 0.06)))
        d.line([px, cy - s * 0.6, px + s * 0.35, cy + s * 0.15], fill=color, width=max(1, int(s * 0.06)))
        d.chord([px - s * 0.42, cy - s * 0.1, px + s * 0.42, cy + s * 0.4], 0, 180, fill=color)
    d.rectangle([cx - s * 0.45, cy + s * 0.75, cx + s * 0.45, cy + s * 0.92], fill=color)


def paper_noise(img, rng, amount, color):
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(amount):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        d.point((x, y), fill=color)


def intimacao_frente():
    """Frente do envelope (512 x 352): remetente, INTIMAÇÃO, destinatário, selo, URGENTE."""
    w, h = 512, 352
    img = Image.new("RGBA", (w, h), ENVELOPE + (255,))
    rng = random.Random(21)
    paper_noise(img, rng, 2500, ENVELOPE_DARK + (255,))
    d = ImageDraw.Draw(img)
    navy = (28, 38, 74)
    d.rectangle([0, 0, w - 1, h - 1], outline=ENVELOPE_DARK, width=8)
    scales(d, 52, 58, 26, navy)
    d.text((92, 34), "PODER JUDICIÁRIO", font=font("Arial Black.ttf", 22), fill=navy)
    d.text((92, 64), "Vara das Execuções contra a Fazenda", font=font("Arial.ttf", 14), fill=navy)
    # Selo postal no canto (borda serrilhada).
    sx, sy = 412, 22
    d.rectangle([sx, sy, sx + 76, sy + 92], fill=(255, 255, 255))
    for k in range(0, 92, 8):
        d.ellipse([sx - 4, sy + k - 3, sx + 4, sy + k + 5], fill=ENVELOPE)
        d.ellipse([sx + 72, sy + k - 3, sx + 80, sy + k + 5], fill=ENVELOPE)
    d.rectangle([sx + 8, sy + 8, sx + 68, sy + 84], fill=(46, 126, 196))
    scales(d, sx + 38, sy + 42, 20, (255, 236, 160))
    text_center(d, (sx + 38, sy + 76), "R$ 0,01", font("Arial Bold.ttf", 11), (255, 255, 255))
    # INTIMAÇÃO grande.
    text_center(d, (w // 2, 160), "INTIMAÇÃO", font("Arial Black.ttf", 64), (176, 24, 30))
    d.line([60, 204, w - 60, 204], fill=navy, width=3)
    addr = font("Courier New Bold.ttf", 20)
    d.text((40, 222), "AO PILOTO DA FRENTE", font=addr, fill=navy)
    d.text((40, 250), "PISTA ATIVOS", font=addr, fill=navy)
    d.text((40, 278), "PRAZO: IMEDIATO", font=addr, fill=navy)
    barcode(d, [40, 310, 250, 334], random.Random(4), navy)
    # URGENTE carimbado torto.
    mark = ink_stamp(300, 100, lambda dd: (
        dd.rounded_rectangle([6, 6, 293, 93], 14, outline=255, width=8),
        text_center(dd, (150, 52), "URGENTE", font("Arial Black.ttf", 50), 255)), 8)
    mark = mark.rotate(14, expand=True, resample=Image.BICUBIC).resize((190, 90), Image.LANCZOS)
    img.alpha_composite(mark, (306, 206))
    img.convert("RGB").save(os.path.join(OUT, "intimacao_frente.png"))


def intimacao_verso():
    """Verso do envelope (512 x 352): a aba em V, o lacre de cera vermelho e INTIMAÇÃO
    (é o lado que a câmera vê, de trás)."""
    w, h = 512, 352
    img = Image.new("RGBA", (w, h), ENVELOPE + (255,))
    rng = random.Random(22)
    paper_noise(img, rng, 2500, ENVELOPE_DARK + (255,))
    d = ImageDraw.Draw(img)
    tip = (w // 2, int(h * 0.58))
    # Abas de baixo e dos lados (dobras), um pouco mais escuras.
    d.polygon([(0, h), (w // 2, int(h * 0.5)), (w, h)], fill=(226, 202, 152))
    d.polygon([(0, 0), (int(w * 0.46), int(h * 0.52)), (0, h)], fill=(230, 207, 158))
    d.polygon([(w, 0), (int(w * 0.54), int(h * 0.52)), (w, h)], fill=(230, 207, 158))
    # Aba de cima (V) com sombra.
    d.polygon([(0, 0), (w, 0), (tip[0], tip[1] + 6)], fill=(200, 172, 120))
    d.polygon([(0, 0), (w, 0), tip], fill=(242, 223, 182))
    for a, b in (((0, 0), tip), ((w, 0), tip), ((0, h), (w // 2, int(h * 0.5))), ((w, h), (w // 2, int(h * 0.5)))):
        d.line([a, b], fill=ENVELOPE_DARK, width=3)
    d.rectangle([0, 0, w - 1, h - 1], outline=ENVELOPE_DARK, width=8)
    d.text((26, 18), "Remetente: Tribunal de Justiça", font=font("Arial Bold.ttf", 15), fill=(110, 86, 48))
    # Lacre de cera na ponta da aba.
    cx, cy = tip
    rr = 46
    blob = []
    for i in range(36):
        a = math.tau * i / 36
        k = 1.0 + 0.08 * math.sin(a * 5 + 1.3) + 0.05 * math.sin(a * 9)
        blob.append((cx + math.cos(a) * rr * k, cy + math.sin(a) * rr * k))
    d.polygon([(x + 3, y + 5) for x, y in blob], fill=(110, 12, 16))
    d.polygon(blob, fill=(196, 28, 34))
    d.ellipse([cx - 32, cy - 32, cx + 32, cy + 32], outline=(140, 16, 22), width=4)
    scales(d, cx, cy + 2, 20, (120, 10, 16))
    d.ellipse([cx - 30, cy - 34, cx - 8, cy - 22], fill=(232, 96, 96))
    text_center(d, (w // 2, int(h * 0.85)), "INTIMAÇÃO", font("Arial Black.ttf", 46), (150, 20, 26))
    img.convert("RGB").save(os.path.join(OUT, "intimacao_verso.png"))


def capsule(draw, a, b, ra, rb, color, n=20):
    """Pena: forma alongada de `a` (raio ra) até `b` (raio rb), pontas redondas."""
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    pts = []
    for i in range(n + 1):
        t = ang + math.pi / 2 + math.pi * i / n
        pts.append((a[0] + math.cos(t) * ra, a[1] + math.sin(t) * ra))
    for i in range(n + 1):
        t = ang - math.pi / 2 + math.pi * i / n
        pts.append((b[0] + math.cos(t) * rb, b[1] + math.sin(t) * rb))
    draw.polygon(pts, fill=color)


def asa():
    """Asinha de penas branca (256 x 192, transparente). O ombro fica na borda esquerda
    (na altura de 40%); as penas compridas abrem em leque para a direita."""
    w, h = 256, 192
    sc = 4
    W, H = w * sc, h * sc
    line = (110, 136, 176, 255)
    fill = (255, 255, 255, 255)
    shade = (214, 228, 246, 255)
    px = lambda x, y: (x * W, y * H)
    feathers = [((0.35, 0.25), (0.96, 0.12), 0.11), ((0.32, 0.35), (0.92, 0.36), 0.12),
                ((0.27, 0.44), (0.80, 0.58), 0.12), ((0.20, 0.51), (0.62, 0.76), 0.115),
                ((0.12, 0.55), (0.40, 0.86), 0.105)]
    border = 6 * sc
    big = Image.new("RGBA", (W, H), line[:3] + (0,))
    d = ImageDraw.Draw(big)
    for a, b, r in reversed(feathers):
        ra, rb = r * H, r * H * 0.5
        capsule(d, px(*a), px(*b), ra + border, rb + border, line)
        capsule(d, px(*a), px(*b), ra, rb, fill)
        # Metade de baixo da pena um pouco azulada.
        mid_a = (px(*a)[0], px(*a)[1] + ra * 0.45)
        mid_b = (px(*b)[0], px(*b)[1] + rb * 0.45)
        capsule(d, mid_a, mid_b, ra * 0.42, rb * 0.42, shade)
    # Cobertura do ombro por cima das raízes das penas.
    cx, cy = px(0.3, 0.33)
    rx, ry = 0.27 * W, 0.24 * H
    d.ellipse([cx - rx - border, cy - ry - border, cx + rx + border, cy + ry + border], fill=line)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill)
    d.ellipse([cx - rx * 0.5, cy + ry * 0.05, cx + rx * 0.75, cy + ry * 0.7], fill=shade)
    big.paste(Image.new("RGBA", (border, H), line[:3] + (0,)), (0, 0))
    img = big.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, "asa.png"))


# --- Ataque: PEC dos Precatórios -------------------------------------------------------

def constituicao_capa():
    """Capa da Constituição (512 x 692, proporção do livro de 4 x 5,4 m): azul-marinho com
    frisos e letras douradas e um post-it amarelo "PEC DOS PRECATÓRIOS" colado."""
    w, h = 512, 692
    img = Image.new("RGBA", (w, h), (24, 52, 120, 255))
    rng = random.Random(31)
    paper_noise(img, rng, 5000, (30, 62, 138, 255))
    d = ImageDraw.Draw(img)
    gold = (232, 192, 92)
    d.rectangle([22, 22, w - 23, h - 23], outline=gold, width=6)
    d.rectangle([38, 38, w - 39, h - 39], outline=gold, width=2)
    text_center(d, (w // 2, 140), "CONSTITUIÇÃO", font("Arial Black.ttf", 50), gold)
    text_center(d, (w // 2, 192), "DA REPÚBLICA FEDERATIVA", font("Arial Bold.ttf", 26), gold)
    text_center(d, (w // 2, 223), "DO BRASIL", font("Arial Bold.ttf", 26), gold)
    # Emblema: estrela dentro de dois círculos.
    cx, cy = w // 2, 352
    d.ellipse([cx - 92, cy - 92, cx + 92, cy + 92], outline=gold, width=6)
    d.ellipse([cx - 74, cy - 74, cx + 74, cy + 74], outline=gold, width=2)
    star = []
    for i in range(10):
        a = -math.pi / 2 + math.pi * i / 5
        r = 62 if i % 2 == 0 else 26
        star.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(star, fill=gold)
    text_center(d, (140, 600), "1988", font("Arial Black.ttf", 44), gold)
    # Post-it amarelo torto no canto de cima.
    note = Image.new("RGBA", (220, 170), (255, 226, 74, 255))
    nd = ImageDraw.Draw(note)
    nd.rectangle([0, 0, 219, 26], fill=(255, 212, 40, 255))
    text_center(nd, (110, 70), "PEC DOS", font("Arial Black.ttf", 30), (44, 40, 90))
    text_center(nd, (110, 112), "PRECATÓRIOS", font("Arial Black.ttf", 26), (44, 40, 90))
    text_center(nd, (110, 146), "parcela tudo!", font("Bradley Hand Bold.ttf", 20), (180, 30, 40))
    shadow = Image.new("RGBA", note.size, (0, 0, 0, 90))
    shadow = shadow.rotate(-8, expand=True, resample=Image.BICUBIC)
    note = note.rotate(-8, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(shadow, (262, 470))
    img.alpha_composite(note, (254, 458))
    img.convert("RGB").save(os.path.join(OUT, "constituicao_capa.png"))


def paginas():
    """Bordas das páginas (64 x 64): creme com listrinhas horizontais."""
    w, h = 64, 64
    img = Image.new("RGB", (w, h), (246, 240, 222))
    d = ImageDraw.Draw(img)
    for y in range(0, h, 4):
        d.line([0, y, w, y], fill=(214, 204, 178), width=1)
    img.save(os.path.join(OUT, "paginas.png"))


# --- Ataque: Impugnação dos cálculos ----------------------------------------------------

def calculadora():
    """Frente da calculadora (384 x 544): marca, painel solar, visor vazio (de 40 a 136 de
    altura) e as teclas. O visor fica no alto da imagem."""
    w, h = 384, 544
    img = Image.new("RGB", (w, h), (52, 58, 72))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, w - 5, h - 5], 26, outline=(30, 34, 44), width=8)
    d.text((26, 14), "IMPUGNA·CALC", font=font("Arial Black.ttf", 18), fill=(220, 226, 236))
    for k in range(4):
        d.rectangle([236 + k * 30, 14, 262 + k * 30, 32], fill=(40, 30, 50), outline=(90, 80, 110))
    # Visor (os algarismos são um Label3D por cima).
    d.rounded_rectangle([22, 40, w - 23, 136], 10, fill=(34, 38, 48))
    d.rounded_rectangle([30, 46, w - 31, 130], 6, fill=(170, 190, 150))
    keys = [["C", "±", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["0", ",", "=", ""]]
    kw, kh, gap = 76, 64, 12
    x0, y0 = 26, 156
    kf = font("Arial Black.ttf", 30)
    for r, row in enumerate(keys):
        for c, label in enumerate(row):
            if label == "":
                continue
            x, y = x0 + c * (kw + gap), y0 + r * (kh + gap)
            if label == "C":
                col, txt = (220, 60, 60), (255, 255, 255)
            elif label == "=":
                col, txt = (255, 140, 30), (255, 255, 255)
                # "=" ocupa duas colunas.
                d.rounded_rectangle([x, y + 4, x + kw * 2 + gap, y + kh + 4], 12, fill=(20, 22, 30))
                d.rounded_rectangle([x, y, x + kw * 2 + gap, y + kh], 12, fill=col)
                text_center(d, (x + kw + gap // 2, y + kh // 2), label, kf, txt)
                continue
            elif c == 3:
                col, txt = (96, 110, 140), (255, 255, 255)
            else:
                col, txt = (226, 230, 238), (40, 44, 56)
            d.rounded_rectangle([x, y + 4, x + kw, y + kh + 4], 12, fill=(20, 22, 30))
            d.rounded_rectangle([x, y, x + kw, y + kh], 12, fill=col)
            text_center(d, (x + kw // 2, y + kh // 2), label, kf, txt)
    img.save(os.path.join(OUT, "calculadora.png"))


def numeros():
    """Atlas 4 x 4 (512 x 512, transparente) da chuva de números: brancos com contorno
    escuro (a cor de cada partícula tinge o branco)."""
    w, h = 512, 512
    cell = 128
    glyphs = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "%", "R$", "+", "−", "×", "="]
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for i, g in enumerate(glyphs):
        cx = (i % 4) * cell + cell // 2
        cy = (i // 4) * cell + cell // 2
        size = 70 if g == "R$" else 96
        d.text((cx, cy), g, font=font("Arial Black.ttf", size), fill=(255, 255, 255, 255), anchor="mm",
               stroke_width=9, stroke_fill=(20, 26, 56, 255))
    img.save(os.path.join(OUT, "numeros.png"))


# --- Armadilha: Pendência documental e Fila do tribunal ----------------------------------

PENDENCIAS = [
    "Procuração com firma reconhecida",
    "Certidão negativa de débitos",
    "RG autenticado em cartório",
    "Comprovante de residência",
    "Cálculo atualizado",
    "Cópia da cópia autenticada",
]


def pendencia_folha():
    """Folha da pilha de papel (256 x 320): a lista de documentos que faltam, cada um
    com um "X" vermelho, e o carimbo PENDENTE torto. É o papel de cima da pilha e as
    folhas que voam em quem escorrega nela."""
    w, h = 256, 320
    img = Image.new("RGBA", (w, h), (251, 248, 236, 255))
    rng = random.Random(31)
    paper_noise(img, rng, 900, (226, 220, 200, 255))
    d = ImageDraw.Draw(img)
    navy = (22, 30, 70)
    gray = (70, 74, 92)
    d.rectangle([0, 0, w - 1, h - 1], outline=(200, 192, 168), width=4)
    scales(d, 34, 34, 16, navy)
    d.text((58, 18), "PODER JUDICIÁRIO", font=font("Arial Black.ttf", 14), fill=navy)
    d.text((58, 38), "Cartório da Vara de Execuções", font=font("Arial.ttf", 10), fill=gray)
    d.line([16, 60, w - 16, 60], fill=navy, width=2)
    text_center(d, (w // 2, 80), "PENDÊNCIA DOCUMENTAL", font("Arial Black.ttf", 16), (176, 24, 30))
    item = font("Arial.ttf", 12)
    y = 104
    for name in PENDENCIAS:
        d.rectangle([18, y, 32, y + 14], outline=navy, width=2)
        d.line([22, y + 3, 29, y + 11], fill=(200, 30, 36), width=3)
        d.line([29, y + 3, 22, y + 11], fill=(200, 30, 36), width=3)
        d.text((40, y), name, font=item, fill=(40, 42, 56))
        y += 26
    d.text((18, y + 6), "Prazo: 15 dias úteis (renováveis)", font=font("Arial Italic.ttf", 11), fill=gray)
    mark = ink_stamp(300, 100, lambda dd: (
        dd.rounded_rectangle([6, 6, 293, 93], 14, outline=255, width=8),
        text_center(dd, (150, 52), "PENDENTE", font("Arial Black.ttf", 46), 255)), 13)
    mark = mark.rotate(-16, expand=True, resample=Image.BICUBIC).resize((170, 78), Image.LANCZOS)
    img.alpha_composite(mark, (70, 228))
    img.convert("RGB").save(os.path.join(OUT, "pendencia_folha.png"))


def senha():
    """Senha de atendimento (256 x 400, transparente fora do papel): papel térmico com as
    bordas serrilhadas, "SENHA", o espaço do número (desenhado no jogo, muda a cada vez)
    e AGUARDE SUA VEZ embaixo."""
    w, h = 256, 400
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Papel com o picote de cima e de baixo em zigue-zague.
    top, bottom, tooth = 10, h - 10, 12
    pts = []
    for x in range(0, w + 1, tooth):
        pts.append((x, top + (0 if (x // tooth) % 2 == 0 else 8)))
    for x in range(w, -1, -tooth):
        pts.append((x, bottom - (0 if (x // tooth) % 2 == 0 else 8)))
    d.polygon(pts, fill=(255, 253, 244, 255))
    navy = (22, 30, 70)
    gray = (96, 100, 116)
    scales(d, w // 2, 48, 18, navy)
    text_center(d, (w // 2, 84), "TRIBUNAL DA PISTA", font("Arial Bold.ttf", 17), navy)
    text_center(d, (w // 2, 104), "Protocolo e Atendimento", font("Arial.ttf", 12), gray)
    for k in range(16, w - 16, 10):
        d.line([k, 122, k + 5, 122], fill=gray, width=2)
    text_center(d, (w // 2, 146), "SENHA", font("Arial Black.ttf", 26), navy)
    # (O número entra aqui, entre y = 165 e 255.)
    for k in range(16, w - 16, 10):
        d.line([k, 268, k + 5, 268], fill=gray, width=2)
    text_center(d, (w // 2, 296), "AGUARDE", font("Arial Black.ttf", 32), (176, 24, 30))
    text_center(d, (w // 2, 332), "SUA VEZ", font("Arial Black.ttf", 32), (176, 24, 30))
    text_center(d, (w // 2, 364), "Previsão: indeterminada", font("Arial Italic.ttf", 12), gray)
    img.save(os.path.join(OUT, "senha.png"))


# --- Defesa: Liminar -----------------------------------------------------------------------

def shield_polygon(cx, cy, s):
    """Brasão (o mesmo de RaceItem.shield_points): topo com as pontas para cima, lados
    retos e a ponta embaixo. s = meia largura."""
    pts = [(-1.0, -1.15), (-0.5, -1.0), (0.0, -1.12), (0.5, -1.0), (1.0, -1.15)]
    p0, p1, p2 = (1.0, 0.1), (1.0, 0.95), (0.0, 1.3)
    side = []
    for i in range(9):
        t = i / 8.0
        side.append(tuple(p0[k] * (1 - t) ** 2 + p1[k] * 2 * (1 - t) * t + p2[k] * t * t for k in range(2)))
    pts += side + [(-x, y) for x, y in reversed(side[:-1])]
    return [(cx + x * s, cy + y * s) for x, y in pts]


def liminar():
    """Escudo-documento da Liminar (512 x 640, transparente fora do brasão): papel com a
    borda verde, PODER JUDICIÁRIO, o texto da decisão e o carimbo LIMINAR DEFERIDA."""
    w, h = 512, 640
    s = 228
    cx, cy = w // 2, 292
    green = (24, 140, 72)
    navy = (22, 30, 70)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outer = shield_polygon(cx, cy, s + 12)
    d.polygon(outer, fill=(16, 96, 50, 255))
    d.polygon(shield_polygon(cx, cy, s), fill=(252, 249, 236, 255))
    inner = shield_polygon(cx, cy, s - 22)
    d.line(inner + [inner[0]], fill=green + (255,), width=5)
    scales(d, cx, 98, 24, navy)
    text_center(d, (cx, 144), "PODER JUDICIÁRIO", font("Arial Black.ttf", 26), navy)
    text_center(d, (cx, 172), "Decisão interlocutória", font("Arial.ttf", 16), (70, 74, 92))
    body = font("Courier New.ttf", 15)
    lines = ["Presentes o fumus boni iuris", "e o periculum in mora,", "DEFIRO a tutela para suspender",
             "todo e qualquer ato contra o", "piloto, inclusive a PEC.", "Cumpra-se com urgência."]
    y = 200
    for line in lines:
        text_center(d, (cx, y), line, body, (40, 42, 56))
        y += 21
    # Assinatura.
    pts = []
    for k in range(80):
        t = k / 79.0
        pts.append((cx - 80 + t * 160, 350 + 10 * math.sin(t * 17.0) - 8 * t))
    d.line(pts, fill=(20, 40, 120), width=3, joint="curve")
    text_center(d, (cx, 378), "Juiz(a) de Plantão", font("Arial.ttf", 13), (70, 74, 92))
    # Carimbo LIMINAR DEFERIDA, verde e torto, por cima de tudo (cortado na borda do papel).
    def stamp_shape(dd):
        dd.rounded_rectangle([8, 8, 431, 171], 20, outline=255, width=11)
        dd.rounded_rectangle([26, 26, 413, 153], 12, outline=255, width=4)
        text_center(dd, (220, 70), "LIMINAR", font("Arial Black.ttf", 64), 255)
        text_center(dd, (220, 128), "DEFERIDA", font("Arial Black.ttf", 40), 255)
    mark = ink_stamp(440, 180, stamp_shape, 17)
    r, g, b, a = mark.split()
    mark = Image.merge("RGBA", (r.point(lambda v: 26), g.point(lambda v: 150), b.point(lambda v: 74), a))
    mark = mark.rotate(10, expand=True, resample=Image.BICUBIC).resize((360, 186), Image.LANCZOS)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.alpha_composite(mark, (cx - 180, 392))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(outer, fill=255)
    lr, lg, lb, la = layer.split()
    layer = Image.merge("RGBA", (lr, lg, lb, Image.composite(la, Image.new("L", (w, h), 0), mask)))
    img.alpha_composite(layer)
    img.save(os.path.join(OUT, "liminar.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    rpv_guia()
    oficio()
    carimbo()
    nota()
    indeferido()
    carimbo_etiqueta()
    intimacao_frente()
    intimacao_verso()
    asa()
    constituicao_capa()
    paginas()
    calculadora()
    numeros()
    pendencia_folha()
    senha()
    liminar()
    for name in sorted(os.listdir(OUT)):
        if name.endswith(".png"):
            print("%-20s %d KB" % (name, os.path.getsize(os.path.join(OUT, name)) // 1024))


if __name__ == "__main__":
    main()
