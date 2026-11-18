# Asas-deltas

## build_asas.py

```bash
python3 tools/asas/build_asas.py            # todas
python3 tools/asas/build_asas.py asa_ativos # só uma
```

Lê o modelo original (`originais/paraglider.glb`, com a textura em
`originais/paraglider_textura.png`) e grava em `assets/models/asas/`:

- `asa_delta.glb`: a malha sem esqueleto, na escala do jogo (3 m de envergadura,
  1,86 m de altura), com a frente para -Z. A vela com a moldura é o nó "Asa" e cada
  corda é um nó próprio ("Corda0".."Corda3") com a origem na ponta de cima: o jogo
  centraliza a vela em cima do kart e estica cada corda até a carroceria (duas na frente
  e duas atrás, uma de cada lado; `GliderVisual.fit_to`). Sem textura: o jogo põe a de
  cada asa (`GliderData.texture`).
- `asa_rubra.png` (a original), `asa_ativos.png`, `bandeirada.png`, `por_do_sol.png`.

A vela do original tem duas camadas (a de cima virada para cima, a de baixo para baixo)
que liam o mesmo pedaço da textura. Cada textura do jogo é um atlas 1024×512 com duas
metades iguais: a camada de cima lê a metade esquerda e a de baixo, a direita. Assim cada
lado tem a sua pintura e o desenho nunca aparece espelhado:

- de cima (tela de seleção, câmera alta), o "para cima" do desenho aponta para a frente;
- de baixo (a câmera da corrida, atrás e abaixo da vela), aponta para trás.

Cada variação recolore as faixas da borda da vela (verde e dourada no original) e o
contorno, troca o emblema do meio pelo desenho dela e recolore a madeira da moldura, as
amarrações e cordas (azuis) e as tiras (bege). O desenho é pintado pela posição 3D de cada
pixel da vela (baricêntricas dos triângulos no espaço UV), então não deforma com o
mapeamento. As cores da vela original são separadas por uma paleta achada por k-means
(`PAL_*` no script).

## sonda_voos.gd

Mede os voos sem abrir janela. Copie para `_probe/` (o Godot ignora `tools/`) e rode:

```bash
cp tools/asas/sonda_voos.gd _probe/
Godot --headless --audio-driver Dummy --path . -s res://_probe/sonda_voos.gd -- track=2 cls=1
```

Imprime cada voo e uma linha `RESUMO` por pista/classe. Em 2026-11-17 (8 karts, ~100 s):

| Pista    | Ar (100cc) | Distância 50 / 100 / 150cc | Paredes | Quedas |
|----------|-----------|----------------------------|---------|--------|
| Circuito | ~3,45 s   | 66–86 / 69–93 / 107–142 m  | 0       | 0      |
| Ilha     | ~3,4 s    | 63–80 / 78–102 / 91–202 m  | 0       | 0      |
| Cânion   | ~6,6 s    | 128–152 / 161–190 / 189–220 m | 0    | 0      |
| Pico     | ~6,1 s    | 117–144 / 155–181 / 167–208 m | 0    | 0      |

Segurando o freio o voo inteiro (`pull=1`, Cânion 150cc): 8,1 s e 216 m — as paredes do
voo vão até 280 m. Virando tudo para um lado (`pull=2`/`3`) o kart bate na parede
invisível, desliza nela e aterrissa dentro da pista.
