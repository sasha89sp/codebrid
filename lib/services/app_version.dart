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
  static const String currentVersion = '2.1.69';
  static const int currentBuildNumber = 69;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.69',
      buildNumber: 69,
      title: 'Единый журнал событий, закреплённый снизу с выводом новых записей сверху',
      summary: 'Журнал авто-деплоя и журнал распаковки сборок объединены в одну закреплённую нижнюю панель под рабочей областью вкладок, где самые свежие записи отображаются сверху, а старые уходят вниз.',
      changes: [
        'Объединены каналы журналов авто-деплоя и распаковки сборок в единый поток activityLogs (новые записи добавляются сверху, старые уходят вниз, сохранение в unified_history.json с миграцией старых логов)',
        'Добавлена закреплённая нижняя панель «Журнал событий» в рабочем экране с баннером ошибок GitHub, статусом проверки, выбором срока хранения, очисткой и сворачиванием',
        'Убраны дублирующиеся отдельные блоки журналов со вкладок «Авто-деплой» и «Распаковка сборок»',
        'Обновлена версия до 2.1.69+69 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.68',
      buildNumber: 68,
      title: 'Кнопка «Запустить .exe» в шапке проекта для быстрого запуска текущей сборки',
      summary: 'Рядом с кнопками «Открыть папку» и «Открыть сборку» добавлена третья кнопка «Запустить .exe», которая находит и запускает исполняемый файл проекта в папке текущей сборки.',
      changes: [
        'Добавлен метод BuildBundleService.launchBuildExe для поиска и запуска .exe в папке текущей сборки (исключая служебные файлы и отдавая приоритет файлу проекта и самому свежему .exe)',
        'Добавлена кнопка «Запустить .exe» в шапке проекта рядом с «Открыть папку» и «Открыть сборку»',
        'Обновлена версия до 2.1.68+68 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.67',
      buildNumber: 67,
      title: 'Перемещение проектов, удаление в корзину и раздел Корзина в «Моих проектах»',
      summary: 'В боковой панели «Мои проекты» добавлены перемещение проектов (перетаскиванием и кнопками вверх/вниз), удаление в корзину и раздел Корзины с восстановлением и окончательным удалением.',
      changes: [
        'Добавлены перемещение проектов с сохранением порядка в settings.json и отправка проектов в корзину без потери данных',
        'Добавлен переключатель «Корзина (N)» с восстановлением проекта, удалением навсегда и очисткой корзины',
        'Обновлена версия до 2.1.67+67 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.66',
      buildNumber: 66,
      title: 'Разделены опции копирования и перемещения ZIP-архива в папку версий после push',
      summary: 'В настройках авто-деплоя появились две отдельные включаемые/выключаемые опции: копирование ZIP в папку версий (исходный файл остаётся) и перемещение ZIP в папку версий (исходный файл удаляется в изначальной папке).',
      changes: [
        'Переименована опция сохранения в папку версий в «Автоматически копировать ZIP-архив после успешного push в папку версий (сохраняя все версии, исходный файл остаётся)»',
        'Добавлена отдельная опция «Автоматически перемещать ZIP-архив после успешного push в папку версий (удаляет исходный файл в изначальной папке)»',
        'Обновлена версия до 2.1.66+66 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
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
  ];
}
