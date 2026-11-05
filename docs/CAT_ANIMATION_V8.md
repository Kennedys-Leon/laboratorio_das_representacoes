# Animação do gatinho — versão 8

A arte usa a ferramenta integrada **imagegen**, com fundo transparente, tomando os recortes originais do atlas de Leon como referência. Os arquivos de trabalho e as artes usadas pelo jogo ficam em `assets/cat_animation/v8/`.

## Estado atual — revisão v13

A levantada usa os 60 quadros completos de `turn-60.png`, sem desenhar outra pata por cima. O último quadro e o primeiro quadro da caminhada mostram a mesma pose `standing.png`, o que evita um salto na troca. O rig só aparece quando a caminhada começa. Durante os passos, as duas patas preservam os pixels originais, mas os recortes móveis começam abaixo da barra do jaleco; assim, nenhuma parte branca do casaco acompanha uma pata. As ligações superiores são arredondadas e ficam atrás do corpo. `CatPawOverlay` e a máscara antiga da levantada permanecem no projeto como histórico, mas não são mostrados nessa animação.

## Virada

- `keyposes.png`: folha original gerada, com oito poses de virada nas duas primeiras linhas. As duas linhas inferiores são estudos de caminhada; o jogo usa pernas independentes para controlar o contato com o piso.
- `turn-60.png`: atlas de 10 × 6 células, cada uma com 128 × 152 pixels. São **60 quadros diferentes**, reproduzidos a 60 FPS durante um segundo.
- `tools/build_cat_animation.py` alinha oito poses na mesma altura e gera os intervalos com fluxo óptico bidirecional e alfa pré-multiplicado. Não são 60 ilustrações desenhadas individualmente.
- A escala do nó permanece em (1, 1). A silhueta mede de 132 a 134 pixels ao longo dos intervalos, sem o antigo aumento de 15%.
- O primeiro quadro corresponde a `idle.png`; o último usa a própria pose `standing.png`. A caminhada também usa essa imagem, incluindo as patas originais. `walk-rest.png` é apenas uma captura de conferência e não substitui mais o desenho final da virada.

## Patas na levantada — revisão v11 (histórico)

As patas traseiras são peças rígidas de `standing.png` desde o repouso. Ficam atrás do sprite e são reveladas quando o jaleco e as patas dianteiras se levantam. `CatAnimator` coordena a posição das peças e a máscara do shader `cat_breath.gdshader`; a máscara remove as patas traseiras interpoladas do atlas. Assim, os pés que aparecem na levantada são os mesmos que iniciam a caminhada, sem troca de escala ou deformação da malha. As patas dianteiras continuam acompanhando os braços da animação original.


### Ajuste da levantada — v12 (histórico)

Na virada, o atlas antigo ainda sobrepunha o desenho das patas sentadas aos pés traseiros por alguns quadros. O shader agora desfaz essa sobreposição em uma faixa curta e com borda suave. `CatPawOverlay` desenha somente os dedos originais de `standing.png` na frente do sprite durante a troca; o restante da perna permanece atrás do jaleco. A opacidade é sincronizada com a virada e a camada desaparece antes da caminhada. A posição e o tamanho dos pés rígidos continuam constantes até o primeiro passo.

O teste `tools/verify_cat_motion.gd` também confere que a camada fica visível apenas durante a levantada e que nenhuma pata pula ou perde contato com o piso. A prancha atual é `docs/preview-cat-paws-v12.png`.

## Caminhada

Revisão v11: removida a deformação da faixa superior de 2–7 pixels que dobrava o desenho das patas durante o passo. Agora **todo o polígono de cada pata** usa uma transformação de translação, inclusive seu contorno superior. A ligação ao corpo é desenhada por trás, com duas articulações arredondadas nas cores do pelo. Ela pode se mover sem esticar a textura dos pés. O rig usa `Node2D`, evitando o arredondamento de posição dos nós de interface; um fragmento da borda do jaleco também foi retirado do polígono da perna distante.

Na v13, os recortes móveis foram limitados aos pés abaixo da barra do jaleco e as ligações arredondadas ficaram mais largas. Isso elimina a faixa branca que deslizava junto com a segunda pata, preservando a forma original dos dois pés.

`scripts/cat_walk_rig.gd` divide a própria textura `standing.png` em três polígonos: corpo, perna distante e perna próxima. Não há escalonamento das patas. Os arquivos `legs-source.png`, `leg-near.png` e `leg-far.png` são estudos anteriores e não são usados pelo jogo nem pelo gerador.

Cada passo começa com 18% de apoio duplo. Depois uma pata permanece fixa no chão enquanto a outra se eleva até 6 pixels e avança. O passo seguinte troca as patas. A fase depende da distância percorrida, o que mantém a pata apoiada no mesmo ponto do cenário. O corpo sobe cerca de 1 pixel ao passar sobre o apoio, com escala fixa. A saída usa aceleração suave e velocidade de 78 pixels por segundo.

No editor 2D, o nó `MenuLayer/MenuCat/CatWalkRig` permite visualizar a caminhada: oculte `CatSprite`, mostre `CatWalkRig` e ajuste **Distance** no Inspetor. Volte a deixar apenas `CatSprite` visível para salvar o menu em repouso. Mova `MenuCat` para reposicionar o conjunto.

## Reprodução e verificação

O jogo só precisa dos PNGs já preparados e do Godot. Para regenerar os intervalos, use um ambiente Python com Pillow, numpy e opencv-python-headless:

1. Execute `python tools/build_cat_animation.py`.
2. Importe o projeto com `godot --headless --editor --quit --path .`.
3. Confira a preservação das patas com `godot --path . --script res://tools/capture_cat_rig.gd` (precisa de uma sessão gráfica). O teste compara os pixels da região das patas renderizada com a arte original; a captura é apenas um registro visual.

