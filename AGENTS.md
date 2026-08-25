# VettiFlow Flutter App

Flutter app for production flow management at Vetti.

## Platforms
Windows, Web, Android, macOS — all from a single codebase.

## Project structure
```
lib/
  app/                   — App entry (MaterialApp + RepositoryProvider)
  shared/theme/          — AppColors, AppTheme (IBM Plex Sans via google_fonts)
  data/models/           — OrdemProducao, Responsavel, StatusOP
  data/repositories/     — OpRepository (abstract) + MockOpRepository
  ui/auth/               — Login page & widgets
  ui/dashboard/          — Dashboard page with desktop/mobile layouts
  ui/dashboard/cubit/    — DashboardCubit + DashboardState (flutter_bloc)
  ui/dashboard/widgets/  — Sidebar, KPIs, FilterBar, OpCard, DetailPanel, NovaOpDialog
  ui/dashboard/views/    — KanbanView, TableView, CardsView
```

## Build & run
```bash
flutter pub get
flutter run -d <device>
```

## Conventions
- Portuguese (pt-BR) for user-facing strings
- Responsive: LayoutBuilder with breakpoint at 920px (desktop vs mobile)
- Theme colors in `AppColors`, theme config in `AppTheme`
- State management: flutter_bloc (Cubit pattern)
- Repository pattern: abstract OpRepository, swap MockOpRepository for ProtheusOpRepository later
- Fonts: IBM Plex Sans (UI) + IBM Plex Mono (codes/numbers) via google_fonts

## Cross-platform
- Line endings normalized to LF via `.gitattributes`
- Machine-specific files (local.properties, Generated.xcconfig, plugin registrants) are gitignored
- After clone: `flutter pub get` regenerates all platform-specific files
