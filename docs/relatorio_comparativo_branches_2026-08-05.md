# Relatorio comparativo das branches VettiFlow - 05/08/2026

Branches comparadas:

- Base atual de Leonardo: `postgres-windows`, com as alteracoes locais mais recentes.
- Branch do colega: `origin/integracao-protheus-mac`, commit `7ec3f81` apos fetch de 05/08/2026.

## Revisao apos novo fetch da branch do Vitor

Em 05/08/2026 foi feito novo `git fetch --all --prune`. A branch
`origin/integracao-protheus-mac` saiu de `43db26b` para `7ec3f81`, adicionando
a pasta `api/` a partir do commit `b0906bd`.

Isso muda bastante a avaliacao. Antes, a branch do Vitor tinha principalmente
o cliente Dart que chamaria uma API externa. Agora ela tem a propria API
FastAPI dentro do projeto:

- `api/app/main.py`
- `api/app/protheus.py`
- `api/app/db.py`
- `api/app/schemas.py`
- `api/tests/test_mutations.py`
- `api/README.md`

### Nova opiniao resumida

Minha recomendacao atualizada e:

- Usar o Flutter atual da branch `postgres-windows` como base operacional.
- Trazer a pasta `api/` do Vitor como base do gateway Protheus.
- Nao substituir a sua regra de negocio pela regra inteira da branch dele.
- Adaptar a API para obedecer exatamente as respostas recentes do gestor.

Em outras palavras: eu nao escolheria "sua branch contra a dele". Eu escolheria
"sua interface/fluxo atual + API do Vitor como servico oficial de escrita no
Protheus".

### Por que a API do Vitor ficou importante

A API e bem mais madura do que parecia antes do fetch:

- Tem FastAPI e contrato HTTP.
- Tem `vf_mutations` para auditoria/idempotencia.
- Tem `VF_APPLY=0` para validar sem gravar em `SC2`/`SD4`/`SB2`.
- Monta `INSERT` dinamico usando `information_schema`, o que resolve o grande
  problema da `SC2` ter muitas colunas `NOT NULL` sem default.
- Calcula `R_E_C_N_O_`.
- Tem endpoints de leitura:
  - OPs abertas da `SC2`;
  - empenhos da `SD4`;
  - saldos da `SB2`.
- Tem escrita separada por tipos:
  - `aberturaOp`;
  - `empenho`;
  - `transferencia`;
  - `baixaProducao`.
- A baixa de producao ja usa a ideia correta confirmada com o gestor:
  - `PR0` para entrada do produto acabado;
  - `RE1` para consumo de materia-prima;
  - atualiza `C2_QUJE`;
  - fecha `C2_DATRF` quando completa;
  - baixa `D4_QUANT`;
  - mexe em `SB2`.

Essa parte e valiosa e eu priorizaria trazer.

### Onde a API ainda conflita com o que foi combinado

Apesar de boa, ela ainda precisa de ajustes antes de virar a fonte final.

1. Criacao da OP esta em duas fases

Na API, `POST /api/v1/mutations` so armazena. A escrita real em `SC2`/`SD4`/
`SB2` acontece depois em `POST /api/v1/finalizar`.

Pela resposta mais recente do gestor, na criacao da OP ja deve gravar:

- `SC2`;
- `SD4`;
- `SB2.B2_QEMP`.

Entao a API pode continuar com fila/idempotencia, mas para `aberturaOp` eu
recomendo aplicar imediatamente, ou entao o Flutter chamar `/mutations` e
`/finalizar` na mesma acao de criacao. Do jeito atual, se a OP ficar apenas
"armazenada", ela nao aparece de verdade na `SC2` ainda.

2. Transferencia ainda nao cria movimento `RE4`/`DE4`

A API do Vitor hoje transfere saldo alterando `SB2.B2_QATU` na origem e no
destino. Isso ajuda a simular saldo, mas o gestor confirmou `RE4`/`DE4` para
transferencia/requisicao entre armazens.

