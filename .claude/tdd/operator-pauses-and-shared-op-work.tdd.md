# Operator Pauses And Shared OP Work TDD Evidence

## Source

Journeys derived from the user request on 2026-07-03: pauses must require PIN, a pause reason, optional produced quantity, and OPs must support more than one operator working in the same process.

## User Journeys

- As an operator, I want to pause an OP only after entering my PIN, a reason, and optional quantity produced so the manager can audit why I left the process.
- As two operators on the same stage, we want to work on the same OP independently so each person's time and signature are tracked.
- As a manager, I want to see pause exits and reasons in reports so I can audit work interruptions.

## Task Report

| Behavior | RED evidence | GREEN evidence | Guarantee |
|---|---|---|---|
| Pauses record PIN, reason, and quantity | `flutter test` failed because `PauseReason`, `pauseEvents`, `operatorSessions`, and signed pause parameters did not exist. | `flutter test` passed with `stage pause records operator pin, reason and optional quantity`. | Store records pause reason, operator PIN, and optional produced quantity. |
| Multiple operators can share one OP stage | `flutter test` failed because sessions and signed completion did not exist. | `flutter test` passed with `OP stage advances only after all active operators complete`. | One operator can complete their own session while the OP stays in the same stage until the remaining active operator also completes. |
| Pause UI requires signed reason | Existing soldering test expected immediate pause and failed after the new dialog was introduced. | `flutter test` passed after signing pause with PIN `3003`. | The pause action now opens a reason/PIN dialog before pausing. |
| Manager can see pause records | Implemented report panel reading `ProductionReport.pauseEvents`. | `flutter analyze` and `flutter build web` passed. | The reports tab now has a `Pausas e saidas` section with OP, operator, stage, reason, and quantity. |

## Validation

- `flutter test`: PASS, 21 tests.
- `flutter analyze`: PASS, no issues.
- `flutter test --coverage`: PASS, 21 tests, global line coverage 42.6% (3747/8791).
- `flutter build web`: PASS, built `build\web`.

## Coverage And Known Gaps

Global coverage is below the 80% target because many large Flutter screens remain lightly covered. This change added focused tests for the critical store guarantees and updated an existing widget flow for signed pause.

The automatic popup on the second operator's screen after another operator clicks conclude is not fully visualized yet. The store behavior is implemented conservatively: signed completion by one operator marks only that operator's session complete, and the OP does not advance while another active session remains. A follow-up UI pass can surface that pending confirmation as a real-time prompt/banner on the other operator's station.
