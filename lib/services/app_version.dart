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
  static const String currentVersion = '2.1.57';
  static const int currentBuildNumber = 57;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.57',
      buildNumber: 57,
      title: 'Удалён неиспользуемый импорт dart:convert в build_bundle_service.dart',
      summary: 'Устранено предупреждение unused_import (dart:convert) в lib/services/build_bundle_service.dart для прохождения flutter analyze.',
      changes: [
        'Удалён неиспользуемый импорт dart:convert в lib/services/build_bundle_service.dart',
        'Обновлена версия до 2.1.57+57 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.56',
      buildNumber: 56,
      title: 'Отображение скачанной/распакованной версии и иконка приложения в панели задач Windows',
      summary: 'При скачивании и распаковке сборки определяется и отображается её версия в статусе и журнале, а в исполняемый файл и окно Windows встроена иконка приложения для панели задач.',
      changes: [
        'Добавлено определение версии скачанной и распакованной сборки и её вывод в сводке «Последняя проверка GitHub» и журнале распаковки',
        'Встроена иконка IDI_APP_ICON в Runner.rc, win32_window.cpp (WM_SETICON) и windowManager.setIcon для отображения значка в панели задач Windows',
        'Обновлена версия до 2.1.56+56 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.55',
      buildNumber: 55,
      title: 'Исправлена инициализация и copyWith для logRetentionDays в AppSettings',
      summary: 'В класс AppSettings добавлены инициализация по умолчанию (30 дней), именованный параметр copyWith и сериализация JSON для поля logRetentionDays.',
      changes: [
        'Добавлен параметр this.logRetentionDays = 30 в конструктор AppSettings',
        'Добавлен именованный параметр int? logRetentionDays в AppSettings.copyWith и сериализация toJson/fromJson',
        'Обновлена версия до 2.1.55+55 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.54',
      buildNumber: 54,
      title: 'Сохранение истории журналов на диск, очистка и лимит хранения (30 дней по умолчанию)',
      summary: 'Журналы авто-деплоя и распаковки сборок сохраняются в data/logs/, поддерживают удаление истории и настройку срока хранения (7 / 30 / 90 дней или без ограничения).',
      changes: [
        'Добавлено сохранение и автоматическая очистка старых записей журналов в AppStorage (data/logs/) с лимитом 30 дней по умолчанию',
        'Добавлены выбор срока хранения и удаление истории журналов в авто-деплое и распаковке сборок',
        'Обновлена версия до 2.1.54+54 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.53',
      buildNumber: 53,
      title: 'Встроенный редактор шаблонов прямо во вкладке «Инструкция» без всплывающих окон',
      summary: 'Управление шаблонами и создание нового шаблона перенесены прямо внутрь основной вкладки «Инструкция» (без Dialog и отдельного маршрута Navigator), где гарантированно работает ввод с клавиатуры.',
      changes: [
        'Перенесено управление и создание шаблонов прямо внутрь вкладки «Инструкция» (без модального окна и отдельного маршрута Navigator)',
        'Добавлена кнопка «Новый шаблон» прямо на панель вкладки «Инструкция» и внутрь редактора шаблонов',
        'Обновлена версия до 2.1.53+53 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.52',
      buildNumber: 52,
      title: 'Уведомления о сохранении/ошибках и отключение автоподсказок в редакторе шаблонов',
      summary: 'В экран библиотеки шаблонов добавлены SnackBar-уведомления при сохранении и ошибках записи, а также отключены автоподсказки/автокоррекция в полях ввода.',
      changes: [
        'Добавлены SnackBar-уведомления при успешном сохранении и при ошибке сохранения шаблона',
        'Отключены autocorrect и enableSuggestions в полях названия и текста шаблона',
        'Обновлена версия до 2.1.52+52 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.51',
      buildNumber: 51,
      title: 'Полноэкранный редактор библиотеки шаблонов с рабочим вводом текста',
      summary: 'Библиотека шаблонов AGENT.md открывается как полноценный экран Scaffold (MaterialPageRoute) без модального Dialog-слоя, который блокировал ввод текста на Windows.',
      changes: [
        'Переведена библиотека шаблонов из модального Dialog на полноценный Scaffold-экран (TemplateManagerScreen)',
        'Убран ручной перехват фокуса в onTap у TextField, чтобы ввод текста, курсор и выделение работали так же, как в основном редакторе инструкции',
        'Обновлена версия до 2.1.51+51 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.50',
      buildNumber: 50,
      title: 'Поле ввода GitHub Token во вкладке «Распаковка сборок»',
      summary: 'Добавлено поле GitHub Token с показом/скрытием и автоматическим сохранением в AppSettings прямо во вкладке «Распаковка сборок» для скачивания артефактов GitHub Actions.',
      changes: [
        'Добавлено поле ввода GitHub Token (_tokenController) с кнопкой показа/скрытия во вкладке BuildCaptureTab',
        'Токен сохраняется в AppSettings при сохранении настроек сборки и перед ручной проверкой сборок на GitHub',
        'Обновлена версия до 2.1.50+50 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
  ];
}