Entao falta registrar tambem o movimento correto, provavelmente em `SD3`, para
a transferencia ficar auditavel como Protheus.

3. Exclusao de empenho usa delete fisico

Em `alterar_empenho`, quando a operacao e `excluir`, a API faz `DELETE FROM
SD4`. O Protheus costuma trabalhar com exclusao logica usando `D_E_L_E_T_ =
'*'`.

Eu mudaria para exclusao logica ou confirmaria com o gestor antes de usar em
base de teste compartilhada.

4. Produto bloqueado precisa ser filtrado na API tambem

A branch atual ja filtra `B1_MSBLQL = '1'` no app/Postgres. A API so checa se
o produto existe em `SB1`; ela ainda nao bloqueia produto com `B1_MSBLQL`.

Esse filtro precisa ir para a API tambem, senao um produto bloqueado pode
passar se alguem chamar o endpoint diretamente.

5. Chave e campos da `SD4` precisam de conferencia final

Na API, `_incluir_empenho` grava:

- `D4_COD = componente`;
- `D4_PRODUTO = componente`.

Na branch atual do Leonardo, a logica trata `D4_PRODUTO` como produto acabado
da OP e `D4_COD` como componente. Esse ponto precisa ser validado com a tabela
real do Protheus da Vetti antes de padronizar, porque e campo critico.

6. Banco esperado e diferente

A API do Vitor espera tabelas fisicas como `sc2010`, `sd4010`, `sb2010`.

A branch atual do Leonardo trabalha mais com schema `protheus_raw` e payloads
JSON/colunas geradas, como:

- `protheus_raw.sc2_orders`;
- `protheus_raw.sd4_commitments`;
- `protheus_raw.sb2_balances`;
- `protheus_raw.vw_sc2_orders_full`.

Antes de juntar, precisa decidir qual banco sera padrao de desenvolvimento:

- modelo Vitor: tabelas espelho fisicas `sc2010`, `sd4010`, etc.;
- modelo Leonardo: `protheus_raw` com payload JSON e views.

Minha preferencia tecnica e usar a API com tabelas fisicas, porque fica mais
perto do Protheus real. Mas o app atual nao deve escrever direto nelas; deve
chamar um gateway.

### Minha preferencia revisada

Eu priorizaria assim:

1. Base visual e operacional: branch `postgres-windows`.

Motivo: ela ja resolve o fluxo real discutido nos ultimos dias: SMD da Paula,
armazem 05 para producao, permissoes por pessoa, PIN, assinaturas, rota
personalizada, pausas, defeitos, relatorios e hot restart persistindo etapa.

2. Base de integracao Protheus: API do Vitor.

Motivo: ela cria uma fronteira limpa entre app e Protheus. O app Flutter nao
deveria carregar SQL pesado de `SC2`/`SD4`/`SB2` para sempre. A API tambem tem
idempotencia e auditoria, que sao essenciais quando varias pessoas mexem ao
mesmo tempo.

3. Regra de negocio Protheus: respostas do gestor, nao qualquer branch.

Motivo: tanto a sua branch quanto a do Vitor tem partes certas e partes que
foram feitas antes de algumas decisoes. A regra final deve ser:

- criacao: `SC2` + `SD4` + `SB2.B2_QEMP`, sem `SD3`;
- requisicao/apontamento: `RE1` no momento correto, nao na criacao;
- producao concluida: `PR0` + `RE1`, atualizando `SC2`, `SD4`, `SB2`;
- transferencia entre armazens: `RE4`/`DE4` e saldo fisico;
- etapa interna: auditoria VettiFlow, sem movimento Protheus por enquanto;
- MOD: aparece como custo/empenho quando fizer sentido, mas nao deve mover
  estoque fisico.

### Plano ideal de unificacao

