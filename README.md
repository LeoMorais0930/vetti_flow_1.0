# VettiFlow 1.0

[Portugues](#portugues) | [English](#english)

## Portugues

Aplicacao Flutter para acompanhamento visual do fluxo de producao da VETTI. O projeto cria uma experiencia operacional responsiva para desktop, web e dispositivos moveis, com telas para painel, ordens de producao, etapas, operadores e acompanhamento em tempo real.

### O problema

A operacao precisava de uma interface simples para visualizar ordens, status, prioridades e etapas sem depender de controles manuais espalhados.

### A solucao

O VettiFlow 1.0 entrega uma base de frontend para uso interno, com:

- Login e estrutura de rotas.
- Dashboard com cards, tabela, kanban, filtros e KPIs.
- Telas por etapa: firmware, solda, teste, almoxarifado, expedicao e fechamento.
- Visao de TV/painel para acompanhamento coletivo.
- Modelos e repositorios separados para evoluir de dados mockados/local storage para API real.
- Tema visual centralizado e identidade VettiFlow.

### Stack

- Flutter / Dart
- Flutter Web / PWA
- BLoC, Provider e repositorios locais
- Google Fonts e tema centralizado
- Estrutura preparada para integracao com API .NET

### Como rodar

```powershell
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5174
```

Abra:

```text
http://127.0.0.1:5174
```

### Estrutura principal

```text
lib/
  app/
  data/
    models/
    repositories/
  shared/
    layout/
    models/
    theme/
  ui/
    auth/
    dashboard/
    firmware/
    soldering/
    testing/
    warehouse/
    expedition/
    closing/
    tv/
```

### Status

Projeto em evolucao para consolidar uma ferramenta interna de producao. A base atual prioriza fluxo, usabilidade, responsividade e separacao de responsabilidades para facilitar a integracao com backend.

## English

Flutter application for visual tracking of VETTI's production flow. The project provides a responsive operational experience for desktop, web, and mobile devices, with screens for dashboards, production orders, stages, operators, and real-time monitoring.

### Problem

The operation needed a simple interface to track orders, status, priorities, and stages without relying on scattered manual controls.

### Solution

VettiFlow 1.0 provides an internal frontend foundation with:

- Login and route structure.
- Dashboard with cards, table, kanban, filters, and KPIs.
- Stage-oriented screens: firmware, soldering, testing, warehouse, expedition, and closing.
- TV/dashboard view for shared production visibility.
- Models and repositories separated to evolve from mocked/local data to a real API.
- Centralized theme and VettiFlow visual identity.

### Tech Stack

- Flutter / Dart
- Flutter Web / PWA
- BLoC, Provider, and local repositories
- Google Fonts and centralized theme
- Structure prepared for .NET API integration

### Running Locally

```powershell
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5174
```

Open:

```text
http://127.0.0.1:5174
```

### Status

Work in progress toward an internal production tool. The current version focuses on workflow, usability, responsiveness, and clean separation of responsibilities to make backend integration easier.
