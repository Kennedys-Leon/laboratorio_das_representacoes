# Perfil de acessibilidade e evidências

Implementação de 04/11/2026. Referências lidas: contrato e serviço `project-gauss-api/src/accessibility`, visão do projeto, contrato de jogos v1, regras editoriais e de currículo; documentos `ACESSIBILIDADE_E_PREFERENCIAS.md`, `CONTRATO_ACESSIBILIDADE_MINIGAMES.md` e `PADRAO_ACESSIBILIDADE_MINIGAMES.md` de project-gauss-apps. O jogo recebe preferências, nunca diagnósticos. Não modifica o ano, IDs, respostas corretas ou registros oficiais.

## Recebimento

- Nativo/autenticado: GET `/accessibility/effective` com a sessão existente. O botão Jogar aguarda a leitura inicial; a introdução fica sem movimento enquanto carrega.
- Web: listener instalado antes do aviso `gauss-accessibility-ready`; aceita `gauss-accessibility-profile` v1 somente da janela pai e da mesma origem. Valida os tipos, valores e todos os campos antes de aplicar. Campos desconhecidos não entram no estado do jogo.
- Atualização preserva questão e resposta. Repetir o mesmo perfil não amplia novamente a fonte nem reinicia a espera do resultado.
- Erro de rede: aviso, apresentação com menos movimento e foco, sem gravar defaults na API. Não há cache anônimo. A troca do token na Web limpa resposta/perfil e ignora respostas pendentes da conta anterior.
- O gestor e o aluno editam as preferências globais no site/app. O jogo aplica automaticamente o perfil efetivo recebido, sem oferecer um seletor de acessibilidade na atividade. Não escreve padrões do gestor nem recalcula precedência.

## Aplicação

| Campo | Comportamento |
| --- | --- |
| textScale | 100/125/150/200%, a partir do tamanho original; menus, instruções, respostas, controles e números dos desenhos. Painéis se reorganizam e permitem rolagem. |
| contrast | Tema escuro com texto branco e foco destacado, além de marcador textual de resposta selecionada. |
| reducedMotion | Interrompe caminhada, respiração, transições de balões e decoração animada; apresenta resultados estáticos e mantém o texto. |
| focusMode | Oculta cenário e enfeites; transfere a instrução do balão para a atividade. |
| pace | Questões sempre sem prazo. Feedback normal aguarda 3 s; extended, 6 s; untimed aguarda Próxima questão/Tentar novamente. A interface HTML equivalente pode pausar sem apagar a resposta. |
| preferredInput | Teclado/toque abrem controles alternativos. Cada parte/fruta pode ser escolhida por botão; Formar grupo valida a quantidade, sem escolher as frutas pelo aluno. Mouse continua disponível. |
| accessibleActivity | O host oficial já direciona `react` para sua prática equivalente. Dentro desta exportação, também abre a interface HTML textual equivalente da mesma questão; não depende da semântica do canvas. |
| captions | Pergunta, instruções, feedback e estado permanecem em texto, inclusive quando false, pois são essenciais. Não há áudio informativo separado. |
| soundEffects | Este projeto ainda não possui players de som; on/off são recebidos sem produzir áudio. Uma futura trilha deverá respeitar o campo. |
| audioAssistance | Recebido e validado; voz não implementada por decisão de Leon. Nenhuma fala automática. |

A interface HTML é uma alternativa local sincronizada com o estado Godot, não uma nova rota React nem um novo banco de questões. Os botões chamam os mesmos métodos de seleção, montagem e envio. A sessão permanece separada da mensagem de preferências. O texto do DOM é inserido com textContent; a página não interpreta HTML vindo da API. O script é empacotado em `accessibility_web_source.gd` para não depender de filtros de exportação de arquivos JavaScript. Ao editar `accessibility_web.js`, regenerar a constante SOURCE.

## Verificação

- `verify_accessibility.gd`: tipos inválidos, perfil após JSON, aplicação idempotente, preservação de resposta, quatro questões por controles alternativos, pausa, movimento reduzido e avanço/repetição sem prazo.
- `profile_fixture.py` + `verify_accessibility_api.gd`: HTTP autenticado local com o formato real de `/accessibility/effective`, aplicado antes de Jogar. Não usa contas reais nem altera a API.
- `verify_accessibility_web.cjs`: Chromium, origem e janela pai, rejeição de origem externa, botões HTML por Enter, aria-pressed, foco preservado e controle desabilitado.
- `preview_accessibility.gd`: capturas a 200% com contraste/foco em 1100 e 390 pixels.
- Testes existentes de rodadas e da reação de erro continuam cobrindo o fluxo padrão.

Não foi validada uma conta de produção nesta sessão. Os testes de navegador verificam o receptor e a interface HTML isolados; a exportação completa dentro do site/app precisa de teste de integração no ambiente de entrega. Ainda são necessários testes com NVDA, VoiceOver, TalkBack e alunos nos dispositivos alvo. Estas evidências não equivalem a certificação WCAG nem a suporte comprovado de leitores de tela em todas as plataformas.