1. Manter `postgres-windows` como branch de trabalho.
2. Copiar `api/` do Vitor para a branch atual.
3. Criar no Flutter uma interface unica, por exemplo `ProtheusGateway`.
4. Mover a escrita de `SC2`/`SD4`/`SB2` do Flutter para esse gateway.
5. Adaptar a API para a regra atual:
   - `aberturaOp` aplicada na criacao;
   - filtro `B1_MSBLQL`;
   - transferencia com `RE4`/`DE4`;
   - exclusao logica em `SD4`;
   - confirmar `D4_PRODUTO`.
6. Trazer os testes da API e rodar junto do fluxo Flutter.
7. Depois importar telas boas do Vitor:
   - fila do Protheus;
   - editor de empenho;
   - transferencia;
   - busca/visualizacao Protheus, se ainda fizer sentido.

### Decisao final revisada

Com a API aparecendo, minha preferencia ficou mais equilibrada:

- Eu nao manteria somente a sua branch.
- Eu nao migraria tudo para a branch do Vitor.
- Eu faria da sua branch o app principal e da API dele o backend de integracao.

Isso entrega o melhor dos dois: a sua branch tem o processo da fabrica mais
correto hoje; a branch dele tem a fronteira tecnica mais correta para escrever
no Protheus amanha.

## Resumo executivo

Minha recomendacao e usar a branch `postgres-windows` como base principal do projeto daqui para frente, porque ela esta mais alinhada com as decisoes mais recentes do gestor e com o banco PostgreSQL que voces estao testando agora.

A branch `integracao-protheus-mac` nao deve ser descartada. Ela tem uma camada muito boa de API/fila/idempotencia e testes bem fortes, mas a regra de negocio dela esta baseada em algumas decisoes antigas, principalmente a ideia de que o Protheus e dono da criacao da OP e que o VettiFlow apenas solicita/adota. Isso conflita com a conversa atual com o gestor, onde o app deve criar `SC2`, criar/atualizar `SD4` e empenhar em `SB2`.

## Validacao tecnica feita

Branch atual:

- `dart analyze lib test tools`: passou sem erros.
- `flutter test`: passou com 76 testes.
- Banco local confirmou a view completa da SC2: `protheus_raw.vw_sc2_orders_full` com 155 colunas e 15.992 registros.

Branch `integracao-protheus-mac`:

- `dart analyze lib test`: passou sem erros depois do `pub get`.
- `flutter test`: passou com 132 testes.
- Apos `git fetch --all --prune` em 05/08/2026, apareceu a pasta `api/` na branch do Vitor, commit `7ec3f81`. Ela contem uma FastAPI com `psycopg`, testes e README.

## O que eu manteria da branch atual

Eu manteria a branch atual como tronco pelos motivos abaixo.

1. Regras atuais do gestor

A branch atual ja segue a logica confirmada:

- Criacao da OP grava `SC2`.
- Criacao tambem gera empenho em `SD4`.
- `SB2.B2_QEMP` aumenta na criacao.
- Criacao nao gera `SD3`.
- Avanco de etapa nao movimenta Protheus por enquanto; fica como auditoria interna do VettiFlow.
- Cancelamento simples cancela/zera `SD4` e reduz `SB2.B2_QEMP`, sem `SD3`.

Isso esta em `lib/data/repositories/production_flow_database.dart` e `lib/data/models/protheus_stock_movement.dart`.

2. Postgres real e migracoes

A branch atual tem uma base de banco mais concreta:

- `db/migrations/001` a `021`.
- Views de leitura de `SB1`, `SB2`, `SG1`, `SC2`, `SD3`, `SD4`.
- Filtro de produto bloqueado por `B1_MSBLQL`.
- `vw_sc2_orders_full`, expondo praticamente todas as colunas da `SC2`.
- Scripts de importacao do export Protheus para o Postgres.

Isso e essencial para testar a regra real com os dados que voces tem hoje.

3. Fluxo operacional da fabrica

A branch atual esta mais perto do processo real que voces mapearam:

