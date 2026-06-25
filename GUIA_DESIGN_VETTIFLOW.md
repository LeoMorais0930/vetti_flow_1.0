# VettiFlow 1.0 — Guia de Design e Estilizacao

> Use este documento como referencia absoluta ao construir qualquer tela do VettiFlow.
> Todas as decisoes de cor, espacamento, tipografia, layout responsivo e fluxo funcional
> ja estao definidas aqui. NAO invente nada fora deste guia.

---

## 1. O QUE E O VETTIFLOW

Sistema de fluxo operacional de chao de fabrica da Vetti (fabricante de centrais de alarme).
Cada operador acessa UMA unica tela — definida pelo administrador. Nao existe menu lateral,
drawer ou navegacao entre telas. O operador loga e cai direto na tela dele.

### Telas (etapas de trabalho)

| Etapa        | Rota           | Descricao                                    |
|-------------|----------------|----------------------------------------------|
| Gravacao    | `/firmware`    | Gravacao de firmware em placas               |
| Soldagem    | `/soldagem`    | Soldagem SMD/manual                          |
| Teste       | `/teste`       | Teste funcional dos produtos                 |
| Expedicao   | `/expedicao`   | Despacho e embalagem                         |
| Almoxarifado| `/almoxarifado`| Controle de estoque e insumos                |
| Suporte     | `/suporte`     | Suporte tecnico interno                      |

### Operadores de teste

| Nome     | Usuario   | Senha | PIN  | Etapa        |
|----------|-----------|-------|------|-------------|
| Fernando | fernando  | 5643  | 5643 | Gravacao    |
| Carlos   | carlos    | 1234  | 1234 | Soldagem    |
| Ana      | ana       | 7890  | 7890 | Teste       |
| Ricardo  | ricardo   | 4321  | 4321 | Expedicao   |
| Julia    | julia     | 9999  | 9999 | Almoxarifado|
| Pedro    | pedro     | 1111  | 1111 | Suporte     |

---

## 2. PALETA DE CORES

Todas as cores estao em `lib/shared/theme/app_colors.dart`. Use SOMENTE estas:

### Cores principais
```
primary        = #0077BD    (azul principal — botoes, links, destaques)
primaryDark    = #004064    (azul escuro — sombras, gradientes)
```

### Superficies
```
background     = #EFF4F8    (fundo geral do app)
pageBackground = #F3F7FA    (fundo de paginas internas — mais claro)
surface        = #FFFFFF    (cards, modais, paineis)
field          = #FFFFFF    (campos de input)
border         = #D7E4EC    (bordas de cards e inputs)
```

### Texto
```
text           = #162C3A    (texto principal — titulos e valores)
title          = #003D60    (titulos de destaque — ex: "Entrar no sistema")
muted          = #5F7183    (texto secundario, descricoes)
label          = #5D6F80    (labels de campos e metricas)
smallText      = #6B7C8E    (texto pequeno, metadados)
iconMuted      = #7B93A4    (icones inativos)
```

### Semanticas
```
green          = #209F58    (sucesso, concluido, confirmar)
orange         = #D97706    (alerta, pausado, defeitos — bordas/fundos)
orangeText     = #B96300    (texto laranja — labels de defeitos/pausa)
buttonSoft     = #BDD9EA    (botao secundario suave)
```

### Cores de estado (usadas nos chips e cards de status)
```
Aguardando:  cor=#5F7183  fundo=#EFF3F7
Gravando:    cor=#0077BD  fundo=#E7F4FB
Pausada:     cor=#B96300  fundo=#FBF1E2
Concluida:   cor=#209F58  fundo=#E7F6EC
```

### Cores de feedback (modais/alertas)
```
Erro:        fundo=#FFF0F0  borda=#E8C4C4  texto=#D45B5B
Sucesso:     fundo=#E7F6EC  borda=#BFE5CC  texto=#209F58
Alerta:      fundo=#FFF8EC  borda=#EFDFBF  texto=#B96300
Info:        fundo=#EAF7FF  borda=#B8DFF2  texto=#0077BD
```

### Fundo escuro (moldura mobile)
```
mobileDark = #101820
```

---

## 3. TIPOGRAFIA

- **Fonte**: Arial (system fallback)
- **Pesos usados**: w400 (regular), w500 (medium), w600 (semibold), w700 (bold), w800 (extrabold), w900 (black)
- **NAO usar**: italico, decoracao, sombras em texto

### Escala de tamanhos

