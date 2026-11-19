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
  static const String currentVersion = '2.1.49';
  static const int currentBuildNumber = 49;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
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
    ReleaseEntry(
      version: '2.1.46',
      buildNumber: 46,
      title: 'Исправлен вызов методов из static applyDownloadedBuild в BuildBundleService',
      summary: 'Вспомогательные методы _clearDirectorySafe, _copyDirectoryContentsSafe, _pruneHistory и _launchNewestExeIfAny возвращены в класс BuildBundleService с модификатором static.',
      changes: [
        'Возвращены _clearDirectorySafe, _copyDirectoryContentsSafe, _pruneHistory и _launchNewestExeIfAny в BuildBundleService как static-методы',
        'Устранена ошибка instance_member_access_from_static при вызове из applyDownloadedBuild',
        'Обновлена версия до 2.1.46+46 в AppVersion, pubspec.yaml, CHANGELOG.md и HANDOFF.yaml',
      ],
    ),
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
  ];
}