- Etapa `SMD` existe no fluxo.
- Paula aparece no SMD.
- Vera, Paula, Tatiane, Bruno, Vinicius, Bruna/Tamara e demais colaboradores estao melhor mapeados.
- Ha regras por armazem: `01` almoxarifado, `03` SMD, `05` producao, `06/07` suporte, `10` expedicao.
- Tatiane fica restrita a producao/expedicao, com almoxarifado e SMD mais como visualizacao.
- Ha assinatura por PIN nas acoes criticas.
- Ha rota personalizada de etapas.
- Ha historico de assinaturas, pausas, defeitos e tempos.

4. Layouts e telas recentes

Eu priorizaria os layouts atuais das telas operacionais, porque eles foram ajustados em cima dos prints e erros reais:

- Criacao de OP com SG1 primeiro.
- Escolha de armazem por componente.
- Cancelamento de OP mais legivel.
- Aba de equipe melhor em mobile.
- Relatorios de pausas/tempo mais legiveis.
- Correcoes de overflow recentes.
- SMD/fechamento/suporte/expedicao com regras mais proximas da operacao atual.

## O que eu manteria da branch do colega

Eu traria varios conceitos da branch `integracao-protheus-mac`, mas adaptando para a regra atual.

1. API Python e cliente de API

Manteria a ideia da API Python em `api/` junto com o `ProtheusSyncClient`:

- `GET /api/v1/health`
- `POST /api/v1/mutations`
- `POST /api/v1/finalizar`
- leitura ao vivo de OPs abertas
- leitura de empenhos da OP
- leitura de saldos por produto/armazem

Isso e importante porque o app Flutter nao deveria ficar para sempre escrevendo direto no banco espelho. A FastAPI pode virar a camada oficial entre VettiFlow e Protheus/Postgres.

Observacao apos o fetch: a API do Vitor ja implementa `aberturaOp`, `empenho`, `transferencia` e `baixaProducao`. Ela tambem cria uma tabela `vf_mutations` para auditoria/idempotencia e permite `VF_APPLY=0` para validar sem gravar.

2. Fila de mutacoes

Manteria a ideia de `PendingMutationStore`:

- cada acao tem ID de idempotencia;
- nada some se a API cair;
- status claro: pendente, enviando, armazenado, enviado, erro;
- tela de fila do Protheus;
- projecao do que esta pendente para a tela nao mostrar estoque velho.

Isso e muito forte para producao real. Se duas maquinas estiverem usando o app, a fila ajuda a evitar perda de movimento e deixa auditoria melhor.

3. Testes da regra de estoque

Eu importaria boa parte dos testes da branch dele, especialmente:

- `pending_mutation_test.dart`
- `armazem_saldo_test.dart`
- `baixa_producao_test.dart`
- `hybrid_repositories_test.dart`
- `empenho_editor_test.dart`

Mas esses testes precisam ser ajustados para a regra nova do gestor. Alguns ainda assumem que OP nasce no Protheus ou que a escrita real acontece so na finalizacao.

4. Modelos conceituais Protheus

Eu aproveitaria os modelos:

- `ProtheusOrder`
- `ProtheusOrderKey`
- `ProtheusEmpenho`
- `Armazem`
- `SaldoArmazem`

Eles ajudam a separar melhor o que e `SC2`, `SD4`, `SB2` e NNR, em vez de misturar tudo no modelo de tela.

## O que eu nao manteria como esta na branch do colega

1. Nao manteria a regra de "Protheus sempre cria a OP"

Na branch dele, ha comentarios e fluxos dizendo que o VettiFlow nao cria OP, apenas pede/adota uma OP que o Protheus numera. Isso conflita com a resposta atual do gestor:

- na criacao grava `SC2`;
- na criacao grava `SD4`;
- na criacao empenha em `SB2`;
- nao gera `SD3` nesse momento.

Entao a ideia de solicitacao e fila pode ficar, mas a regra precisa mudar.

2. Nao manteria apontamento Protheus no final exatamente como esta

A branch dele enfileira baixa de producao no fim, com consumo proporcional ao empenho real. Essa ideia e boa, mas precisa ser revisada com os codigos confirmados:

