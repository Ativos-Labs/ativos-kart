"""Roda dentro do Blender (chamado por rig_henrique.py):

  Blender -b --factory-startup --python-exit-code 1 -P blender_pesos.py -- entrada.npz saida.npz

Entrada (npz, espaço do Blender: +Z para cima, -Y para a frente):
- verts (V, 3), faces (F, 3): a malha do corpo, com os vértices repetidos já juntados;
- bones (B,), heads (B, 3), tails (B, 3): os ossos que recebem peso automático;
- opcional: image (caminho de um PNG) e uv (N, 2): devolve a cor da textura nesses UVs.

Saída (npz): weights (V, B) com os pesos automáticos do Blender (bone heat, o "With
Automatic Weights" de Ctrl+P) e, se pedido, colors (N, 4) em sRGB de 0 a 1.
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
data = np.load(args[0], allow_pickle=False)
out = {}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

verts = data["verts"]
faces = data["faces"]
mesh = bpy.data.meshes.new("corpo")
mesh.from_pydata(verts.tolist(), [], faces.tolist())
mesh.validate()
mesh.update()
body = bpy.data.objects.new("corpo", mesh)
scene.collection.objects.link(body)

arm_data = bpy.data.armatures.new("esqueleto")
arm = bpy.data.objects.new("esqueleto", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
names = [str(n) for n in data["bones"]]
for name, head, tail in zip(names, data["heads"], data["tails"]):
    eb = arm_data.edit_bones.new(name)
    eb.head = head.tolist()
    eb.tail = tail.tolist()
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

if len(mesh.vertices) != len(verts):
    raise SystemExit("o Blender mudou o número de vértices (%d -> %d)" % (len(verts), len(mesh.vertices)))
W = np.zeros((len(verts), len(names)), dtype=np.float32)
group_bone = {g.index: names.index(g.name) for g in body.vertex_groups if g.name in names}
for v in mesh.vertices:
    for g in v.groups:
        if g.group in group_bone:
            W[v.index, group_bone[g.group]] = g.weight
out["weights"] = W
print("pesos automáticos: %d vértices, %d sem peso" % (len(W), int((W.sum(1) < 1e-4).sum())))

if "image" in data.files:
    img = bpy.data.images.load(str(data["image"]))
    img.colorspace_settings.name = "Non-Color"  # valores do arquivo, sem conversão
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = data["uv"]
    # UV do glTF: v = 0 em cima; o Blender guarda as linhas de baixo para cima.
    x = np.clip((uv[:, 0] % 1.0) * w, 0, w - 1).astype(int)
    y = np.clip((uv[:, 1] % 1.0) * h, 0, h - 1).astype(int)
    out["colors"] = px[h - 1 - y, x]

np.savez(args[1], **out)
