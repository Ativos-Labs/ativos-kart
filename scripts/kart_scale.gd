@tool
class_name KartScale
extends Object
## Proporções do mundo depois do encaixe piloto × kart (veja KartData e
## tools/karts/encaixe_karts.py): os pilotos entraram em escala 1 (Jarbas, Henrique e
## Ulysses com 1,03 a 1,06 m) e cada kart foi escalado para eles. O Kart Padrão foi de
## 2,44 m para 1,13 m de comprimento, os outros veículos ficaram com 46% a 77% do tamanho
## e os pilotos com ~79% da altura de antes. As pistas e a física não mudaram.
##
## Itens, efeitos e alcances feitos para os karts antigos multiplicam as medidas por
## ITEMS (≈ quanto um kart encolheu em média); a câmera da corrida, por CAMERA (a cabeça
## do piloto, que ela precisa ver por cima, encolheu menos que o kart).

const ITEMS := 0.55
const CAMERA := 0.75
## Kart com o piloto nas telas de seleção de kart e de asa (palco montado para os karts de
## antes): o conjunto inteiro cresce junto, sem mudar a proporção entre piloto e kart. Os
## veículos altos (piloto sentado no alto, como no Cometa e na Motoca) crescem menos, até o
## topo do conjunto ficar em SHOWCASE_HEIGHT (m) no palco (KartVisual.showcase_scale).
const SHOWCASE := 1.6
const SHOWCASE_HEIGHT := 1.45