- `PR0` constroi item;
- `RE1` requisita materia-prima;
- transferencia entre armazens usa `RE4`/`DE4`;
- etapa interna do VettiFlow nao deve gerar movimento Protheus por enquanto.

3. Nao substituiria os layouts atuais pelos layouts dele sem revisao

Algumas telas dele sao boas, principalmente fila e editor de empenho. Mas as telas atuais ja foram ajustadas para problemas reais de mobile, permissao, SMD e fluxo da fabrica. Eu traria componentes dele pontualmente, nao a UI inteira.

## O que eu padronizaria daqui para frente

Minha proposta de padrao unico:

1. Banco e regra atual: usar `postgres-windows` como base.

2. Criar uma camada de servico unica para Protheus:

- hoje pode escrever direto no Postgres;
- amanha a mesma interface pode chamar FastAPI;
- o Flutter nao deve espalhar SQL e regra Protheus por varias telas.

3. Trazer a fila do colega, mas com nomes/regra nova:

- `CriacaoOpMutation`: grava `SC2`, `SD4`, `SB2_QEMP`;
- `TransferenciaArmazemMutation`: usa `RE4`/`DE4`;
- `ApontamentoProducaoMutation`: usa `PR0`/`RE1`;
- `CancelamentoOpMutation`: cancela `SD4`, reduz `SB2_QEMP`, e registra auditoria VettiFlow;
- `EtapaInternaMutation` nao deve existir como Protheus por enquanto; etapa interna fica no VettiFlow.

4. Manter `ProductionFlowStore` e `production_orders` como verdade do app.

O VettiFlow precisa saber etapa atual, responsavel, pausas, defeitos, assinatura e rota personalizada. Isso nao e Protheus puro. Entao:

- Protheus/Postgres guarda OP, empenho e estoque.
- VettiFlow guarda etapa, rota, assinatura, tempo, pausas, defeitos e responsavel interno.

5. Padronizar nomes de armazem:

- filial: `04`;
- almoxarifado: `01`;
- SMD: `03`;
- producao: `05`;
- suporte: confirmar se fica `06`, `07` ou ambos;
- expedicao: `10`.

6. Padronizar testes obrigatorios antes de merge:

- `dart analyze lib test tools`;
- `flutter test`;
- teste criando OP e verificando `SC2`, `SD4`, `SB2`;
- teste cancelando OP e verificando devolucao de empenho;
- teste avancando etapa e confirmando que nao cria `SD3`;
- teste futuro de API/fila com idempotencia.

## Prioridade de merge sugerida

Ordem recomendada:

1. Congelar a branch atual como base.
2. Trazer da branch dele apenas modelos de API/fila, sem trocar a regra atual.
3. Adaptar `PendingMutation` para os movimentos confirmados pelo gestor.
4. Criar uma interface tipo `ProtheusGateway`:
   - implementacao `PostgresProtheusGateway` agora;
   - implementacao `ApiProtheusGateway` depois.
5. Migrar a tela "Fila do Protheus" dele para acompanhar essa interface.
6. Trazer os testes dele e reescrever os que conflitam com as decisoes novas.
7. So depois pensar em unificar widgets de layout.

## Decisao recomendada

Eu priorizaria assim:

- Regra de negocio: branch atual.
- Banco/Postgres/migracoes: branch atual.
- Fluxo operacional, permissao e etapas: branch atual.
- Fila, API Python, idempotencia e tela de pendencias Protheus: branch do colega.
- Testes de fila e saldo projetado: branch do colega, adaptados.
- Modelos Protheus conceituais: branch do colega, mas conectados ao Postgres atual.
- Layout: usar o atual como base e importar apenas os componentes melhores dele, principalmente fila, editor de empenho e busca/adocao se ainda forem uteis.

Conclusao: nao e caso de "branch dele ou sua". E caso de usar a sua como linha principal e absorver a arquitetura de API/fila dele como camada futura. Isso evita jogar fora o que ja esta funcionando no Postgres e tambem evita perder a parte mais madura que ele fez para operar com API e falha de rede.
