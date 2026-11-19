# История изменений CodeBridge Mini

## 2.1.39+39
- Восстановлены методы и геттеры `ProjectProvider` (`deployZipArchive`, `zipVersionsDirectoryFor`, `checkCurrentProjectGit`, `clearDeployLogs`, `applyBuildArchive`, `dismissPendingBuild`, `confirmPendingBuild`, `checkAndApplyGitHubBuilds`, `prepareForGracefulExit`), добавлен `dart:convert` и `super.key` в `files_to_prompt_dialog.dart` и убраны неиспользуемые элементы анализатора.

## 2.1.38+38
- Вынесены диалоги проектов в `lib/widgets/project_dialogs.dart`, диалог настроек и бэкапов в `lib/widgets/about_backup_dialog.dart`, а управление бэкапами выделено в `BackupCoordinator` (`lib/services/backup_coordinator_service.dart`).

## 2.1.37+37
- Вынесен диалог «Файлы → текст для ИИ» в `lib/widgets/files_to_prompt_dialog.dart`, логика фонового опроса сборок GitHub выделена в `GitHubBuildPollingCoordinator` (`lib/services/github_build_polling_service.dart`), а список релизов в `AppVersion` сокращён до последних ключевых версий.

## 2.1.36+36
- Обновлены `AGENTS.md`, `ROOT_MAP.md` и `MAP.md`, а горячие клавиши вынесены в отдельный виджет `lib/widgets/home_shortcuts.dart` для снижения разрастания `lib/screens/home_screen.dart`.

## 2.1.35+35
- Исправлены ошибки и подсказки анализатора в `lib/models/app_settings.dart` (лишний `);` в `AppSettings.fromJson`) и `lib/screens/home_screen.dart` (`unawaited`, `const Shortcuts` и выход по `Ctrl+Q`).

## 2.1.34+34
- Синхронизирован контроллер вкладок с `selectedTabIndex` из меню, добавлен фоновый опрос сборок GitHub для всех проектов с включённой автопроверкой, выведены текущие статусы в меню и добавлено бережное сохранение состояния окна и остановка таймеров при выходе / `Ctrl+Q`.

## 2.1.33+33
- Исправлены ошибки и предупреждения анализатора (`referenced_before_declaration` в `lib/main.dart`, `duplicate_definition` `clearDeployLogs` в `lib/providers/project_provider.dart` и `deprecated_export_use` `BytesBuilder` в `lib/services/github_build_fetcher_service.dart`).

## 2.1.32+32
- Добавлены горячие клавиши (`Ctrl+N`, `Ctrl+,`, `Ctrl+Q`) и синхронизация переключения вкладок, сохранение обработанных источников сборок GitHub между перезапусками, учёт фильтра сборок при автоскачивании, актуальная версия в подсказке трея и кнопка открытия папки версий ZIP в «Авто-деплое».

## 2.1.31+31
- Восстановлены методы `ProjectProvider` (`checkCurrentProjectGit`, `clearDeployLogs`, `dismissPendingBuild`, `confirmPendingBuild`, `createBackupNow`, `updateBackupSettings`, `restoreBackup`) и исправлены ошибки/подсказки анализатора в `lib/widgets/compact_app_menu.dart`.

## 2.1.30+30
- Добавлено тёмное компактное меню с подменю (`Файл`, `Деплой и сборки`, `Бэкап и настройки`, `Окно`), быстрыми переключателями настроек программы и пунктами `Настройки` / `Выйти`.

## 2.1.29+29
- Добавлено сохранение и восстановление последнего состояния окна при запуске (развёрнутое окно, полноэкранный режим и размеры) через `AppSettings`, `AppStorage`, `WindowSizeListener`, `AppTrayService` и `main.dart`.

## 2.1.28+28
- Добавлен `GitHubBuildFetcherService` и автопроверка/автоскачивание готовых сборок с GitHub (артефакты успешных workflow runs и релизы) с автоматическим применением через `applyBuildArchive`.

## 2.1.27+27
- Исправлена ошибка анализатора `undefined_named_parameter` (`errorCode`) в `lib/services/github_repo_service.dart`.

## 2.1.26+26
- Исправлена синтаксическая ошибка в `CodeProject.fromJson` (`lib/models/code_project.dart`): убран лишний `);` после `zipArchiveFolder`, из-за которого поля `buildCapture*` падали с `missing_identifier` и `unused_label`.

## 2.1.25+25
- В диалоге создания проекта добавлен режим **«Подключить готовый репозиторий»**: автоматический `git clone` при пустой/отсутствующей папке либо привязка `origin` и проверка статуса Git для существующей папки без перезаписи стартовых файлов без разрешения, с автозаполнением настроек авто-деплоя.

