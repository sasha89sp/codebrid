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
  static const String currentVersion = '2.1.43';
  static const int currentBuildNumber = 43;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.43',
      buildNumber: 43,
      title: 'Исправлена ручная проверка и скачивание сборок с GitHub',
      summary: 'При ручном нажатии «Проверить и скачать с GitHub» добавлен forceRecheck, перебор последних успешных run и подробное логирование причин, если сборка не найдена или не задан URL/токен.',
      changes: [
        'Добавлен флаг forceRecheck при ручной проверке сборок с GitHub',
        'Добавлен перебор последних успешных workflow runs и проверка просроченных/пустых артефактов',
        'Добавлены понятные сообщения и записи в журнал при пустом URL, отсутствии токена или уже обработанной сборке',
      ],
    ),
    ReleaseEntry(
      version: '2.1.42',
      buildNumber: 42,
      title: 'Полноценное создание и редактирование новых шаблонов в библиотеке',
      summary: 'Вынесен диалог библиотеки шаблонов в lib/widgets/template_manager_dialog.dart, исправлена работа с черновиком нового шаблона, фокусом и сохранением.',
      changes: [
        'Вынесен TemplateManagerDialog в lib/widgets/template_manager_dialog.dart с явным управлением состоянием черновика нового шаблона',
        'Исправлено выделение/редактирование названия и текста нового шаблона с сохранением через provider.saveTemplate',
        'Обновлена карта модулей MAP.md и версия сборки до 2.1.42+42',
      ],
    ),
    ReleaseEntry(
      version: '2.1.41',
      buildNumber: 41,
      title: 'Журнал распаковки в стиле авто-деплоя, ротация _history и автозапуск .exe',
      summary: 'Журнал распаковки оформлен в едином тёмном стиле с журналом авто-деплоя, добавлены ротация _history, бережная обработка занятых файлов и опциональный запуск .exe.',
      changes: [
        'Добавлен журнал распаковки в стиле консоли авто-деплоя (0xFF141A26, Consolas, кнопка «Очистить») и статус последней проверки GitHub',
        'Добавлена ротация копий в _history (buildHistoryKeepCount) и бережная обработка занятых файлов при распаковке',
        'Добавлен опциональный автозапуск найденного .exe после обновления папки current (buildAutoLaunchExe)',
      ],
    ),
    ReleaseEntry(
      version: '2.1.40',
      buildNumber: 40,
      title: 'Исправлено редактирование нового шаблона и ошибки анализатора из 2.1.39',
      summary: 'Добавлены FocusNode и явное управление фокусом/readOnly в редакторе шаблонов, исправлены вызовы диалогов и удалены неиспользуемые импорты и функции.',
      changes: [
        'Добавлены _nameFocusNode, _contentFocusNode, readOnly: false и автофокус при создании шаблона в _TemplateManagerDialog',
        'Исправлены вызовы showCreateProjectDialog и showAboutBackupDialog в home_screen.dart',
        'Удалены неиспользуемые импорты и функции в home_screen.dart и about_backup_dialog.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.39',
      buildNumber: 39,
      title: 'Восстановлены методы деплоя/сборок в ProjectProvider и убраны замечания анализатора',
      summary: 'Восстановлены методы deployZipArchive, applyBuildArchive, checkAndApplyGitHubBuilds, prepareForGracefulExit и другие в ProjectProvider, добавлен utf8 и super.key, удалены неиспользуемые импорты и функции.',
      changes: [
        'Восстановлены методы и геттеры деплоя, перехвата сборок, опроса GitHub и корректного выхода в ProjectProvider',
        'Добавлен импорт dart:convert (utf8) и параметр super.key в FilesToPromptDialog',
        'Удалены неиспользуемые функции и импорт в about_backup_dialog.dart, files_to_prompt_dialog.dart и project_dialogs.dart',
      ],
    ),
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
  ];
}