| Uso                        | Desktop  | Mobile   | Peso  |
|---------------------------|----------|----------|-------|
| Titulo principal da pagina | 24px     | 20px     | w800  |
| Numero da OP (detalhe)     | 24-26px  | 18-20px  | w900  |
| Nome do produto            | 17-18px  | 13-15px  | w700-w800 |
| Label de secao ("Acoes")   | 18-20px  | 17px     | w800  |
| Texto de corpo/descricao   | 13-14px  | 12-13px  | w400-w500 |
| Labels de metricas         | 12px     | 11px     | w700  |
| Valores de metricas        | 19px     | 16px     | w800  |
| Texto pequeno/metadado     | 11-12px  | 11px     | w500  |
| Botoes                     | 14-16px  | 14px     | w800  |
| Chips de status            | 10-12px  | 9-11px   | w800  |

### Regra geral
- Desktop: tamanhos ~15-25% maiores que mobile
- Nunca passar de 26px exceto no login ("Entrar no sistema" = 31px)
- `height` (line-height): 1.05-1.1 para titulos, 1.25-1.45 para corpo

---

## 4. ESPACAMENTO E RAIOS

### Border radius
```
Cards principais (paineis):      18px
Cards de items (OP na lista):    14px
Inputs e botoes:                 10-12px
Chips/badges:                    999px (pill)
Modais desktop:                  16px
Modais/sheets mobile:            22px
Moldura mobile:                  22px
```

### Paddings internos
```
Painel desktop (card grande):    28px
Painel mobile:                   14-22px
Card de item:                    16-20px
Botoes:                          altura 48-56px
Modais desktop:                  36px horizontal, 32px vertical
Modais mobile:                   24px horizontal, 16-24px vertical
```

### Gaps entre elementos
```
Entre cards na lista:            10-12px
Entre secoes:                    24-32px desktop, 16-24px mobile
Entre label e valor:             5-8px
Entre titulo e descricao:        4-8px
```

### Sombras
```
Cards principais:   color=primaryDark@0.04, blur=16, offset=(0,6)
Cards detalhe:      color=primaryDark@0.05, blur=18, offset=(0,8)
Bottom sheets:      color=black@0.12, blur=24, offset=(0,-4)
Login card desktop: color=primaryDark@0.20, blur=34, offset=(0,22)
```

### Bordas
```
Cards:    1px solid #E4EDF4
Selected: 1.5px solid primary (#0077BD)
Active:   1px solid statusColor@0.35
Botoes:   1.4-1.6px
```

---

## 5. LAYOUT RESPONSIVO — A REGRA DE OURO

### Breakpoints (AppBreakpoints)
```
compact:   < 600px     (celular)
medium:    600-1023px   (tablet)
expanded:  >= 1024px    (desktop)
```

Para a tela de firmware especificamente, o desktop ativa em >= 1180px.

### Desktop (expanded)
- `Scaffold` com `backgroundColor: AppColors.pageBackground`
- **VettiTopBar** no topo (72px de altura, fundo primary, logo VETTIFLOW + titulo + operador)
- Conteudo centralizado com `ConstrainedBox(maxWidth: 1180)`
- Layout tipico: `Row` com painel esquerdo (lista, ~340px) + painel direito (detalhe, Expanded)
- Ambos os paineis sao cards brancos com borda, radius 18, sombra sutil
- Padding externo: `EdgeInsets.fromLTRB(40, 32, 40, 36)`

### Mobile (compact + medium)
- **Moldura de celular**: fundo `#101820`, container branco centralizado
- `maxWidth: 430`, `margin: 10`, `borderRadius: 22`, `clipBehavior: Clip.antiAlias`
- VettiTopBar compact (104px, com titulo embaixo do logo)
- Conteudo scrollavel dentro da moldura
- Acoes em **bottom sheet flutuante** (nao inline)

### Anatomia da moldura mobile
```
Scaffold(backgroundColor: #101820)
  SafeArea
    Center
      Container(
        maxWidth: 430,
        margin: EdgeInsets.all(10),
        borderRadius: 22,
        clipBehavior: antiAlias,
        color: pageBackground ou surface,
        child: Column([
          VettiTopBar(compact: true),   // topo azul
          Expanded(                      // conteudo scrollavel
            SingleChildScrollView(...)
          ),
        ])
      )
```

---

## 6. COMPONENTES REUTILIZAVEIS

### VettiTopBar
Barra superior presente em TODAS as telas internas (nao no login).

