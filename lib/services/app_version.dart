class ReleaseEntry {
  const ReleaseEntry({
    required this.version,
    required this.buildNumber,
    required this.title,
    required this.summary,
    required this.changes,
  });

  final String version;
  final int buildNumber;
  final String title;
  final String summary;
  final List<String> changes;

  String get fullVersion => '$version+$buildNumber';
}

class AppVersion {
  static const String currentVersion = '2.1.38';
  static const int currentBuildNumber = 38;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.38',
      buildNumber: 38,
      title: 'Вынесены диалоги проектов/настроек и координатор бэкапов',
      summary: 'Продолжена разгрузка home_screen.dart и project_provider.dart за счёт выделения диалогов проектов, диалога настроек/бэкапов и BackupCoordinator.',
      changes: [
        'Вынесены диалоги создания и переименования проекта в lib/widgets/project_dialogs.dart',
        'Вынесен диалог настроек, бэкапов и истории версий в lib/widgets/about_backup_dialog.dart',
        'Выделен BackupCoordinator в lib/services/backup_coordinator_service.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.37',
      buildNumber: 37,
      title: 'Вынос диалога «Файлы → текст для ИИ», координатор опроса GitHub и компактная история версий',
      summary: 'Разгружены home_screen.dart и project_provider.dart за счёт выделения отдельных модулей, а история в AppVersion ограничена последними ключевыми релизами.',
      changes: [
        'Вынесен диалог «Файлы → текст для ИИ» в lib/widgets/files_to_prompt_dialog.dart',
        'Выделен GitHubBuildPollingCoordinator в lib/services/github_build_polling_service.dart',
        'Сокращён список ReleaseEntry в AppVersion до последних ключевых версий (полная история в CHANGELOG.md)',
      ],
    ),
    ReleaseEntry(
      version: '2.1.36',
      buildNumber: 36,
      title: 'Обновлены AGENTS.md, ROOT_MAP.md, MAP.md и вынесены горячие клавиши из home_screen.dart',
      summary: 'Актуализированы правила разработки и карты проекта, а блок горячих клавиш вынесен в отдельный модуль lib/widgets/home_shortcuts.dart для разгрузки home_screen.dart.',
      changes: [
        'Обновлены AGENTS.md, ROOT_MAP.md и MAP.md под актуальную архитектуру и процесс сборки',
        'Вынесен HomeShortcutsWrapper в lib/widgets/home_shortcuts.dart для уменьшения размера home_screen.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.35',
      buildNumber: 35,
      title: 'Исправлены ошибки анализатора в app_settings.dart и home_screen.dart',
      summary: 'Убран лишний ); в AppSettings.fromJson и исправлены вызовы unawaited / const Shortcuts в lib/screens/home_screen.dart.',
      changes: [
        'Удалён лишний закрывающий ); на строке 120 в lib/models/app_settings.dart',
        'Добавлен импорт dart:async, const для Shortcuts и корректный запуск асинхронного выхода в lib/screens/home_screen.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.34',
      buildNumber: 34,
      title: 'Синхронизация вкладок, фоновый опрос сборок для всех проектов и бережный выход',
      summary: 'Синхронизирован контроллер вкладок с меню, добавлен фоновый опрос сборок GitHub по всем активным проектам, добавлены статусы в меню и бережное сохранение состояния при выходе.',
      changes: [
        'Связаны TabController и provider.selectedTabIndex для мгновенного переключения вкладок из меню',
        'Расширен фоновый опрос сборок GitHub на все проекты с включённой автопроверкой',
        'Добавлены статусы проекта и автосборок в меню и бережное сохранение состояния окна/таймеров при выходе и Ctrl+Q',
      ],
    ),
    ReleaseEntry(
      version: '2.1.33',
      buildNumber: 33,
      title: 'Исправлены ошибки анализатора в main.dart, project_provider.dart и github_build_fetcher_service.dart',
      summary: 'Устранён порядок объявления windowSizeListener в main.dart, удалён дубликат clearDeployLogs в project_provider.dart и добавлен прямой импорт dart:typed_data.',
      changes: [
        'Исправлен порядок объявления windowSizeListener перед AppWindowCloseListener в lib/main.dart',
        'Удалено повторное объявление clearDeployLogs в lib/providers/project_provider.dart',
        'Добавлен импорт dart:typed_data для BytesBuilder в lib/services/github_build_fetcher_service.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.32',
      buildNumber: 32,
      title: 'Горячие клавиши, сохранение статуса сборок GitHub и кнопка папки версий ZIP',
      summary: 'Реализованы глобальные горячие клавиши, сохранение ID обработанных сборок GitHub между перезапусками, фильтр имени при автоскачивании, актуальная версия в трее и кнопка открытия папки версий ZIP.',
      changes: [
        'Добавлены горячие клавиши Ctrl+N, Ctrl+, и Ctrl+Q и синхронизация переключения вкладок из меню',
        'Сохраняется lastFetchedBuildSources в settings.json и учитывается buildZipFilter / buildTakeAllPublicBuilds при скачивании с GitHub',
        'Обновлён тултип трея на актуальную версию AppVersion и добавлена кнопка «Папка версий ZIP» во вкладку «Авто-деплой»',
      ],
    ),
    ReleaseEntry(
      version: '2.1.31',
      buildNumber: 31,
      title: 'Восстановлены методы ProjectProvider и исправлены ошибки анализатора в compact_app_menu.dart',
      summary: 'Восстановлены все методы ProjectProvider и исправлены синтаксические/анализаторные ошибки в lib/widgets/compact_app_menu.dart.',
      changes: [
        'Восстановлены checkCurrentProjectGit, clearDeployLogs, dismissPendingBuild, confirmPendingBuild, createBackupNow, updateBackupSettings и restoreBackup в ProjectProvider',
        'Исправлены кавычки, неиспользуемые поля и переключение максимизации/полного экрана через window_manager в compact_app_menu.dart',
      ],
    ),
  ];
}
