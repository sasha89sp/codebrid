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
  static const String currentVersion = '2.1.27';
  static const int currentBuildNumber = 27;
  static const String fullVersion = '$currentVersion+$currentBuildNumber';

  static const List<ReleaseEntry> history = <ReleaseEntry>[
    ReleaseEntry(
      version: '2.1.27',
      buildNumber: 27,
      title: 'Удалён несуществующий параметр errorCode в GitHubRepoProvisionResult',
      summary: 'Убран лишний именованный аргумент errorCode: null при ошибке git init в lib/services/github_repo_service.dart.',
      changes: [
        'Удалён errorCode: null из вызова конструктора GitHubRepoProvisionResult в attachExistingRepository',
      ],
    ),
    ReleaseEntry(
      version: '2.1.26',
      buildNumber: 26,
      title: 'Исправлена синтаксическая ошибка в CodeProject.fromJson',
      summary: 'Убран преждевременный закрывающий ); на строке 176 в lib/models/code_project.dart, из-за которого поля buildCapture* воспринимались как метки.',
      changes: [
        'Удалён лишний ); после zipArchiveFolder в CodeProject.fromJson (lib/models/code_project.dart)',
      ],
    ),
    ReleaseEntry(
      version: '2.1.25',
      buildNumber: 25,
      title: 'Режим подключения готового репозитория при создании проекта',
      summary: 'В диалоге создания проекта добавлен выбор между созданием нового проекта с нуля и подключением готового репозитория по URL.',
      changes: [
        'Добавлен метод GitHubRepoService.attachExistingRepository: git clone при пустой/отсутствующей папке или привязка origin и проверка статуса Git в существующей папке',
        'Добавлена защита от перезаписи существующих README.md, .gitignore и AGENTS.md без явного разрешения и автозаполнение авто-деплоя',
      ],
    ),
    ReleaseEntry(
      version: '2.1.24',
      buildNumber: 24,
      title: 'Сохранена прежняя опция удаления ZIP + добавлена опция автопереноса в папку версий',
      summary: 'Во вкладке «Авто-деплой» оставлена прежняя опция удаления исходного ZIP и добавлена отдельная опция автопереноса в папку версий проекта.',
      changes: [
        'Возвращён отдельный чекбокс удаления исходного ZIP после успешного push без перезаписи при сохранении настроек',
        'Добавлена новая опция автоматического переноса/сохранения всех версий ZIP в папку проекта (_zip_versions или выбранный каталог)',
      ],
    ),
    ReleaseEntry(
      version: '2.1.23',
      buildNumber: 23,
      title: 'Автоперенос ZIP-архива после push в папку версий проекта',
      summary: 'Вместо удаления ZIP-архив переносится в папку версий проекта (_zip_versions или выбранную папку) с сохранением всех версий.',
      changes: [
        'Добавлены moveZipAfterPush (включено по умолчанию) и zipArchiveFolder в CodeProject, ProjectProvider и AutoDeployTab',
        'При совпадении имени файла в папке версий добавляется метка времени, чтобы предыдущие версии архивов не перезаписывались',
      ],
    ),
    ReleaseEntry(
      version: '2.1.22',
      buildNumber: 22,
      title: 'Удалены лишние const внутри const Row в lib/screens/home_screen.dart',
      summary: 'Исправлены предупреждения unnecessary_const на строках 1896 и 1897 в диалоге «О программе».',
      changes: [
        'Убран лишний const перед Icon и SizedBox внутри const Row в _showAboutDialog',
      ],
    ),
    ReleaseEntry(
      version: '2.1.21',
      buildNumber: 21,
      title: 'Устранены подсказки prefer_const в диалоге «О программе»',
      summary: 'Перенесён модификатор const на уровень Row и Text в _showAboutDialog в lib/screens/home_screen.dart.',
      changes: [
        'Исправлены подсказки prefer_const_constructors и prefer_const_literals_to_create_immutables в lib/screens/home_screen.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.20',
      buildNumber: 20,
      title: 'Исправлена ошибка типа String? в _findProject и подсказки prefer_const',
      summary: 'Приведён аргумент для _findProject к не-nullable String и устранены подсказки анализатора в home_screen.dart.',
      changes: [
        'Исправлен вызов _findProject(currentProject!.id) при наличии currentProject?.id в project_provider.dart',
        'Убраны оставшиеся подсказки prefer_const в диалоге «О программе» в home_screen.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.19',
      buildNumber: 19,
      title: 'Исправлены ошибки и замечания flutter analyze в Build portable Windows x64',
      summary: 'Устранены дублирующий импорт, неопределённый идентификатор AgentTemplate и подсказки prefer_const.',
      changes: [
        'Удалён дублирующий импорт dart:io и добавлен импорт agent_template.dart в project_provider.dart',
        'Исправлены замечания prefer_const в lib/screens/home_screen.dart',
      ],
    ),
    ReleaseEntry(
      version: '2.1.18',
      buildNumber: 18,
      title: 'Исправлен отсев вкладки «Распаковка сборок» при загрузке настроек',
      summary: 'В ProjectProvider при нормализации порядка вкладок из settings.json добавлен идентификатор build_capture.',
      changes: [
        'В список allowed при загрузке settings.json добавлен build_capture, чтобы вкладка «Распаковка сборок» не вырезалась при запуске',
      ],
    ),
    ReleaseEntry(
      version: '2.1.17',
      buildNumber: 17,
      title: 'Бэкап и автобэкап настроек, шаблонов, проектов и наработок',
      summary: 'Добавлено сохранение всех настроек, проектов и наработок в ZIP-архивы с ручным бэкапом, восстановлением и автобэкапом по расписанию.',
      changes: [
        'Создан BackupService для архивирования data/ (настройки, проекты, шаблоны) и папок проектов с ротацией архивов и восстановлением',
        'Добавлены автобэкап по интервалу, выбор папки бэкапов и кнопки «Сделать бэкап», «Восстановить» и «Папка бэкапов» в разделе «О программе»',
      ],
    ),
    ReleaseEntry(
      version: '2.1.16',
      buildNumber: 16,
      title: 'Единый номер версии и раздел «О программе» с историей изменений',
      summary: 'Версия 2.1.16 подтягивается в интерфейс из единого источника и добавлен диалог «О программе» с журналом версий.',
      changes: [
        'Единый номер версии 2.1.16+16 в AppVersion, pubspec.yaml, шапке приложения и диалоге «О программе»',
        'Добавлен раздел «О программе» с историей всех изменений по версиям и быстрым открытием папки данных',
      ],
    ),
    ReleaseEntry(
      version: '2.1.15',
      buildNumber: 15,
      title: 'Автозаполнение настроек авто-деплоя при создании проекта',
      summary: 'При создании проекта автоматически задаются авто-деплой, фильтр ZIP, ветка и автосинхронизация.',
      changes: [
        'Автоматическое заполнение autoDeployEnabled, zipNameFilter, gitBranch и autoSyncOnReject при создании проекта',
        'Автоматическое включение мониторинга «Загрузок» при активном авто-деплое и добавление опций в диалог создания',
      ],
    ),
    ReleaseEntry(
      version: '2.1.14',
      buildNumber: 14,
      title: 'Автосоздание репозитория на GitHub и базовых файлов проекта',
      summary: 'При создании проекта можно создать приватный или публичный репозиторий и стартовые файлы.',
      changes: [
        'Добавлен GitHubRepoService (GitHub API и gh CLI) для создания приватных и публичных репозиториев',
        'Генерация стартовых файлов (README.md, .gitignore, AGENTS.md) и сохранение GitHub owner/token в settings.json',
      ],
    ),
    ReleaseEntry(
      version: '2.1.13',
      buildNumber: 13,
      title: 'Подключение вкладки «Распаковка сборок»',
      summary: 'Вкладка «Распаковка сборок» подключена во всех переключателях рабочего пространства.',
      changes: [
        'Добавлен case build_capture в _iconForTab, _labelForTab и _bodyForTab в home_screen.dart',
        'Обновлён номер сборки в pubspec.yaml',
      ],
    ),
    ReleaseEntry(
      version: '2.1.12',
      buildNumber: 12,
      title: 'Исправление дубля _openFolder',
      summary: 'Удалено дублирующееся определение _openFolder в lib/screens/home_screen.dart.',
      changes: [
        'Оставлено единое определение _openFolder для открытия папок проекта, сборок и файлов',
      ],
    ),
    ReleaseEntry(
      version: '2.1.11',
      buildNumber: 11,
      title: 'Исправление замечаний flutter analyze',
      summary: 'Убраны предупреждения анализатора перед сборкой portable Windows x64.',
      changes: [
        'Удалён неиспользуемый импорт в home_screen.dart и неиспользуемое поле в auto_deploy_tab.dart',
        'Упорядочены проверки mounted и context.mounted в _saveManualAgent',
      ],
    ),
    ReleaseEntry(
      version: '2.1.10',
      buildNumber: 10,
      title: 'Кнопка «Открыть сборку»',
      summary: 'Рядом с «Открыть папку» добавлена кнопка открытия актуальной папки готовой сборки (current).',
      changes: [
        'Добавлен метод BuildBundleService.currentBuildDirectory и отслеживание lastBuildArchiveName',
      ],
    ),
    ReleaseEntry(
      version: '2.1.9',
      buildNumber: 9,
      title: 'Отдельная вкладка «Распаковка сборок»',
      summary: 'Логика работы с готовыми сборками после компиляции вынесена в BuildCaptureTab.',
      changes: [
        'Создан виджет BuildCaptureTab и добавлена вкладка «Распаковка сборок» с поддержкой перестановки',
      ],
    ),
    ReleaseEntry(
      version: '2.1.8',
      buildNumber: 8,
      title: 'Восстановление функций из параллельных веток',
      summary: 'Объединены авто-синхронизация при отказе push, ручное редактирование AGENT.md и переименование проекта.',
      changes: [
        'Восстановлены autoSyncOnReject, сохранение правок agent.md и диалог переименования проекта',
      ],
    ),
    ReleaseEntry(
      version: '2.1.7',
      buildNumber: 7,
      title: 'Оверлей старой версии и очистка перед сборкой',
      summary: 'Добавлены настройки сохранения оверлея старой версии и очистки перед применением нового архива.',
      changes: [
        'Добавлены параметры overlayPreviousVersion и clearTargetBeforeApply в BuildBundleService и UI',
      ],
    ),
    ReleaseEntry(
      version: '2.1.6',
      buildNumber: 6,
      title: 'Очистка замечаний анализатора в Main Validation',
      summary: 'Исправлены prefer_interpolation_to_compose_strings и unused_field.',
      changes: [
        'Обновлена интерполяция регулярного выражения и удалено лишнее поле',
      ],
    ),
    ReleaseEntry(
      version: '2.1.5',
      buildNumber: 5,
      title: 'Режим «брать все» для публичных сборок',
      summary: 'Публичные сборки по умолчанию принимаются без отсева по фильтру имени архива.',
      changes: [
        'Добавлен флаг buildTakeAllPublicBuilds со значением true по умолчанию',
      ],
    ),
    ReleaseEntry(
      version: '2.1.4',
      buildNumber: 4,
      title: 'Исправление ошибок компиляции и анализа',
      summary: 'Исправлены ошибки в build_bundle_service.dart, app_storage.dart, project_provider.dart и auto_deploy_tab.dart.',
      changes: [
        'Добавлен AppStorage.saveTabOrder, исправлено регулярное выражение и объявления полей',
      ],
    ),
    ReleaseEntry(
      version: '2.1.3',
      buildNumber: 3,
      title: 'Кнопка «Открыть папку» и перестановка вкладок',
      summary: 'Добавлены перетаскивание/перемещение вкладок с сохранением порядка в settings.json и кнопка папки.',
      changes: [
        'Добавлены AppSettings.tabOrder, reorderTabs и перетаскивание/стрелки на панели вкладок',
      ],
    ),
  ];
}
