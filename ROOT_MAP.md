# ROOT_MAP.md

Портативное настольное Flutter/Dart-приложение `code_bridge_mini` (CodeBridge Mini; основная платформа — Windows x64).

## Структура корня
- `lib/` — исходный код приложения (`main.dart`, `app.dart`, `models/`, `providers/`, `screens/`, `services/`, `widgets/`).
- `test/` — модульные тесты (`agent_template_test.dart`, `files_to_prompt_test.dart`, `project_naming_test.dart`, `response_parser_test.dart`, `zip_deploy_service_test.dart`).
- `windows/` — нативный Windows Runner (C++/CMake).
- `assets/` — ресурсы приложения (`tray.ico`).
- `.github/workflows/` — пайплайны проверок и сборки Windows (`pr-checks.yml`, `windows-build.yml`, `main-validation.yml`).
- `build_portable.ps1` — упаковка портативного ZIP-архива `CodeBridgeMini-Windows-x64.zip`.
- `pubspec.yaml`, `analysis_options.yaml` — зависимости и правила анализатора.
- `AGENTS.md`, `ROOT_MAP.md`, `MAP.md`, `HANDOFF.yaml`, `CHANGELOG.md` — правила разработки, карты и история.

## Точки входа
- Dart/Flutter: `lib/main.dart` -> `lib/app.dart` -> `lib/screens/home_screen.dart`.
- Windows Runner: `windows/runner/main.cpp`.
- Портативная сборка: `build_portable.ps1`.
