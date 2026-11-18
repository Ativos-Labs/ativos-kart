"""Renderiza os glb de poses_nos_karts.gd no Blender (sem janela, EEVEE): para cada kart,
vista de lado, de frente (3/4), de cima, perto do piloto e um corte de lado a 19 cm do
meio do kart (aparecem pernas e pés escondidos pela carenagem).

  Blender -b --factory-startup -P tools/personagens/render_poses.py -- <prefixo_saida> <arquivos.glb...>

Grava <prefixo_saida><nome do glb>_<vista>.png.
"""
import bpy, sys, math, mathutils  # noqa: E401
argv = sys.argv[sys.argv.index('--')+1:]
out_prefix = argv[0]; files = argv[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 640; sc.render.resolution_y = 520
sc.render.film_transparent = False
w = bpy.data.worlds.new('w'); sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.55, 0.6, 0.68, 1); bg.inputs[1].default_value = 1.0
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'
G2B = lambda v: mathutils.Vector((v[0], -v[2], v[1]))
# Vistas no espaço do kart (Godot: frente = -Z, +X = direita). Centro no cockpit.
views = {
    'lado': ((-1, 0.0, 0), 1.6),        # do lado esquerdo do kart
    'frente34': ((-0.8, 0.35, -1.0), 1.6),
    'cima': ((0, 1, 0.001), 1.6),
    'piloto': ((-0.9, 0.25, -0.15), 0.95),
    'corte': ((-1, 0.0, 0), 1.0),
}
for f in files:
    for o in list(sc.objects):
        if o.type not in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
    bpy.ops.import_scene.gltf(filepath=f)
    name = f.split('/')[-1].replace('.glb', '')
    meshes = [o for o in sc.objects if o.type == 'MESH']
    lo = mathutils.Vector((1e9,)*3); hi = -lo
    for o in meshes:
        for c in o.bound_box:
            p = o.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, p)); hi = mathutils.Vector(map(max, hi, p))
    center = (lo + hi) / 2
    center.z = (lo.z + hi.z) / 2
    for vname, (d, size) in views.items():
        dv = G2B(d).normalized()
        c = center
        if vname == 'piloto':
            # perto do piloto: centro na altura do volante
            c = mathutils.Vector((center.x, center.y, lo.z + (hi.z - lo.z) * 0.55))
        cam.data.ortho_scale = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * (1.15 if vname != 'piloto' else 0.7)
        cam.location = c + dv * 5
        up = 'Y' if vname == 'cima' else 'Y'
        cam.rotation_euler = (-dv).to_track_quat('-Z', 'Y').to_euler()
        cam.data.clip_start = 0.1
        if vname == 'corte':
            # Corta o kart num plano a 19 cm do meio (lado esquerdo): aparecem pernas e pés.
            c = mathutils.Vector((0.0, center.y, lo.z + (hi.z - lo.z) * 0.45))
            cam.location = c + dv * 5
            cam.data.clip_start = 5 - 0.19
            cam.data.ortho_scale = max(hi.y - lo.y, hi.z - lo.z) * 0.8
        sc.render.filepath = f'{out_prefix}{name}_{vname}.png'
        bpy.ops.render.render(write_still=True)
