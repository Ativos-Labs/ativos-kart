# Celerino — rig & animation guide

Reference for using `celerino.glb` in Godot and for updating it from Blender.
Every number here was taken from the exported `.glb`. Godot-side values were read
back from the file, not assumed from Blender.

> **Notas do Ativos Kart**
> - O Godot remove o sufixo `_loop` no import: os clipes viram `idle`, `walk` e `gesture_wave` (já com loop).
> - No import, todos os clipes trazem trilhas para ~54 ossos (não só os que animam). Por isso o
>   jogo mistura as animações por código, com máscaras de ossos — veja `scripts/character_rig.gd`.
> - Os arquivos `.blend` e o vídeo citados abaixo não estão neste projeto, só o `celerino.glb`.

## Files

| File | What it is |
|---|---|
| `celerino.glb` | **The game asset.** Skinned model, 65-bone skeleton, 13 plain-color materials, 48 baked animations. |
| `celerino_rigged.blend` | Master source. Rig, controls, Blender test animation, cel-shaded preview. Edit here, then re-export. |
| `celerino_editable.blend` | Pre-rig version with live modifiers (shape changes only). |
| `celerino_rig_ready.blend` | Obsolete intermediate. Safe to delete. |
| `celerino_test_reel.mp4` | 22 s preview of the walk, look-around, gestures and expressions. |
| `RIG.md` | This file. |

## Quick facts

- **Size / units:** about 2 m tall, metres. The origin is between the feet, which rest on Y = 0.
- **Facing:** the character faces **+Z**, the glTF / Godot model-front convention.
- **Left / right:** `.L` = the character's own left = **+X**.
- **Meshes (10):** `Celerino_Body`, `Celerino_Arm.L/.R`, `Celerino_Leg.L/.R`, `Celerino_Eye.L/.R`, `Celerino_Brow.L/.R`, `Celerino_Mouth`. All skinned to one skeleton, with at most 4 bones per vertex.
- **Materials:** 13 flat colors named `Cel_*`. No textures. One UV map (`UVMap`, a non-overlapping atlas) is ready if you add some. The cel shading and ink outlines seen in the Blender preview are Blender-only; rebuild them as Godot shaders.

## Using it in Godot

1. Drop `celerino.glb` into the project. It imports as a scene with a `Skeleton3D`, 10 `MeshInstance3D`s and an `AnimationPlayer` holding the 48 clips.
2. **Looping:** clips whose names end in `_loop` (`idle_loop`, `walk_loop`, `gesture_wave_loop`) should import with looping on. If one doesn't, set its Loop Mode in *Advanced Import Settings → Animations*.
3. **Layering:** each clip only animates the bones listed for it in the table below. For example, a face clip contains only face tracks, so it can sit on top of a body clip.
   - Build an `AnimationTree` with locomotion at the bottom (`idle_loop` / `walk_loop`), then layer gestures, hands, face, eyes and `blink`, in that order.
   - Godot 4.2+ AnimationTrees are *deterministic* by default. In that mode, tracks missing from a clip blend back toward rest, so turn on **filters** on each `Blend2` node and tick only that layer's bones. Alternatively, set the tree's `deterministic` to false.
   - Body bends (`body_*`) work well through an `Add2` node on top of idle or walk.
4. **Walk speed:** `walk_loop` is in place (1 s cycle). Move the character body at about **0.44 m/s** to keep the feet from sliding.

## Animation library (48 clips)

Single-pose clips are 1 frame long (0.042 s). Hold them with a blend amount, or loop them.

| Clips | Bones animated | Notes |
|---|---|---|
| `face_neutral`, `face_happy`, `face_smiling`, `face_surprised`, `face_angry`, `face_confused`, `face_eepy`, `face_sleeping`, `face_screaming` | 13 face bones (eyelids, brows, lip corners, `mouth`, `jaw`, teeth, `tongue`, `eye.L/.R`) | Full expressions, including where the eyes look. `face_smiling`, `face_confused`, `face_eepy` and `face_sleeping` use the closed mouth. |
| `mouth_closed`, `mouth_open`, `mouth_open_wide` | `jaw`, `teeth_upper`, `teeth_lower`, `tongue` | For talking / lip flaps. Layer above a face clip. |
| `blink` | `eyelid.L/.R` | 7 frames: open → closed → open. Play it as a OneShot above the face layer. |
| `eyes_center`, `eyes_look_left`, `eyes_look_right`, `eyes_look_up`, `eyes_look_down` | `eye.L/.R` | Good as a BlendSpace2D. "Left" is the character's left. |
| `hand_{open,relaxed,fist,point,thumbs_up,peace}_L` / `_R` | that hand's 12 finger and thumb bones | Hand shapes only, no arm. |
| `gesture_arms_down`, `gesture_thumbs_up`, `gesture_point`, `gesture_cheer`, `gesture_shrug`, `gesture_jazz_hands`, `gesture_angry_fists`, `gesture_hands_on_cheeks`, `gesture_wave_loop` | both arms (`upper_arm`, `forearm`, `hand`) + both hands' fingers | Full arm + hand poses. `gesture_wave_loop` is a 0.5 s wave with the right hand. |
| `body_lean_forward`, `body_lean_back`, `body_bend_left`, `body_bend_right`, `body_twist_left`, `body_twist_right` | `body_02`–`body_05` | Smooth whole-page bends (20°, 15°, 20°, 20°, 30°, 30°). |
| `idle_loop` | `body_01`–`body_05`, both arms | 2 s breathing idle. Fingers are not animated, so layer `hand_relaxed_*`. |
| `walk_loop` | `body_01`–`body_05`, both legs (`thigh`, `shin`, `foot`, `toe`), both arms | 1 s walk in place. Feet roll heel to toe, and the shoe bends at `toe`. |
| `demo_reel` | all deforming bones + `root` | The 22 s test reel, with root motion (moves about 2.3 m forward). For reference and testing. |

