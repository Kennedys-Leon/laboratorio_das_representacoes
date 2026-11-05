# Rodadas do 3º ano no Laboratório das Representações

Escopo desta revisão: somente a habilidade **EF03MA09** autorizada para `laboratorio-das-representacoes` na lição `gauss-ef03ma09-partes-iguais.v1.json` de `project-gauss-api`. Os outros conteúdos do 3º ano pertencem a aulas, à prática React ou a jogos com contratos diferentes.

| Exercício da API | Tipo | Representação | Resposta enviada |
| --- | --- | --- | --- |
| `uma-de-duas` | `fraction_parts` | Pintar 1 de 2 partes do círculo | `"1/2"` |
| `uma-de-quatro` | `fraction_parts` | Pintar 3 de 4 partes do quadrado | `"3/4"` |
| `metade-de-oito` | `fraction_collection` | Cercar 8 maçãs em 2 grupos de 4 | `"1/2"` |
| `quarta-parte-de-doze` | `fraction_collection` | Cercar 12 bananas em 4 grupos de 3 | `"1/4"` |

O círculo e o quadrado começam vazios; a criança clica nas partes para pintá-las. Nas coleções, desenha contornos ao redor de grupos iguais. O balão do gato primeiro explica apenas o desenho. Ao completar essa etapa, o balão se fecha, estoura em estrelinhas e volta com a pergunta da fração (`answerPrompt`). O jogo então libera as quatro alternativas. **Desfazer** retira a última pintura ou grupo e restaura a instrução inicial quando necessário; **Recomeçar** reinicia a rodada. A descrição textual da API continua no contrato, mas o enunciado visível fica no balão do gato. O servidor precisa publicar o conteúdo revisado para usá-lo com alunos autenticados; um catálogo antigo aciona a demonstração local identificada.

`GET /learning/lessons?gameId=...` devolve apenas lições publicadas elegíveis à série da matrícula. O jogo filtra `schoolYear == 3`, `skillId == EF03MA09` e os dois tipos de fração. A lista pública não contém gabarito. A correção oficial usa `POST /learning/attempts` com os IDs da lição, um `eventId` por tentativa e o valor de `choice` correspondente ao tipo. Um envio sem resposta pode ser repetido com o mesmo `eventId` e horário. O retorno da API determina o acerto e o feedback; nenhuma tentativa autenticada é corrigida localmente.

O arquivo `content/grade3_fractions_preview.json` serve apenas para a demonstração sem sessão, com uma etiqueta visível de que não há registro oficial. É gerado por `tools/sync_grade3_rounds.py` a partir do conteúdo da API e não inclui gabarito explícito. `uma-de-duas` é uma checagem de etapa: aparece em `GET /learning/lessons`, e a API aceita sua tentativa, embora não seja candidata de `GET /learning/games/next-round`.

## Verificação

- `godot --headless --path . --script tools/verify_grade3_rounds.gd`: quatro rodadas locais, figuras, alternativas, erro, nova tentativa e conclusão.
- `godot --headless --path . --script tools/verify_potion_animation.gd`: 18 quadros transparentes alinhados, despejo uma vez, mistura em ciclo e transições em uma simulação de dez segundos a 60 FPS.
- `python tools/mock_grade3_api.py` e, em outro terminal, `GAUSS_API_URL=http://127.0.0.1:38961 GAUSS_STUDENT_TOKEN=grade3-test godot --headless --path . --script tools/verify_grade3_online.gd`: quatro exercícios públicos sem gabarito no cliente, cinco tentativas autenticadas e feedback retornado.
- `godot --path . --script tools/preview_grade3_rounds.gd`: capturas reais das quatro telas para revisão visual.
- `godot --path . --script tools/preview_grade3_interactions.gd`: capturas com partes pintadas e grupos desenhados.

O teste HTTP usa um servidor local que reproduz o contrato da API. A publicação da lição e uma sessão real do aluno ainda dependem do ambiente integrado de GH/Gouvea.
