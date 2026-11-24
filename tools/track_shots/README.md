# Imagens da tela de pistas

A tela de seleção de pistas não gera nenhuma pista em 3D: o fundo é uma foto aérea pronta
de cada pista e os cartões usam uma foto da largada. As imagens ficam em `assets/pistas/`
e cada `data/pistas/*.tres` aponta para as suas (`background` e `thumbnail`).

| Arquivo | Para que serve |
| --- | --- |
| `gerar.sh` | Faz tudo: build de teste, prints no Chrome headless, conversão e import |
| `zz_track_shots.gd` | Probe: monta cada pista, enquadra a vista aérea e a largada e pede os prints (`?s=shots`); `?s=explore` fotografa a vista aérea dos 4 lados; `?s=select` mede a tela de pistas |
| `make_images.py` | Converte os prints: fundo 1920×1080 e cartão 448×300 (JPEG) |

Usa o kit de `tools/perf/` (export com o probe, servidor COOP/COEP e o `run_chrome.mjs`).

## Uso

```sh
tools/track_shots/gerar.sh /tmp/ak_fotos   # pasta temporária fora do projeto
IDS=baia_ativos tools/track_shots/gerar.sh /tmp/ak_fotos   # só essas pistas (?ids=)
```

Rode de novo depois de mudar o traçado, o cenário ou as decorações de uma pista. Com `IDS`
as imagens das outras pistas ficam como estão (não aparecem como mudadas no git).

## Pista nova

1. Acrescente o id em `VIEWS` no `zz_track_shots.gd` (lado de onde a câmera olha e a
   inclinação). Para escolher o lado, rode o probe com `?s=explore` (veja o
   `gerar.sh`: troque `s=shots` por `s=explore`) e compare os 4 prints.
2. Rode `gerar.sh`.
3. No `.tres` da pista, aponte `background` para `res://assets/pistas/<id>_fundo.jpg` e
   `thumbnail` para `res://assets/pistas/<id>_cartao.jpg`.

## Cuidados

- Os prints saem do renderizador da web (Compatibility). De longe a neblina da corrida
  deixaria tudo branco, então o probe usa 12% dela; também tira os cortes por distância,
  estica a sombra e esconde a neve.
- O `shaders/water.gdshader` converte a profundidade do Compatibility (`* 2 - 1`); sem
  isso a água inteira virava espuma branca na web (e nas fotos).
- A vista aérea usa `near = 40 m`: com o near padrão o buffer de profundidade perde a
  precisão a 400 m e a espuma da água cobre tudo.
- O probe espera cada print ficar pronto (`window.__shot_saved`) antes de mexer na
  câmera: com shader compilando o Chrome pode levar segundos para entregar o quadro.