`godot --headless --path . --script res://tools/verify_cat_motion.gd` verifica os 60 quadros da virada, escala fixa, contato com o chão, ausência de deslizamento da pata apoiada, alternância das pernas, apoio duplo e abertura da rodada.

`tools/verify_cat_connections.gd` verifica a continuidade entre patas e corpo em 120 posições renderizadas. `tools/verify_cat_paw_shape.gd` renderiza as duas patas isoladas em 60 posições da virada e 120 posições da caminhada, compensando o deslocamento da câmera para comparar a forma completa com a referência. Ambos precisam de uma sessão gráfica. Na revisão v11: 0/120 posições com patas desconectadas; 360 comparações das patas sem diferença de pixels após compensar o deslocamento. O teste de movimento também passou, com 60 quadros de virada e 55 amostras de apoio duplo. A prancha `docs/preview-cat-paws-v11.png` mostra a levantada e os passos ampliados.

A prévia atual `docs/preview-cat-motion-v13.mp4` tem 60 FPS, começa com três segundos de respiração e é reproduzida um pouco mais devagar para facilitar a revisão. Ela foi capturada na própria Godot por `tools/preview_cat_motion.gd` com avanço de 1/60 s por quadro.

A respiração usa `shaders/cat_breath.gdshader`: um ciclo contínuo de 2,7 s expande discretamente a parte superior (cerca de 1,6 pixel nas orelhas), com os pés ancorados no piso. O efeito retorna suavemente a zero no início da virada.

## Prompts completos

### Folha de poses

```text
Use case: illustration-story.
Asset type: production 2D game sprite animation sheet, exact 4 columns by 4 rows, sixteen full-body poses of ONE same cat character, transparent background.
Input image 1 is the exact character identity and front seated start pose. Input image 2 is the side-facing character identity and artistic style ONLY; do NOT repeat its suspended run pose.
Create sixteen clean animation key poses, reading left-to-right top-to-bottom. Preserve the small black/dark indigo scientist cat, pink ears, open round eyes, round glasses, white lab coat, purple collar gem, short legs, curled tail, thick dark outline, charming cartoon rendering.
All sixteen cells must have the SAME camera, identical character scale, head diameter, body proportions and identical ground baseline within each cell. Every full silhouette including tail and paws fits its cell with generous transparent margin. No titles, numbers, labels, frames, grid lines, checkerboard, floor, shadows, props or text. Genuine transparent alpha outside each cat.

First 8 cells (rows 1 and 2): a smooth turn and rise from seated front-facing slightly toward screen-left to standing facing screen-right. Cell1 seated front both paws flat, both eyes fully open. Cell2 slight anticipation lean with head beginning right. Cell3 head turned 15 degrees right, body still seated. Cell4 head 30 degrees right, body beginning to rise. Cell5 body halfway rising, head45 degrees. Cell6 almost standing, head60 degrees, both hind feet touch the same ground. Cell7 standing turned75 degrees. Cell8 standing right-facing 3/4 side view, BOTH hind feet flat on the ground, arms relaxed. Do not enlarge the head or body as it turns; identical scale in all cells, rise only a very small amount.

Last 8 cells (rows 3 and 4): coherent realistic biped WALK in place facing screen-right, complete alternating two-legged walking gait, same standing character as cell8. Only TWO hind feet and two arms. Modest natural step, no running, no jumping.
Cell9 double-support CONTACT A: near foot forward flat contacting ground, far foot behind toes touching ground; BOTH feet touch.
Cell10 DOWN A: near front foot accepts weight flat on ground, far foot lifts behind.
Cell11 PASS A: near supporting foot directly beneath hip flat on ground, far foot swings past low above floor.
Cell12 UP A: near supporting foot rolls to toes on ground, far foot reaches forward about to contact.
Cell13 double-support CONTACT B: far foot forward flat on ground, near foot behind toes touching ground; BOTH feet touch, opposite feet from cell9.
Cell14 DOWN B: far front foot accepts weight flat on ground, near foot lifts behind.
Cell15 PASS B: far supporting foot directly beneath hip flat on ground, near foot swings past low above floor.
Cell16 UP B: far supporting foot rolls to toes, near foot reaches forward about to contact leading seamlessly back to cell9.
In every walking frame at least one paw MUST be flat on or have toes on the exact same baseline; contact frames9 and13 have BOTH paws on baseline. The supporting leg extends from hip to floor; lifted paw clearance only small. Visible distinct alternating leg poses, arms counter-swing gently. Keep head absolutely consistent in size and facial features across all sixteen sprites.
```

### Pernas independentes — estudo anterior, fora do jogo atual

```text
Use case: precise-object-edit.
Asset type: transparent 2D cutout animation rig parts, two isolated cat hind legs.
Reference image shows the exact standing black-purple scientist cat. Create ONLY its two hind legs as separate complete independent cutout parts, one near leg on the left and one far leg on the right. No head, torso, coat, tail, hands, floor, shadows, text or checkerboard.
Each leg: short plump dark indigo-purple furry thigh descending almost vertically, slight natural knee bend, rounded ankle and an entire wide rounded flat paw at the bottom pointing toward screen RIGHT, visible two subtle toe marks. Thick smooth very dark ink contour and modest purple shading matching the reference. The limb top is a rounded cap which will be hidden behind the coat, not a hard rectangle. Both legs have the SAME scale and same total length; far leg slightly darker. Feet perfectly flat along the SAME horizontal baseline. Silhouettes separate with lots of transparent space, all toes and full contours visible. Solid connected organic leg with no gaps. Side view three-quarter angle consistent with the reference. Short cat leg proportions: total height about twice paw width. Genuine transparent background. This is a sprite rig asset, no scene.
```