## 2.1.24+24
- Во вкладке «Авто-деплой» возвращена прежняя опция удаления исходного ZIP после успешного `push` и добавлена новая опция автоматического переноса в папку версий проекта с сохранением всех версий.

## 2.1.23+23
- В авто-деплое вместо удаления ZIP-архива после успешного `push` добавлен автоматический перенос в папку версий проекта (`_zip_versions` внутри каталога проекта или заданную папку) с сохранением всех версий.

## 2.1.22+22
- Удалены лишние модификаторы `const` (`unnecessary_const`) внутри `const Row` в `lib/screens/home_screen.dart`.

## 2.1.21+21
- Устранены подсказки `prefer_const_constructors` и `prefer_const_literals_to_create_immutables` в диалоге «О программе» (`lib/screens/home_screen.dart`).

## 2.1.20+20
- Исправлена ошибка `argument_type_not_assignable` при вызове `_findProject` с `String?` в `lib/providers/project_provider.dart` и подсказки `prefer_const` в `lib/screens/home_screen.dart`.

## 2.1.19+19
- Исправлены ошибки анализатора в `lib/providers/project_provider.dart` (`duplicate_import`, `undefined_identifier` для `AgentTemplate`) и замечания `prefer_const` в `lib/screens/home_screen.dart`.

## 2.1.18+18
- В `ProjectProvider` при загрузке и нормализации `tabOrder` из `settings.json` добавлен идентификатор `build_capture`, из-за отсутствия которого вкладка «Распаковка сборок» отсеивалась при старте.

## 2.1.17+17
- Добавлен `BackupService` для полного сохранения настроек, проектов, шаблонов и наработок в ZIP-архивы с ротацией и восстановлением.
- Добавлены автобэкап по расписанию, настройка папки бэкапов и кнопки ручного бэкапа/восстановления в разделе «О программе».

## 2.1.16+16
- Единый номер версии `2.1.16+16` вынесен в `AppVersion` (`lib/services/app_version.dart`), синхронизирован с `pubspec.yaml`, отображается в шапке приложения и в разделе «О программе».
- Добавлен раздел **«О программе»** с полной историей изменений по версиям и быстрым открытием папки данных.

## 2.1.15+15
- При создании проекта автоматически заполняются настройки авто-деплоя (`autoDeployEnabled`, `zipNameFilter`, `gitBranch`, `autoSyncOnReject`) и при необходимости включается мониторинг «Загрузок».
- Добавлены переключатель автозаполнения, поле фильтра имени ZIP и чекбокс автосинхронизации в диалог создания проекта.

## 2.1.14+14
- Добавлен `GitHubRepoService` для создания приватных и публичных репозиториев на GitHub (через GitHub API или `gh CLI`) и генерации базовых файлов проекта (`README.md`, `.gitignore`, `AGENTS.md`).
- Добавлены сохранение `githubOwner` и `githubToken` в `settings.json` и автозаполнение `gitRepoUrl` и `gitBranch` в новом проекте.

## 2.1.13+13
- Подключена вкладка **«Распаковка сборок»** (`build_capture`) во всех переключателях рабочего пространства в `lib/screens/home_screen.dart`.

## 2.1.12+12
- Удалено дублирующееся определение `_openFolder` в `lib/screens/home_screen.dart`.

## 2.1.11+11
- Устранены замечания `flutter analyze` в `lib/screens/home_screen.dart` и `lib/widgets/auto_deploy_tab.dart`.

## 2.1.10+10
- Добавлена кнопка **«Открыть сборку»** в шапке проекта для открытия актуальной папки собранной версии (`current`).

## 2.1.9+9
- Весь функционал распаковки после компиляции вынесен в отдельный виджет `BuildCaptureTab` и вкладку **«Распаковка сборок»**.

## 2.1.8+8
- Восстановлены авто-синхронизация при отклонении `git push` (`autoSyncOnReject`), ручное редактирование `AGENT.md` и переименование проекта.

## 2.1.7+7
- Добавлены настройки сохранения оверлея старой версии и очистки перед сборкой (`overlayPreviousVersion`, `clearTargetBeforeApply`).

## 2.1.6+6
- Исправлены предупреждения `prefer_interpolation_to_compose_strings` и `unused_field`.

## 2.1.5+5
- Добавлен режим взятия всех подходящих ZIP-архивов для публичных сборок (`buildTakeAllPublicBuilds`).

## 2.1.4+4
- Исправлены ошибки анализатора в `build_bundle_service.dart`, `app_storage.dart`, `project_provider.dart` и `auto_deploy_tab.dart`.

## 2.1.3+3
- Добавлены перетаскивание/перемещение вкладок с сохранением порядка в `settings.json` и кнопка открытия папки.
