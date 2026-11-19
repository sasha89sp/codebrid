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
  static const String currentVersion = '2.1.54';
  static const int currentBuildNumber = 54;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
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
    ReleaseEntry(
      version: '2.1.49',
      buildNumber: 49,
      title: 'Исправлен ввод текста и клавиатурный фокус в диалогах на Windows',
      summary: 'Переведён безрамочный заголовок окна на штатный TitleBarStyle.hidden в window_manager без перехвата WM_NCCALCSIZE/WM_NCHITTEST в flutter_window.cpp, восстановив нормальный ввод с клавиатуры в полях диалогов и редакторе шаблонов.',
      changes: [
        'Убран низкоуровневый перехват WM_NCCALCSIZE/WM_NCHITTEST в windows/runner/flutter_window.cpp, ломавший клавиатурный фокус в диалогах Windows',
        'Включён TitleBarStyle.hidden и управление окном через window_manager в MacOsWindowTitleBar',
        'Улучшено получение фокуса в полях названия и текста в TemplateManagerDialog и обновлена версия до 2.1.49+49',
      ],
    ),
    ReleaseEntry(
      version: '2.1.48',
      buildNumber: 48,
      title: 'Кнопки окна перенесены вправо в порядке Windows',
      summary: 'В MacOsWindowTitleBar кнопки управления окном перенесены в правый угол и расположены слева направо в порядке Windows: свернуть, развернуть/восстановить, закрыть.',
      changes: [
        'Перенесён блок кнопок управления окном в правую часть MacOsWindowTitleBar',
        'Установлен порядок кнопок как на Windows: жёлтая (свернуть), зелёная (развернуть/восстановить), красная (закрыть)',
        'Обновлена версия до 2.1.48+48 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.47',
      buildNumber: 47,
      title: 'Исправлен вызов withValues на Color для совместимости с Flutter 3.24',
      summary: 'В виджете MacOsWindowTitleBar заменён вызов .withValues(alpha: 0.78) на .withOpacity(0.78), поддерживаемый в Flutter 3.24.5.',
      changes: [
        'Заменён .withValues(alpha: 0.78) на .withOpacity(0.78) в lib/widgets/macos_window_title_bar.dart',
        'Обновлена версия до 2.1.47+47 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
  ];
}
