# Dashboard OP Priority TDD Evidence

## Source

Journeys derived from the user request on 2026-07-03: allow dashboard OP creation/management to mark an OP as priority because TV and operator screens already consume priority.

## User Journeys

- As a dashboard coordinator, I want to choose an OP priority when creating it so high-priority jobs appear correctly in VettiFlow TV and operator queues.
- As a dashboard coordinator, I want high-priority OPs to be visibly marked in dashboard cards/details so the priority is clear while managing production.

## Task Report

| Behavior | RED evidence | GREEN evidence | Guarantee |
|---|---|---|---|
| `NovaOrdemDTO` carries selected priority from the new OP dialog | `flutter test` failed to compile because `prioridade` did not exist on `NovaOrdemDTO`. | `flutter test` passed with `new OP dialog submits the selected priority`. | The dialog can submit `Alta` through `NovaOrdemDTO.prioridade`. |
| Dashboard-created OPs persist priority to the shared production flow | Same compile-time RED from missing `prioridade` parameter/getter. | `flutter test` passed with `flow repository creates dashboard OPs with selected priority`. | `FlowOpRepository.criarOrdem` writes `Alta` to `ProductionFlowStore`, making `isHighPriority` true for TV and queues. |
| Route wiring remains intact after the dashboard routing extraction | Existing route coverage retained. | `flutter test` passed with `every work stage has a registered app route`. | All `WorkStage.route` values remain registered in the app routes map. |

## Validation

- `flutter test`: PASS, 19 tests.
- `flutter analyze`: PASS, no issues.
- `flutter test --coverage`: PASS, 19 tests, global line coverage 41.7% (3507/8404).
- `flutter build web`: PASS, built `build\web`.

## Coverage And Gaps

Global coverage is below the TDD target because this Flutter app currently has large production screens with limited widget coverage. The new priority path is covered at the widget/DTO boundary and repository/store boundary. Follow-up coverage should add broader tests for dashboard cards/table/detail views and operator-stage screens.
