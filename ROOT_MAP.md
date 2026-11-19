# ROOT_MAP.md

Однопакетный Flutter/Dart-проект `code_bridge_mini` v2.1.0 (Windows — основная платформа сборки, Flutter 3.24.x / Dart 3.5.x).

## Структура корня
- `lib/` — исходный код приложения (детали и контракты см. в `MAP.md`).
- `test/` — модульные тесты (`agent_template_test.dart`, `files_to_prompt_test.dart`, `project_naming_test.dart`, `response_parser_test.dart`, `zip_deploy_service_test.dart`).
- `windows/` — нативный Windows Runner (C++/CMake).
- `assets/` — ресурсы приложения (`tray.ico`).
- `.github/workflows/` — CI/CD пайплайны (`pr-checks.yml`, `windows-build.yml`, `main-validation.yml`).
- `build_portable.ps1` — упаковка портативной Windows x64 сборки.
- `pubspec.yaml`, `analysis_options.yaml` — зависимости (`provider`, `path`, `file_picker`, `window_manager`, `tray_manager`, `archive`) и правила анализатора.
- `AGENTS.md`, `ROOT_MAP.md`, `MAP.md`, `HANDOFF.yaml` — протокол разработки, карты и передача контекста.

## Точки входа
- Dart/Flutter: `lib/main.dart` (принимает CLI-аргумент `.zip` + IPC-мост) -> `lib/app.dart` -> `lib/screens/home_screen.dart`.
- Windows Runner: `windows/runner/main.cpp`.
- Портативная сборка: `build_portable.ps1`.
