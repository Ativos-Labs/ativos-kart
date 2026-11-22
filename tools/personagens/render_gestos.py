"""Renderiza no Blender (sem janela, EEVEE) os glb de quadros_gesto.gd e monta uma folha:
uma linha por vista, uma coluna por quadro, na ordem dos arquivos.

  Blender -b --factory-startup -P tools/personagens/render_gestos.py -- <folha.png> <vistas> <arquivos.glb...>

Vistas (separadas por vírgula): jogo (a câmera da tela de seleção, mais fechada), 34 (3/4
pelo lado direito do personagem), lado (perfil direito), esq (perfil esquerdo), cima.
"""
import math
import os
import sys
import tempfile

import bpy
import mathutils
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
sheet_path = argv[0]
wanted = argv[1].split(',')
files = argv[2:]
W, H = 360, 460

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = W
sc.render.resolution_y = H
world = bpy.data.worlds.new('w')
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs[0].default_value = (0.5, 0.55, 0.65, 1)
bg.inputs[1].default_value = 1.1
sun = bpy.data.objects.new('sol', bpy.data.lights.new('sol', 'SUN'))
sc.collection.objects.link(sun)
sun.data.energy = 3.0
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.sensor_fit = 'VERTICAL'


def godot(x, y, z):
    """Ponto no espaço do Godot (Y para cima, frente +Z) → Blender."""
    return mathutils.Vector((x, -z, y))


# O personagem fica de frente para +Z, com ~1,9 m (escala da vitrine); a câmera mira 1 m de altura.
target = godot(0, 1.0, 0)
views = {
    'jogo': godot(0, 1.45, 5.6),
    '34': godot(-3.9, 1.6, 3.9),
    'lado': godot(-5.6, 1.2, 0.0),
    'esq': godot(5.6, 1.2, 0.0),
    'cima': godot(0.0, 6.0, 1.2),
}
tmp = tempfile.mkdtemp()
shots = {v: [] for v in wanted}
for f in files:
    for o in list(sc.objects):
        if o.type not in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o)
    bpy.ops.import_scene.gltf(filepath=f)
    name = os.path.basename(f).replace('.glb', '')
    for v in wanted:
        loc = views[v]
        cam.location = loc
        cam.rotation_euler = (target - loc).normalized().to_track_quat('-Z', 'Y').to_euler()
        cam.data.angle = math.radians(23.0)
        sun.rotation_euler = (math.radians(45), 0, math.atan2(loc.x, -loc.y) * 0.5)
        path = os.path.join(tmp, f'{name}_{v}.png')
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        shots[v].append(path)

# Folha: linhas = vistas, colunas = quadros (a origem das imagens do Blender é embaixo).
cols = len(files)
rows = len(wanted)
pixels = np.ones((rows * H, cols * W, 4), dtype=np.float32)
for r, v in enumerate(wanted):
    for c, path in enumerate(shots[v]):
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
        y0 = (rows - 1 - r) * H
        pixels[y0:y0 + H, c * W:(c + 1) * W] = px
        bpy.data.images.remove(img)
sheet = bpy.data.images.new('folha', cols * W, rows * H, alpha=True)
sheet.pixels = pixels.ravel()
sheet.filepath_raw = sheet_path
sheet.file_format = 'PNG'
sheet.save()
print(f'folha: {sheet_path} ({cols} quadros x {rows} vistas)')
