# Arte do protótipo

As artes principais em `assets/` foram produzidas com a ferramenta integrada de geração de imagens, usando como referência visual a montagem enviada por Leon em `Downloads/Laboratório das Representações_ Protótipo Educacional.png`. A interface, o círculo e os marcadores são nós editáveis do Godot; a montagem original não foi usada como tela pronta.

## Laboratório das rodadas (`assets/laboratorio-rodadas-v2.png`)

Gerado para aparecer somente após **Jogar**, usando as referências de cenários e frascos enviadas por Leon. Prompt: laboratório de alquimia infantil em ilustração 2D 16:9, com lousas de frações sem texto, livros empilhados, frascos coloridos, plantas e luz dourada; detalhes nas bordas e área central tranquila para a interface, piso visível e nenhum personagem ou elemento de UI. O arquivo original gerado foi copiado para `assets/` e o menu conserva seu fundo anterior.

## Frutas das coleções

`assets/fruta-maca-v2.png` e `assets/fruta-banana-v2.png` são ilustrações transparentes geradas para as atividades do 3º ano. A maçã tem volume, casca vermelha, cabo e folha; a banana tem casca amarela e contorno natural. Ambas foram feitas como sprites individuais, sem fundo, letras ou personagens, e são posicionadas pelo nó editável `AppleCollection` no Godot. Os contornos desenhados pelo aluno continuam sendo renderizados pelo jogo.

## Gatinho misturando poções nas atividades

`assets/cat_animation/potion_mix/atlas-original.png` é a imagem de 18 quadros fornecida por Leon em `Gato cientista mistura poção mágica.png`. `tools/extract_potion_atlas.py` recorta os quadros, remove molduras, números, fundo escuro e faixa da mesa, preservando o gato e os recipientes em arquivos transparentes `frame_01.png` a `frame_18.png`. Todos usam a mesma tela de 272 × 273 pixels e alinham a base do recipiente. Na cena de exercício, `scripts/game_cat_idle.gd` usa os quadros 1 a 6 para preparar e derramar as poções uma vez; os quadros 7 a 14 formam o ciclo contínuo de mistura, mantendo a patinha sobre o frasco. Os quadros 17 e 18 mostram a comemoração após o acerto. `scripts/success_burst.gd` desenha a explosão colorida; `tools/extract_success_cloud.py` recorta a nuvem com “Parabéns!” da folha enviada por Leon. A nuvem cresce e sobe do frasco, com brilho e estrelas, dentro da cena de exercícios. O jogo renderiza as transições a 60 FPS.

O próprio `tools/extract_potion_atlas.py` recompõe o corpo escuro sob as lapelas e liga os pequenos vãos entre mangas e abas inferiores em cada quadro transparente. As duas abas do tecido são unidas dentro da silhueta original. A cena não usa uma segunda camada de jaleco. A parte frontal do recipiente é extraída em `beaker_01.png` a `beaker_18.png`: o corpo fica atrás da mesa e o vidro à frente, sem a borda do tampo atravessar o frasco. `PotionTable` coloca a mesa marrom sob os recipientes, com pernas curtas nos layouts estreitos; o tempo da mistura permanece igual.

`assets/cat_animation/potion_mix/atlas-standing-reference.png` é uma cópia da referência mais recente enviada por Leon, `Gatinha Alquimista Mistura Poção Roxa.png`. `tools/extract_standing_legs.py` separa as duas patas originais em `standing_legs.png`, preservando seus dedos e formato. O recorte recebeu apenas ajuste sutil de cor para combinar com o pelo do corpo. O nó `StandingLegs` fica atrás de `PotionTable` e acompanha discretamente a respiração sem alterar a forma das patas.

O tampo usa um trapézio com superfície ampla e borda frontal arredondada; os frascos laterais ficam menores e recuados sobre ele. A mesa não tem barra inferior. A extração das patas suaviza o contorno, harmoniza o roxo do pelo e prolonga apenas a parte das pernas escondida pela borda, preservando o desenho dos dedos. A extensão das canelas é de 5 pixels, com largura de 100 pixels no nó da cena, para evitar pernas excessivamente compridas e estreitas.

