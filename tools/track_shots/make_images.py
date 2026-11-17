"""Converte os prints do probe nas imagens da tela de pistas.

Uso: python3 -I make_images.py <log_dos_prints> <pasta_saida>
  <log>.<id>_fundo.png  (1920x1080) -> <id>_fundo.jpg   vista aérea, fundo da tela
  <log>.<id>_cartao.png (1920x1080) -> <id>_cartao.jpg  448x300, foto do cartão
"""
import glob
import os
import sys

from PIL import Image

CARD = (448, 300)

log, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for path in sorted(glob.glob(glob.escape(log) + ".*.png")):
    name = path[len(log) + 1:-4]
    im = Image.open(path).convert("RGB")
    if name.endswith("_cartao"):
        # Mesmo enquadramento da câmera do cartão: corta o meio na proporção 448:300
        # (o campo de visão vertical é o mesmo) e reduz.
        w = round(im.height * CARD[0] / CARD[1])
        x = (im.width - w) // 2
        im = im.crop((x, 0, x + w, im.height)).resize(CARD, Image.LANCZOS)
        quality = 92
    elif name.endswith("_fundo"):
        quality = 88
    else:
        continue
    dest = os.path.join(out, name + ".jpg")
    im.save(dest, quality=quality, optimize=True, progressive=False)
    print(f"{dest}  {im.size[0]}x{im.size[1]}  {os.path.getsize(dest) // 1024} KB")