## Skeleton (65 bones)

| Group | Bones | Notes |
|---|---|---|
| Root | `root` | Parent of everything. Only `demo_reel` moves it. |
| Spine | `body_01` … `body_05` (bottom → top) | Weights are a smooth gradient, so bending several bones gives an even curve. `body_01` carries the legs, `body_03` the arms and mouth, `body_04` the eyes, `body_05` the brows. |
| Face | `mouth` → `jaw` → `teeth_lower`, `tongue`; `mouth` → `teeth_upper`, `lip_corner.L/.R`; `eye.L/.R`, `eyelid.L/.R` (on `body_04`); `brow.L/.R` (on `body_05`) | See the next section. |
| Arms | `upper_arm`, `forearm`, `hand` (.L/.R) | |
| Fingers | `index_01-03`, `middle_01-03`, `pinky_01-03`, `thumb_01-03` (.L/.R) | Three fingers plus a thumb. Rotating `_01`–`_03` about their local X curls them. |
| Legs | `thigh`, `shin`, `foot`, `toe` (.L/.R) | `toe` bends the shoe at the ball of the foot. |
| **Inert in Godot** | `body_bend`, `eyes_target`, `eye_target.L/.R`, `foot_ik.L/.R`, `knee_pole.L/.R` | Blender-only controls. They drive other bones through constraints, which don't export. In Godot they do nothing. Their effects are already baked into the clips. |

## Driving the face from code

All face controls are **position offsets from the bone's rest position**, in the bone's parent space, which is what `Skeleton3D.set_bone_pose_position()` expects:

```gdscript
var b := skeleton.find_bone("jaw")
skeleton.set_bone_pose_position(b, skeleton.get_bone_rest(b).origin + Vector3(0, 0.105, 0))  # close mouth
```

| Bone | Axis (Godot) | Values |
|---|---|---|
| `jaw` | Y | `0` = default open smile · **`+0.105` = fully closed** (dark mouth line shows) · `-0.11` = wide scream. Don't go past these. |
| `teeth_upper` | Y | `+0.045` tucks the upper teeth away. Use this whenever the mouth is closed. |
| `teeth_lower` | Y | `0` = hidden inside the face · `-0.055`…`-0.06` = lower teeth showing (big grin, scream). |
| `lip_corner.L` / `.R` | X, Y | X: `+X` is toward the character's left, so outward is `+X` for `.L` and `-X` for `.R`. Range about 0.015 outward, 0.05 inward. Y: up to `+0.016` (smile), down to `-0.035` (frown). |
| `mouth` | X | Shifts the whole mouth sideways, about ±0.04. |
| `eyelid.L` / `.R` | Y | `0` = open · `-0.19` = sleepy half-lid · **`-0.332` = fully closed**. Not clamped in Godot. |
| `brow.L` / `.R` | Y, rotation Z | Y `+0.045` raised, `-0.025` lowered. Rotation about local Z: `.L` positive / `.R` negative (about 20°) = angry (inner ends down); the opposite = worried. |
| `eye.L` / `.R` | rotation | The bone's local **+Y points out of the face**. Rotate it so +Y aims at the look target, for example with `LookAtModifier3D` (Godot 4.4+, forward axis +Y) or your own look-at code. Keep within about 30° of straight ahead; past about 35° the iris reaches the socket rim. |

## Working in Blender

- **Re-export:** open `celerino_rigged.blend`, go to the *Text Editor*, open `export_celerino_godot.py` and press **Alt+P**. The script:
  - writes `celerino.glb` next to the .blend;
  - exports every action that has the custom property `godot_export`;
  - mutes the rig constraints and hides the preview outlines during export;
  - trims each clip to the bones its action animates.
- **Add a clip:** create an action and keyframe the *deforming* bones directly. Then add the custom property `godot_export` (any value) to the action. If you animate with the controls (`body_bend`, `eyes_target`, `foot_ik`), first bake to the deforming bones with *Pose → Animation → Bake Action* (Visual Keying on). The export mutes constraints, so control motion that isn't baked is lost.
- **In-Blender preview:** the active action `Celerino_TestReel` uses the controls, plays with the EEVEE cel shader and outlines, and is followed by `PreviewCam`. The baked `godot_export` actions are meant for export; previewed in Blender, the constraints override some of their keys.
- **Controls (Blender only):**
  - `body_bend` bends the whole spine evenly (rotate X / Y / Z).
  - `eyes_target` aims both eyes.
  - `foot_ik.L/.R` with `knee_pole.L/.R` is leg IK.
  - Limits keep the eyelids and lip corners in range.

## Known limits

- **Irises:** they float about 8 mm in front of the eye white so they never clip while moving. That's barely visible at extreme side angles.
- **Mouth corners:** they can show tiny dark specks in close-ups when pushed to the ends of their range.
- **No textures:** materials are flat colors only.
