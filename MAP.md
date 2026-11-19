# MAP.md (code_bridge_mini)

## Точка входа и UI
- `lib/main.dart` — инициализация `AppStorage`, `SingleInstanceBridge`, `WindowSizeListener`, `AppTrayService`, восстановление размеров и состояния окна (развёрнутое / полный экран), запуск `ProjectProvider` и `CodeBridgeMiniApp`.
- `lib/app.dart` — `CodeBridgeMiniApp` (Material 3 тема, корневой `HomeScreen`).
- `lib/screens/home_screen.dart` — главный экран, горячие клавиши (`Ctrl+N`, `Ctrl+,`, `Ctrl+Q`), боковая панель проектов, синхронизация вкладок и рабочее пространство проекта.
- `lib/widgets/compact_app_menu.dart` — тёмное каскадное меню с подменю (`Файл`, `Деплой и сборки`, `Бэкап и настройки`, `Окно`), статусами и настройками.
- `lib/widgets/auto_deploy_tab.dart` — вкладка «Авто-деплой»: мониторинг «Загрузок», настройки Git/GitHub, папка версий ZIP, ручной выбор `.zip` и журнал деплоя.
- `lib/widgets/build_capture_tab.dart` — вкладка «Распаковка сборок»: перехват и распаковка `.zip` сборок в `_history` и `current`, сохранение файлов, автопроверка/автоскачивание с GitHub.
- `lib/widgets/section_header.dart` — заголовок секции.
- `lib/widgets/files_to_prompt_dialog.dart` — диалог сборки файлов/папки в промпт для ИИ.
- `lib/widgets/home_shortcuts.dart` — глобальные горячие клавиши главного окна.

## Состояние (`lib/providers/`)
- `project_provider.dart` — `ProjectProvider` (`ChangeNotifier`): управление проектами, шаблонами, генерацией инструкций, разбором ответов, мониторингом «Загрузок», авто-деплоем, распаковкой сборок, фоновым опросом сборок GitHub и бэкапами.

## Модели (`lib/models/`)
- `code_project.dart` — `CodeProject` (метаданные проекта, пути, настройки авто-деплоя, перехвата/распаковки сборок и автопроверки с GitHub).
- `app_settings.dart` — `AppSettings` (последний проект, размеры и состояние окна, шаблоны, мониторинг «Загрузок», порядок и активная вкладка, GitHub токен/владелец, бэкапы, сохраняемые источники сборок GitHub).
- `agent_template_item.dart` — `AgentTemplateItem`.
- `generated_file.dart` — `GeneratedFile`.

## Сервисы (`lib/services/`)
- `github_build_fetcher_service.dart` — `GitHubBuildFetcherService`: проверка успешных прогонов workflow / артефактов и релизов на GitHub с учётом фильтра и скачивание `.zip`.
- `github_build_polling_service.dart` — `GitHubBuildPollingCoordinator`: фоновый опрос и автоприменение сборок GitHub для проектов.
- `build_bundle_service.dart` — `BuildBundleService`: сохранение предыдущей сборки в `_history`, оверлей/сохраняемые файлы и распаковка новой сборки в `current`.
- `zip_deploy_service.dart` — `ZipDeployService`: проверка и распаковка проектных `.zip` с сохранением `.git/`.
- `git_service.dart` — `GitService`: локальные операции Git (`init`, `remote`, `commit`, `push`, автосинхронизация при отказе).
- `github_repo_service.dart` — `GitHubRepoService`: создание и подключение репозиториев на GitHub.
- `backup_service.dart` — `BackupService`: создание и восстановление полных бэкапов данных проекта.
- `downloads_watcher_service.dart` — `DownloadsWatcherService`: фоновый мониторинг папки «Загрузок».
- `single_instance_bridge.dart` — `SingleInstanceBridge`: локальный IPC для передачи `.zip` запущенному экземпляру.
- `agent_template.dart` — `AgentTemplate`: шаблоны инструкций и рендер переменных.
- `app_storage.dart` — `AppStorage`: хранение настроек, проектов и шаблонов в каталоге данных.
- `app_version.dart` — `AppVersion` и `ReleaseEntry`: текущая версия и история релизов.
- `files_to_prompt.dart` — `FilesToPrompt`: сбор файлов проекта в текст для ИИ.
- `response_parser.dart` — `ResponseParser`: разбор ответов ИИ.
- `file_writer.dart` — `FileWriter`: запись файлов и слияние фрагментов `pubspec.yaml`.
- `project_naming.dart` — `ProjectNaming`: формирование имени пакета.
- `app_tray_service.dart` — `AppTrayService`, `AppWindowCloseListener`: системный трей Windows и сохранение состояния при закрытии/выходе.
- `window_size_listener.dart` — `WindowSizeListener`: отслеживание и сохранение размеров и состояния окна.

## Тесты (`test/`)
- `agent_template_test.dart`
- `files_to_prompt_test.dart`
- `project_naming_test.dart`
- `response_parser_test.dart`
- `zip_deploy_service_test.dart`
