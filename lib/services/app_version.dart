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
  static const String currentVersion = '2.1.65';
  static const int currentBuildNumber = 65;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.65',
      buildNumber: 65,
      title: 'Исправлен ввод текста и фокус полей во вкладке «Заметки»',
      summary: 'В редактор заметок и поле создания папки добавлены явные FocusNode, корректная передача фокуса при клике и создании заметки, а также устранены лишние перерисовки при наборе текста.',
      changes: [
        'Добавлены явные FocusNode и обработка фокуса для полей заголовка, текста заметки и имени новой папки в ProjectNotesTab',
        'Убраны лишние setState при каждом нажатии клавиши в редакторе заметки, чтобы не сбрасывался фокус и ввод текста',
        'Обновлена версия до 2.1.65+65 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.64',
      buildNumber: 64,
      title: 'Полностью удалена интерполяция branch из app_version.dart',
      summary: 'Удалены все упоминания интерполяции branch в lib/services/app_version.dart для прохождения flutter analyze.',
      changes: [
        'Заменены все вхождения branch на обычный текст branch в lib/services/app_version.dart',
        'Обновлена версия до 2.1.64+64 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.63',
      buildNumber: 63,
      title: 'Исправлена константная строка в истории релизов app_version.dart',
      summary: 'В константном списке ReleaseEntry в lib/services/app_version.dart заменена интерполяция branch на обычный текст [branch].',
      changes: [
        'Заменено [branch] на [branch] в константном списке history в lib/services/app_version.dart',
        'Обновлена версия до 2.1.63+63 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.62',
      buildNumber: 62,
      title: 'Убраны лишние фигурные скобки в строковой интерполяции github_build_fetcher_service.dart',
      summary: 'Исправлено замечание анализатора unnecessary_brace_in_string_interps на строке 43 в lib/services/github_build_fetcher_service.dart.',
      changes: [
        'Заменено [branch] на [branch] в lib/services/github_build_fetcher_service.dart',
        'Обновлена версия до 2.1.62+62 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.61',
      buildNumber: 61,
      title: 'Оповещение об упавшей сборке GitHub в статусе, журнале и баннере',
      summary: 'При проверке сборок с GitHub программа отслеживает статус последнего завершённого workflow run и при ошибке сборки выводит красный баннер, подсвечивает строку статуса и записывает ошибку в журнал распаковки.',
      changes: [
        'В GitHubBuildFetcherService добавлено определение упавших workflow runs (failure, cancelled, timed_out и др.) с номером run, веткой и коммитом',
        'Добавлены красный баннер с кнопкой скрытия, подсветка статуса «Последняя проверка GitHub» и запись [ОШИБКА СБОРКИ GITHUB] в журнал распаковки',
        'Обновлена версия до 2.1.61+61 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.60',
      buildNumber: 60,
      title: 'Добавлено поле currentProjectNotes в ProjectProvider для вкладки «Заметки»',
      summary: 'Исправлена ошибка анализатора undefined_identifier/undefined_getter: в ProjectProvider объявлено поле currentProjectNotes для хранения заметок и папок активного проекта.',
      changes: [
        'Добавлено поле ProjectNotesStore currentProjectNotes = const ProjectNotesStore() в lib/providers/project_provider.dart',
        'Обновлена версия до 2.1.60+60 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.59',
      buildNumber: 59,
      title: 'Вкладка «Заметки» с папками и заметками для багов с привязкой к проекту',
      summary: 'Добавлена новая вкладка «Заметки» для каждого проекта с созданием папок, заметок, быстрым шаблоном записи бага и сохранением в data/projects/<id>/notes.json.',
      changes: [
        'Добавлена модель ProjectNotesStore / ProjectNoteFolder / ProjectNoteItem и сохранение заметок строго внутри каталога выбранного проекта (notes.json)',
        'Добавлена вкладка «Заметки» (ProjectNotesTab) с папками, поиском, быстрой кнопкой «Записать баг» и встроенным редактором заметок',
        'Обновлена версия до 2.1.59+59 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.58',
      buildNumber: 58,
      title: 'Сохранение развёрнутого состояния окна после сворачивания и разворачивания',
      summary: 'При сворачивании окна, развёрнутого на весь экран, запоминается его состояние максимизации/полного экрана, и при возврате из панели задач или трея окно снова открывается на весь экран.',
      changes: [
        'В MacOsWindowTitleBar добавлено запоминание состояния максимизации/полного экрана перед сворачиванием и автоматическое восстановление при возврате окна',
        'В WindowSizeListener и AppTrayService защищено сохранение флагов windowIsMaximized/windowIsFullScreen при сворачивании окна',
        'Обновлена версия до 2.1.58+58 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
  ];
}