**Desktop** (`compact: false`):
- Altura 72px, fundo `primary`
- Logo "VETTIFLOW" a esquerda (VETTI em branco 24px w900, FLOW em #DFF3FF 17px w900)
- Separador vertical branco@0.45
- Titulo da tela em branco 22px w900
- Operador a direita: "Operador logado" 13px #DFF3FF + nome 16px branco w900

**Mobile** (`compact: true`):
- Altura 104px, fundo `primary`, radius top 22
- Logo + operador na primeira linha
- Titulo abaixo, 16px w800

### OperationCard (card de item na lista)
- Raio 14px
- Fundo: branco (inativo), `#EAF7FF` (selecionado), `status.surface` (ativo nao selecionado)
- Borda: `border` normal, `primary` selecionado, `status.color@0.35` ativo
- Barra lateral colorida de 4px quando ativo (cor do status)
- Mini chip de status quando ativo (icone + label)
- Icone direito: radio_button_checked (selecionado) ou chevron_right (normal)
- Conteudo: numero da OP (15-16px w800) + produto (13px w700 primary) + metadados (11px)

### OperationStatusChip
- Pill (radius 999) com fundo `status.surface`, icone + label em `status.color`
- Desktop: padding 14x7, font 12px
- Mobile: padding 12x6, font 11px

### OperationMetrics (faixa de metricas)
- Container unico branco, radius 12, borda `#E4EDF4`
- Row de items com separadores verticais de 1px `#E9F0F5`
- Cada item: label (12px w700 label) + valor (19px w800 text)
- 3 metricas: Quantidade, Origem, Recebida

### OperationActions (botoes de acao por estado)
- **Aguardando**: so "Iniciar gravacao" (primary, branco)
- **Gravando**: "Pausar OP" (outline orange) + "Concluir OP" (green filled)
- **Pausada**: "Retomar gravacao" (primary filled) + "Concluir OP" (outline green)
- **Concluida**: banner verde de confirmacao
- Botoes: 50-54px altura, radius 10, font 14px w800
- Pares em Row com gap 12px, max 480px

### Bottom sheet mobile (acoes flutuantes)
- `margin: EdgeInsets.fromLTRB(10, 0, 10, 10)`
- Branco, radius 22, sombra `black@0.12 blur24 offset(0,-4)`
- Handle centralizado: 40x4px `#CBD7E1` radius 2
- Conteudo: header (numero + produto + chip) → metricas → acoes

---

## 7. FLUXO FUNCIONAL — MAQUINA DE ESTADOS

### Login
1. Operador digita usuario + senha
2. `Operator.authenticate()` valida
3. Se invalido: mostra banner vermelho "Usuario ou senha incorretos"
4. Se valido: `pushReplacementNamed(operator.stage.route)` — vai direto pra tela dele

### Operacao (ex: firmware, mas vale pra todas)
Cada OP tem seu proprio estado independente (`Map<int, Status>`).

```
AGUARDANDO ──[Iniciar]──> GRAVANDO/ATIVA
GRAVANDO ──[Pausar]──> PAUSADA
GRAVANDO ──[Concluir]──> (dialog defeitos → dialog PIN) → CONCLUIDA
PAUSADA ──[Retomar]──> GRAVANDO
PAUSADA ──[Concluir]──> (dialog defeitos → dialog PIN) → CONCLUIDA
```

- Trocar de OP **NAO** reseta o estado da anterior
- Pode ter multiplas OPs ativas ao mesmo tempo
- O card mostra visualmente o estado de cada OP (barra colorida + chip)

### Fluxo de conclusao (Concluir OP)

**Passo 1 — Dialog de defeitos:**
- Lista de defeitos A-H como chips clicaveis (toggle)
- Se nenhum selecionado: botao "Continuar sem defeitos"
- Se selecionados: mostra caixa amarela com resumo + botao "Continuar com N"
- Cancelar = volta sem fazer nada

**Passo 2 — Dialog de PIN (assinatura):**
- Input de 4 digitos (numerico, obscurecido, centralizado, letter-spacing 12)
- Auto-verifica ao completar 4 digitos usando `Operator.findByPin()`
- **PIN valido + mesma etapa**: feedback verde "Operador: Nome (Etapa)" — botao habilitado
- **PIN valido + etapa diferente**: feedback amarelo "PIN de Nome, vinculado a etapa X. Voce esta na etapa Y." — botao **DESABILITADO**
- **PIN nao encontrado**: feedback vermelho "PIN nao encontrado" — botao desabilitado
- Borda do input muda: verde (valido), vermelho (invalido), azul (focado), cinza (neutro)
- Se havia defeitos, mostra faixa amarela com codigos

### Regras do PIN
- Cada operador tem um PIN unico de 4 digitos
- O PIN identifica QUEM concluiu a OP (rastreabilidade)
- So permite concluir se o PIN pertence a mesma etapa de trabalho
- Isso impede que alguem da soldagem assine uma conclusao de firmware

---

## 8. COMO CONSTRUIR UMA NOVA TELA

### Checklist obrigatorio

1. **Criar o arquivo** em `lib/ui/{etapa}/{etapa}_page.dart`
2. **Usar LayoutBuilder** com `AppBreakpoints` pra decidir desktop vs mobile
3. **Desktop**: Scaffold + VettiTopBar + conteudo em paineis brancos (cards) centralizados
4. **Mobile**: moldura de celular (fundo escuro, container 430, radius 22, VettiTopBar compact)
5. **Dados da OP**: cada tela recebe OPs com campos relevantes pra etapa
6. **Estado por OP**: `Map<int, StatusDaEtapa>` — nunca estado unico compartilhado
7. **Mobile: acoes em bottom sheet**, nao inline
8. **Desktop: detalhe no painel direito** com metricas + acoes
9. **Conclusao de OP**: sempre passa pelo fluxo defeitos → PIN

### Estrutura de arquivos por tela
```
lib/ui/{etapa}/
  {etapa}_page.dart              ← pagina principal (layouts mobile + desktop)
  widgets/
    {etapa}_models.dart          ← modelos de dados e enum de status
    {etapa}_card.dart            ← card de item na lista (se diferente do padrao)
    {etapa}_actions.dart         ← botoes por estado
    {etapa}_metrics.dart         ← metricas especificas (se diferentes)
    {etapa}_completion_dialogs.dart  ← defeitos + PIN (pode reusar do firmware)
```

### Template de estado por etapa (adaptar nomes)
```dart
enum SolderingStatus {
  waiting('Aguardando'),
  active('Em soldagem'),
  paused('Pausada'),
  completed('Concluida');
  // ... mesma estrutura de color, surface, icon
}
```

### O que MUDA entre telas
- Nomes dos status (ex: "Gravando" → "Em soldagem" → "Em teste")
- Campos da OP (firmware tem firmware-specificos, soldagem tem temperatura, etc.)
- Metricas exibidas (adaptar ao contexto da etapa)
- Acoes extras possiveis (ex: teste pode ter "Reprovar")
- Lista de defeitos (pode mudar de A-H pra outros codigos por etapa)

### O que NAO muda entre telas
- Paleta de cores
- Tipografia e escala de tamanhos
- Layout responsivo (moldura mobile, paineis desktop)
- VettiTopBar (so muda titulo e nome do operador)
- Fluxo de conclusao (defeitos → PIN)
- Bordas, raios, sombras, espacamentos
- Estilo de botoes e chips

---

## 9. MODAIS E DIALOGS

### Regra de exibicao
- **Desktop** (largura >= 720px): `showDialog` com `Dialog` centralizado
- **Mobile** (largura < 720px): `showModalBottomSheet` com margin e radius

### Anatomia do modal
```
_ModalSurface:
  Desktop: centralizado, maxWidth 480-520, padding 36x32, radius 16
  Mobile:  bottom, full-width, margin 10, padding 24x16-24, radius 22

Conteudo:
  [SheetHandle se mobile]           → 50x4px cinza, margin bottom 22
  Titulo                            → 24px w900 text
  Descricao                         → 13px muted
  [gap 24px]
  Conteudo especifico
  [gap 24-28px]
  Row de botoes: [Cancelar] [Acao]  → altura 48px, radius 10
```

### Botoes de modal
- **Cancelar**: fundo `#F6F9FB`, cor `muted`, borda `border`
- **Acao positiva**: fundo `green`, cor branca
- **Desabilitado**: fundo `#E4EDF4`, cor `muted`

---

## 10. INPUTS E CAMPOS

### Campos de texto
- Fundo: `#F8FBFD`
- Borda: `#D8E6EE` (normal), `primary` (focado), `#D45B5B` (erro)
- Radius: 12px
- Padding: 16x17px
- Texto: 15px w600 `text`
- Hint: 14px w400 `muted`
- Prefixo: icone em `iconMuted`

### Campo de PIN
- Numerico, obscurecido, maxLength 4
- `letterSpacing: 12`, `textAlign: center`
- Font: 22px w900
- Borda muda dinamicamente: verde (valido), vermelho (invalido), azul (focado)

---

## 11. REGRAS DE OURO

1. **Nunca** use cores fora da paleta definida
2. **Nunca** crie menu/drawer/sidebar — cada operador ve UMA tela
3. **Mobile SEMPRE** usa a moldura de celular (fundo escuro + container arredondado)
4. **Acoes mobile** SEMPRE em bottom sheet, nunca inline
5. **Estado por OP** — nunca um estado global que reseta ao trocar de OP
6. **Conclusao** SEMPRE passa por defeitos → PIN
7. **PIN** verifica automaticamente ao completar 4 digitos, NAO tem botao "verificar"
8. **Botoes** aparecem conforme o estado — nao mostra todos de uma vez
9. **Cards** em paineis brancos com bordas sutis — nada "solto" no fundo cinza
10. **Tipografia**: desktop ~15-25% maior que mobile, nunca maior que 26px (exceto login)
