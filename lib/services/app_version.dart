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
  static const String currentVersion = '2.1.45';
  static const int currentBuildNumber = 45;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.45',
      buildNumber: 45,
      title: 'Панель окна в стиле macOS с поведением кнопок Windows',
      summary: 'Добавлена верхняя панель окна в стиле macOS («светофор») с сохранением поведения кнопок и границ изменения размера окна Windows через Win32 и MethodChannel.',
      changes: [
        'Добавлен виджет MacOsWindowTitleBar с кнопками закрытия, сворачивания и разворачивания/восстановления окна и перетаскиванием заголовка',
        'Настроен Win32-обработчик окна в windows/runner/flutter_window.cpp с сохранением рамки изменения размера и команд окна Windows',
        'Обновлена версия до 2.1.45+45 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.44',
      buildNumber: 44,
      title: 'Исправлены ошибки и замечания flutter analyze в релизе 2.1.43',
      summary: 'Исправлены модификаторы методов расширения в build_bundle_service.dart, объявления полей и структура Column в build_capture_tab.dart, а также удалён неиспользуемый импорт в home_screen.dart.',
      changes: [
        'Оформлены вспомогательные методы BuildBundleService в расширение без лишнего static и удалён неиспользуемый _clearDirectory',
        'Добавлены поля _buildAutoLaunchExe и _buildHistoryKeepCount и исправлена структура Column для журнала распаковки в build_capture_tab.dart',
        'Удалён неиспользуемый импорт agent_template_item.dart в home_screen.dart',
      ],
    ),
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
  ];
}