A caminhada usa passos de 8 pixels após a passagem gradual da pose de repouso, a 32 pixels por segundo. A passada mais curta evita que as patas se afastem demais; a inclinação e o deslocamento vertical do tronco são derivados diretamente da elevação de cada pata, e a pata apoiada permanece fixa no chão. As verificações `verify_cat_motion.gd`, `verify_cat_connections.gd` e `verify_cat_paw_shape.gd` cobrem apoio, continuidade e preservação da arte.

## Atlas de animação do gatinho

A animação atual usa as artes de `assets/cat_animation/v8/`: oito poses de virada interpoladas em 60 quadros e pernas independentes para alternar o apoio no chão. As artes foram criadas com a ferramenta integrada imagegen a partir dos recortes do atlas original. Os prompts completos, arquivos e procedimento estão em [CAT_ANIMATION_V8.md](CAT_ANIMATION_V8.md). Os arquivos descritos abaixo registram as versões anteriores.

`assets/cat_animation/atlas-original.png` é uma cópia do atlas fornecido por Leon. `tools/extract_cat_atlas.py` separa seus quatro quadros de repouso e cinco de caminhada, retirando o fundo quadriculado sem redesenhar o personagem. A máscara mantém os pixels do contorno e as áreas claras fechadas dentro dele, como o jaleco, sem expandir o recorte sobre o fundo branco. Os limites dos quadros preservam a cauda inteira em cada pose. `idle_0.png` e `walk_0.png` serviram de referência para a arte atual.

`assets/cat_animation/turn_three_quarter.png` é uma pose intermediária com fundo transparente, produzida pela ferramenta integrada de geração de imagens a partir de `idle_0.png` e `walk_0.png`. Prompt usado:

> Use case: illustration-story. Asset type: one transparent 2D game animation sprite, an in-between turning pose. Input image 1 is the exact front-facing seated black scientist cat; input image 2 is the exact right-facing walking black scientist cat. Draw the SAME cat at a three-quarter view turning toward screen right, halfway between sitting and taking the first step: body just rising, both eyes fully open and visible, head and nose pointing diagonally right, one front paw beginning to lift, feet close to ground. Match the two reference sprites as closely as possible: dark indigo-black fur, pink inner ears, large round glasses with gold and cyan rims, white laboratory coat, purple collar jewel, thick dark ink outlines, charming polished 2D cartoon game sprite. Single complete character centered in a vertical sprite canvas with similar proportions and visible full body and tail. Genuine transparent background, no checkerboard, no floor or shadow, no text, no border, no additional characters, no repeated pose, no white holes or missing body parts. Preserve the recognizable character and the white coat.

## Gatinho (`assets/gato-cientista.png`)

Prompt usado na ferramenta integrada:

> Use case: background-extraction. Asset type: transparent 2D game character sprite for Godot. Input image: the attached educational game mockup is the exact visual reference for the purple-black cat scientist in the laboratory panels. Create one clean full-body cutout of the same cute dark purple cat with bright lime-green eyes, small pointed ears, rounded paws, a pale lab coat, and a friendly confident expression, facing slightly toward the viewer, standing upright. Match the illustrated children's game style, crisp dark outlines, rich purple shading. Entire character visible with generous padding. No laboratory, no props, no text, no speech bubble, no shadow outside silhouette. Genuine transparent background with clean alpha edges.

## Laboratório (`assets/laboratorio-fundo.png`)

Prompt usado na ferramenta integrada:

> Use case: illustration-story. Asset type: 16:9 background painting for a 2D educational Godot game, behind editable UI. Input image: the attached mockup is a style and environment reference only. Create an original cozy magical math laboratory interior: violet wooden walls, bookshelves, geometric glass flasks with gentle lime-green glow, chalkboard with simple geometric marks, a few plants, warm evening light, richly illustrated children's adventure game style with clean dark outlines and painterly shading. Composition: wide room, keep the central 65% relatively quiet and low contrast so a cream-colored editable question panel can sit there; stronger detail toward left and right edges. No characters, no cat, no interface, no writing, no numbers, no buttons, no watermark.

## Decorações da interface

`assets/ui_decor/menu-display.png`, `lab-shelf.png`, as mini-poções e os livros foram gerados com o fundo do laboratório como referência de estilo. São recortes com transparência usados por `scripts/lab_decor.gd` nos nós da cena 2D. A lousa e a prateleira usam a mesma madeira dourada, sombras roxas e vidro brilhante do cenário.
