# Documentacao Resumida - VettiFlow

Data: 25/06/2026

## Objetivo do trabalho

Evoluir o VettiFlow para que o fluxo operacional funcione localmente de ponta a ponta, sem depender de API externa neste momento, preparando o sistema para uma futura integracao com o Protheus via leitura de dados SQL.

O foco foi permitir que uma OP seja criada no almoxarifado, avance pelas etapas reais da producao e seja acompanhada pela tela VettiFlow TV.

## Fluxo operacional implementado

Foi criado um fluxo local compartilhado para as OPs, permitindo que a mesma ordem avance pelas seguintes etapas:

1. Almoxarifado
2. Gravacao de firmware
3. Soldagem
4. Teste de producao
5. Expedicao
6. Armazenamento ou finalizacao

Cada tela passou a consultar e atualizar o mesmo estado local da OP. Assim, quando uma etapa conclui uma OP, ela sai da tela atual e aparece na proxima etapa.

## Almoxarifado

Foi adicionada uma nova aba para criar OP localmente.

Essa tela permite:

- Criar uma OP do zero para teste do fluxo.
- Selecionar produto, quantidade e prioridade.
- Visualizar componentes necessarios.
- Iniciar separacao.
- Pausar separacao.
- Concluir a separacao e liberar a OP para firmware.

Os produtos e componentes foram baseados nas informacoes do legado Vetti Config e firmware SmartAlarm32, incluindo itens como SmartAlarm32 V6.68, CR4, CR8, sensores magneticos, infravermelhos, sirene sem fio, teclado inteligente e botao de panico.

## Telas de producao

As telas de firmware, soldagem e teste foram conectadas ao novo fluxo local.

Agora elas permitem:

- Receber apenas OPs da etapa anterior.
- Iniciar execucao.
- Pausar execucao.
- Retomar quando aplicavel.
- Concluir a etapa e enviar a OP para a proxima tela.

Tambem foi adicionada a exibicao do tempo da OP na etapa, descontando periodos pausados.

## Expedicao e armazenamento

A expedicao foi ajustada para trabalhar com quantidades parciais.

Ao finalizar uma OP, o usuario pode:

- Expedir tudo.
- Armazenar tudo.
- Armazenar apenas parte da quantidade e expedir o restante.

A tela tambem possui uma aba de OPs armazenadas, onde e possivel expedir uma quantidade parcial ou total do que ficou armazenado.

A visualizacao foi melhorada para mostrar:

- Quantidade disponivel.
- Quantidade que sera armazenada.
- Quantidade restante que sera expedida.
- Historico visual das quantidades expedidas.

## VettiFlow TV

Foi criada uma tela VettiFlow TV dentro do proprio app.

Ela mostra:

- OPs em producao.
- Etapa atual de cada OP.
- Status da OP.
- Tempo da etapa atual.
- Tempo total acumulado.
- OPs finalizadas recentemente.

Como a API antiga sera descontinuada, a TV passou a ler o mesmo fluxo local do aplicativo. No navegador, o estado tambem e persistido e sincronizado entre abas via armazenamento local, permitindo abrir uma aba operacional e outra aba com a TV sem depender de servidor ou API intermediaria.

Rota da TV:

```text
/tv
```

## Saida do sistema

Foi adicionada a opcao de sair nas telas principais, incluindo:

- Almoxarifado
- Firmware
- Soldagem
- Teste
- Expedicao
- Suporte
- Dashboard
- TV

## Preparacao para Protheus

O sistema ainda nao faz leitura real do Protheus nesta etapa.

Porem, a estrutura foi preparada para que futuramente o fluxo local seja abastecido por uma rotina de leitura periodica do SQL do Protheus.

A ideia prevista e:

- O app consulta o SQL do Protheus em intervalos definidos.
- As OPs reais sao importadas ou atualizadas no fluxo do VettiFlow.
- As telas operacionais continuam usando o mesmo modelo interno.
- A TV passa a refletir automaticamente as OPs vindas do Protheus.

## Validacoes realizadas

Foram executadas as validacoes tecnicas:

```text
flutter analyze
flutter test
```

Resultado:

- Analise sem erros.
- Todos os testes automatizados passaram.

## Pontos pendentes / proximos passos

Os proximos pontos recomendados sao:

- Conectar o dashboard do gestor ao mesmo fluxo local das telas operacionais.
- Definir os campos reais que serao lidos do SQL do Protheus.
- Mapear os status oficiais do Protheus para as etapas do VettiFlow.
- Definir regra de OP com defeito no teste: seguir para suporte, retrabalho ou expedicao parcial.
- Criar configuracao de intervalo de atualizacao para leitura futura do Protheus.
- Persistir o fluxo tambem em arquivo ou banco local, caso o uso nao seja apenas web/browser.

## Resumo executivo

O VettiFlow passou a ter um fluxo operacional local funcional, permitindo criar OP no almoxarifado, acompanhar sua passagem pelas etapas produtivas, controlar pausas e tempos, separar quantidades para armazenamento e visualizar a producao em uma tela de TV integrada ao proprio app.

Essa entrega reduz a dependencia da API antiga e deixa o sistema mais preparado para a futura integracao direta com dados do Protheus.
