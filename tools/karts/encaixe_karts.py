"""Encaixe piloto × kart: redimensiona cada veículo para os pilotos caberem nele em escala 1.

Regra do documento "Encaixe Piloto × Kart" (kart-compare.blend, cena Proporcoes_Finais):
os pilotos (Jarbas, Henrique, Ulysses) nunca mudam de escala — os .glb já estão em
metros e entram no veículo em escala 1, com a origem na origem do piloto — e cada
veículo recebe uma escala uniforme k tirada da distância do assento (S) ao centro do
volante (W), comparada à do kart de referência (standard_kart com escala 0,06):

    d = |(W.y - S.y, W.z - S.z)|          distância assento → volante do veículo
    k = 0,3702 / d                         escala uniforme do veículo
    W' = k·W, S' = k·S                     volante e assento depois da escala

Se as escalas pelo ΔZ e pelo ΔY diferem mais de 10%, o veículo tem outra ergonomia
(volante mais alto ou mais longe): vale o ΔZ (alcance dos braços), k = 0,314 / ΔZ, e o
resto fica para o IK das mãos (as mãos seguem o volante de verdade).

Em vez de mover o veículo até o assento de referência (o "t" do documento), o veículo
fica com as rodas no chão e o piloto é que entra no ponto certo:
KartData.driver_origin() = S' - assento de referência. A relação entre piloto e kart é
a mesma.

A moto usa a POSE_Moto: o assento de referência é o selim embaixo do quadril e o
"volante" é o meio do guidão, entre as manoplas (medidos nos três pilotos, média).

Este script lê os data/karts/*.tres, calcula k e, se o veículo ainda não estiver na
escala (k diferente de 1), multiplica por k tudo o que é medida no espaço do kart:
modelo, rodas, banco, volante, pegada, cockpit, escapamentos e caixa de batida, e grava
`seat_point` (S'). Rodar de novo não muda nada (k = 1) e serve de conferência: imprime
o k, o erro do volante, o diâmetro da pega, a inclinação do volante e o tamanho final.

Uso: python3 tools/karts/encaixe_karts.py [--gravar]
(sem --gravar só imprime a conferência).

Kart novo: meça S (vinco entre o fundo do banco e o encosto, na linha central) no
espaço do kart (KartVisual: frente = -Z, a mesma escala do .tres) e acrescente em
MEDIDAS; W é o steering_wheel_center do .tres.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
KARTS = os.path.join(PROJ, "data", "karts")

# Kart de referência (espaço do kart do jogo: frente = -Z, Y para cima), em metros.
REF_SEAT = (0.0, 0.111, 0.118)  # S · assento (vinco do banco)
REF_WHEEL = (0.0, 0.307, -0.196)  # W · centro do volante
REF_GRIP_DIAMETER = 0.217  # Ø da linha de pega do aro
REF_TILT = 59.0  # inclinação do plano do volante (graus da horizontal)
# Moto (POSE_Moto, média dos três pilotos): selim embaixo do quadril e meio do guidão.
REF_SADDLE = (0.0, 0.282, 0.030)
REF_BAR = (0.0, 0.502, -0.326)
REF_BAR_SPREAD = 0.161  # meia distância entre as manoplas na pose

# S de cada veículo, no espaço do .tres ANTES do encaixe (medido na linha central com
# mapas de ocupação de 1 cm; padrão = o vinco medido no Blender pelo documento). Depois
# do encaixe o .tres guarda o seat_point e esta tabela não é mais lida.
MEDIDAS = {
    "standard_kart": (0.0, 0.2405, 0.5211),
    "bolido": (0.0, 0.355, 0.155),
    "kart_de_treino": (0.0, 0.37, 0.335),
    "cometa": (0.0, 0.60, 0.38),
    "bugre": (0.0, 0.43, 0.535),
    "motoca": (0.0, 0.88, 0.33),
}

# Padrões de kart_data.gd / kart_exhaust.gd (campos que não aparecem no .tres).
DEFAULTS = {
    "model_scale": 1.0,
    "model_offset": (0.0, 0.0, 0.0),
    "front_wheel_radius": 0.22,
    "rear_wheel_radius": 0.27,
    "seat_position": (0.0, 0.33, 0.3),
    "steering_wheel_center": (0.0, 0.665, -0.16),
    "steering_wheel_axis": (0.0, 0.545, 0.839),
    "steering_wheel_radius": 0.24,
    "hand_angle": 70.0,
    "hand_grip_point": (0.0, 0.0, 0.0),
    "seat_back_point": (0.0, 0.0, 0.0),
    "seat_front_z": 0.0,
    "floor_height": 0.0,
    "foot_limit_z": 0.0,
    "foot_spread": 0.12,
    "hitbox_size": (0.0, 0.0, 0.0),
    "seat_point": (0.0, 0.0, 0.0),
    "turn_lean_degrees": 0.0,
}
SCENE_HITBOX = (1.5439453, 0.5, 2.1572266)  # caixa de res://scenes/kart.tscn
EXHAUST_DEFAULTS = {"radius": 0.05, "length": 0.0}
# Campos multiplicados por k (medidas no espaço do kart).
SCALED = ["model_scale", "model_offset", "front_wheel_radius", "rear_wheel_radius", "seat_position",
          "steering_wheel_center", "steering_wheel_radius", "hand_grip_point", "seat_back_point",
          "seat_front_z", "floor_height", "foot_limit_z", "foot_spread"]


def parse_value(text):
    text = text.strip()
    m = re.match(r"Vector3\(([^)]*)\)", text)
    if m:
        return tuple(float(x) for x in m.group(1).split(","))
    try:
        return float(text)
    except ValueError:
        return text


def fmt(value):
    def num(x):
        if abs(x) < 5e-7:
            return "0"
        s = ("%.6f" % x).rstrip("0").rstrip(".")
        return s if s not in ("-0", "") else "0"
    if isinstance(value, tuple):
        return "Vector3(%s)" % ", ".join(num(x) for x in value)
    return num(value)


class Tres:
    """Edição de um .tres por texto (o ResourceSaver do Godot já apagou listas dos karts)."""

    def __init__(self, path):
        self.path = path
        self.lines = open(path, encoding="utf-8").read().split("\n")

    def _section(self, header_pred):
        start = None
        for i, line in enumerate(self.lines):
            if line.startswith("["):
                if start is not None:
                    return start, i
                if header_pred(line):
                    start = i
        if start is None:
            return None
        return start, len(self.lines)

    def sections(self, prefix):
        out = []
        for i, line in enumerate(self.lines):
            if line.startswith(prefix):
                out.append(line)
        return out

    def get(self, key, section=lambda l: l.startswith("[resource]"), default=None):
        rng = self._section(section)
        for i in range(rng[0] + 1, rng[1]):
            m = re.match(r"^(\w+) = (.*)$", self.lines[i])
            if m and m.group(1) == key:
                return parse_value(m.group(2))
        return default

    def set(self, key, value, section=lambda l: l.startswith("[resource]"), after=None):
        rng = self._section(section)
        for i in range(rng[0] + 1, rng[1]):
            m = re.match(r"^(\w+) = (.*)$", self.lines[i])
            if m and m.group(1) == key:
                self.lines[i] = "%s = %s" % (key, fmt(value))
                return
        # Campo novo: depois de `after` (se existir) ou no fim da seção.
        at = rng[1]
        while at > rng[0] + 1 and self.lines[at - 1].strip() == "":
            at -= 1
        if after:
            for i in range(rng[0] + 1, rng[1]):
                m = re.match(r"^(\w+) = ", self.lines[i])
                if m and m.group(1) == after:
                    at = i + 1
                    break
        self.lines.insert(at, "%s = %s" % (key, fmt(value)))

    def save(self):
        open(self.path, "w", encoding="utf-8").write("\n".join(self.lines))


def value(t, key):
    return t.get(key, default=DEFAULTS[key])


def mul(v, k):
    return tuple(x * k for x in v) if isinstance(v, tuple) else v * k


def fit_scale(S, W, bike):
    """k pela regra do documento: distância S→W ou, com ergonomia diferente, ΔZ."""
    ref_s, ref_w = (REF_SADDLE, REF_BAR) if bike else (REF_SEAT, REF_WHEEL)
    dy, dz = W[1] - S[1], S[2] - W[2]
    rdy, rdz = ref_w[1] - ref_s[1], ref_s[2] - ref_w[2]
    d = math.hypot(dy, dz)
    kd = math.hypot(rdy, rdz) / d
    kh = rdz / dz
    kv = rdy / dy if dy > 0 else kh
    spread = abs(kh - kv) / ((kh + kv) / 2.0)
    k = kh if spread > 0.10 else kd
    return k, {"d": d, "kd": kd, "kh": kh, "kv": kv, "spread": spread, "angle": math.degrees(math.atan2(dy, dz)),
               "rule": "ΔZ" if spread > 0.10 else "S→W"}


def report(name, t, info, k, bike):
    S = value(t, "seat_point")
    W = value(t, "steering_wheel_center")
    ref_s, ref_w = (REF_SADDLE, REF_BAR) if bike else (REF_SEAT, REF_WHEEL)
    # Volante em relação ao assento, comparado com a referência.
    rel = (W[1] - S[1], S[2] - W[2])
    ref_rel = (ref_w[1] - ref_s[1], ref_s[2] - ref_w[2])
    err = math.hypot(rel[0] - ref_rel[0], rel[1] - ref_rel[1])
    print("%-15s k %.4f (%s; S→W %.4f, ΔZ %.4f, ΔY %.4f, %.0f%% de diferença, ângulo %.1f° / ref %.1f°)" % (
        name, k, info["rule"], info["kd"], info["kh"], info["kv"], info["spread"] * 100.0, info["angle"],
        math.degrees(math.atan2(ref_rel[0], ref_rel[1]))))
    print("%15s depois: S %s  W %s  volante %+.1f cm na altura, %+.1f cm na distância (%.1f cm: %s)" % (
        "", fmt(S), fmt(W), (rel[0] - ref_rel[0]) * 100, (rel[1] - ref_rel[1]) * 100, err * 100,
        "ok" if err <= 0.015 else ("atenção" if err <= 0.03 else "corrigir: IK das mãos/pernas")))
    if bike:
        grip = value(t, "hand_grip_point")
        print("%15s manoplas a ±%.3f m do meio (pose: ±%.3f)" % ("", abs(grip[0] - W[0]), REF_BAR_SPREAD))
    else:
        r = value(t, "steering_wheel_radius")
        axis = value(t, "steering_wheel_axis")
        n = math.sqrt(sum(a * a for a in axis))
        tilt = math.degrees(math.acos(axis[1] / n))
        dev = 2 * r / REF_GRIP_DIAMETER - 1
        print("%15s pega Ø %.3f m (ref 0,217: %+.0f%%)  inclinação %.0f° (ref 59°)  mãos a %.0f° do topo" % (
            "", 2 * r, dev * 100, tilt, value(t, "hand_angle")))


def main():
    write = "--gravar" in sys.argv
    for fname in sorted(os.listdir(KARTS)):
        if not fname.endswith(".tres"):
            continue
        name = fname[:-5]
        t = Tres(os.path.join(KARTS, fname))
        bike = value(t, "turn_lean_degrees") > 0.0
        S = value(t, "seat_point")
        if S == (0.0, 0.0, 0.0):
            if name not in MEDIDAS:
                print("%s: sem seat_point e sem medida em MEDIDAS; pulando" % name)
                continue
            S = MEDIDAS[name]
        W = value(t, "steering_wheel_center")
        k, info = fit_scale(S, W, bike)
        if abs(k - 1.0) > 1e-4:
            old = {key: value(t, key) for key in SCALED}
            for key in SCALED:
                t.set(key, mul(old[key], k))
            hit = value(t, "hitbox_size")
            t.set("hitbox_size", mul(hit if hit != (0.0, 0.0, 0.0) else SCENE_HITBOX, k), after="turn_lean_degrees")
            t.set("seat_point", mul(S, k), after="seat_position")
            # Escapamentos (sub_resources KartExhaust).
            for header in t.sections('[sub_resource type="Resource" id="Resource_saida'):
                sec = (lambda h: lambda l: l == h)(header)
                pos = t.get("position", sec, (0.0, 0.0, 0.0))
                radius = t.get("radius", sec, EXHAUST_DEFAULTS["radius"])
                length = t.get("length", sec, EXHAUST_DEFAULTS["length"])
                if length == 0.0:
                    length = 0.3 + radius * 6.0  # o automático de KartExhaust.get_length()
                t.set("position", mul(pos, k), sec)
                t.set("radius", radius * k, sec)
                t.set("length", length * k, sec)
            if write:
                t.save()
                t = Tres(os.path.join(KARTS, fname))
        print()
        report(name, t, info, k, bike)
        if not write and abs(k - 1.0) > 1e-4:
            print("%15s (simulado: rode com --gravar para gravar)" % "")
    if not write:
        print("\nNada gravado (use --gravar).")


if __name__ == "__main__":
    main()
