# VettiFlow 1.0

Projeto Flutter/Dart base para implementar as telas do VettiFlow.

## Rodar localmente

```powershell
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5174
```

Abra:

```text
http://127.0.0.1:5174
```

## Estrutura inicial

```text
lib/
  app/
    vetti_flow_app.dart
  ui/
    auth/
      login_page.dart
      widgets/
        login_brand_panel.dart
        login_form_panel.dart
    firmware/
      firmware_page.dart
      widgets/
        firmware_completion_dialogs.dart
        firmware_models.dart
        operation_actions.dart
        operation_card.dart
        operation_metrics.dart
    shared/
      widgets/
        vetti_top_bar.dart
  shared/
    theme/
      app_colors.dart
      app_theme.dart
```

## Base pronta

- App Flutter criado com o package `vetti_flow_1_0`.
- Login inicial responsivo para desktop e mobile, seguindo a tela de referencia do VettiFlow.
- Tela de gravacao de firmware responsiva, com fluxo de defeitos e assinatura por PIN.
- Tema central com a cor Vetti `#0077BD`.
- Logo VettiFlow em `assets/images/vetti-flow-logo.png`.
- Tela preparada para trocar o `SnackBar` por chamada real de backend depois.
