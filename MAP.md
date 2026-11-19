# MAP.md (code_bridge_mini)

## Точка входа и UI
- `lib/main.dart` — инициализация `AppStorage`, `SingleInstanceBridge` (приём `.zip` через CLI / «Открыть с помощью»), `window_manager`, `AppTrayService`, запуск `ProjectProvider` и `CodeBridgeMiniApp`.
- `lib/app.dart` — `CodeBridgeMiniApp` (Material 3 тема, корневой `HomeScreen`).
- `lib/screens/home_screen.dart` — основной экран с 4 вкладками: Инструкция, Ответ ИИ, Файлы проекта, Авто-деплой.
- `lib/widgets/auto_deploy_tab.dart` — вкладка «Авто-деплой»: фоновый мониторинг `Downloads`, настройки Git/GitHub проекта, ручной выбор `.zip` и журнал деплоя.
- `lib/widgets/section_header.dart` — переиспользуемый заголовок секции.

## Состояние (`lib/providers/`)
- `project_provider.dart` — `ProjectProvider` (`ChangeNotifier`): управление проектами, шаблонами (`flutter-monorepo-agents`), генерацией `agent.md`, разбором ответов, фоновым мониторингом `Downloads` и пайплайном `deployZipArchive` (проверка ZIP -> распаковка -> `git push`).

## Модели (`lib/models/`)
- `code_project.dart` — `CodeProject` (id, display name, packageName, пути, templateId, настройки авто-деплоя: `gitRepoUrl`, `gitBranch`, `autoDeployEnabled`, `zipNameFilter`, `deleteZipAfterDeploy`, `cleanBeforeExtract`).
- `agent_template_item.dart` — `AgentTemplateItem` (id, name, content, isBuiltIn).
- `generated_file.dart` — `GeneratedFile` (path, content, isFragment, selected, sourceFormat, note).
- `app_settings.dart` — `AppSettings` (lastProjectId, windowWidth, windowHeight, selectedTemplateId, downloadsWatchPath, downloadsWatcherEnabled).

## Сервисы (`lib/services/`)
- `zip_deploy_service.dart` — `ZipDeployService`: инспекция ZIP (маркеры `pubspec.yaml` / `AGENTS.md`, защита от Zip Slip, снятие одиночной корневой папки) и распаковка с сохранением `.git/`.
- `git_service.dart` — `GitService`: проверка Git, `git init` / настройка `origin`, `git add -A`, `git commit`, `git push -u origin <branch>` через локальный `git`.
- `downloads_watcher_service.dart` — `DownloadsWatcherService`: фоновый перехват новых `.zip` в `Downloads` с ожиданием окончания загрузки и дедупликацией.
- `single_instance_bridge.dart` — `SingleInstanceBridge`: локальный loopback IPC (`data/ipc_port.txt`) для передачи `.zip` уже запущенному окну при «Открыть с помощью -> code_bridge_mini.exe».
- `agent_template.dart` — `AgentTemplate`: встроенные шаблоны (включая `flutter-monorepo-agents`) и рендер переменных.
- `app_storage.dart` — `AppStorage`: локальное хранение в `data/` (`settings.json`, `projects/`, `templates/index.json`).
- `files_to_prompt.dart` — `FilesToPrompt`: сбор файлов/каталогов в промпт с фильтрацией `build/`, `.dart_tool/`, `ephemeral/`, `*.g.dart`, `*.freezed.dart`, `*.gr.dart`.
- `response_parser.dart` — `ResponseParser`: разбор ответов ИИ (`<<<FILE>>>` и Markdown-блоки).
- `file_writer.dart` — `FileWriter`: безопасная локальная запись UTF-8/LF и слияние фрагментов `pubspec.yaml`.
- `project_naming.dart` — `ProjectNaming`: транслитерация имён проектов в Dart package slug.
- `app_tray_service.dart` — `AppTrayService`, `AppWindowCloseListener`: сворачивание в трей Windows.
- `window_size_listener.dart` — `WindowSizeListener`: сохранение размеров окна.

## Тесты (`test/`)
- `agent_template_test.dart` — встроенный шаблон `AGENTS.md` и рендер переменных.
- `files_to_prompt_test.dart` — экспорт файлов и фильтрация сгенерированного кода/каталогов.
- `project_naming_test.dart` — генерация package slug.
- `response_parser_test.dart` — парсинг форматов ответов ИИ.
- `zip_deploy_service_test.dart` — проверка ZIP, снятие корневой папки, защита от path traversal, сохранение `.git/`.
