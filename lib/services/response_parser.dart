import '../models/generated_file.dart';

class ResponseParseResult {
  const ResponseParseResult({
    required this.files,
    required this.format,
    this.warnings = const <String>[],
  });

  final List<GeneratedFile> files;
  final String format;
  final List<String> warnings;
}

/// Универсальный импортёр ответов ИИ.
/// Поддерживает маркеры CodeBridge и Markdown-ответы с заголовками/код-блоками.
class ResponseParser {
  static const _extensions =
      r'dart|yaml|yml|json|md|xml|gradle|kts|properties|kt|java|swift|plist|html|css|js|ts|tsx|jsx|c|cc|cpp|h|hpp|cmake|txt|toml|lock|sh|ps1|bat|rc|manifest|sql|py|go|rs|example';

  static List<GeneratedFile> parse(String source) => parseDetailed(source).files;

  static ResponseParseResult parseDetailed(String source) {
    final normalized = source
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final ignored = List<bool>.filled(lines.length, false);
    final files = <GeneratedFile>[];
    final warnings = <String>[];

    _parseExplicitBlocks(lines, ignored, files);
    _parseMarkdownBlocks(lines, ignored, files, warnings);

    if (files.isEmpty) {
      throw FormatException(
        'Не удалось определить файлы. Поддерживаются <<<FILE: путь>>>, '
        'Markdown-заголовки с путями и строки «Файл: путь» перед блоками кода. '
        'В ответе найдены блоки кода: ${_countFences(lines)}.',
      );
    }

    final unique = <String, GeneratedFile>{};
    for (final file in files) {
      final key = file.path.toLowerCase();
      final previous = unique[key];
      if (previous == null) {
        unique[key] = file;
      } else if (previous.content.trimRight() == file.content.trimRight()) {
        warnings.add('Повторяющийся одинаковый блок ${file.path} пропущен.');
      } else {
        throw FormatException(
          'В ответе найдено несколько разных версий файла "${file.path}". '
          'Оставь одну версию или попроси ИИ выдать итоговый файл один раз.',
        );
      }
    }

    // Сохраняем порядок файлов в ответе ИИ: он важен для предсказуемого
    // отображения результата и не должен меняться из-за алфавитной сортировки.
    final resultFiles = unique.values.toList(growable: false);
    final formats = resultFiles.map((file) => file.sourceFormat).toSet();
    final format = formats.length > 1
        ? 'mixed'
        : (formats.isEmpty ? 'markdown' : formats.first);
    return ResponseParseResult(files: resultFiles, format: format, warnings: warnings);
  }

  static void _parseExplicitBlocks(
    List<String> lines,
    List<bool> ignored,
    List<GeneratedFile> files,
  ) {
    var index = 0;
    while (index < lines.length) {
      final line = lines[index].trim();
      if (line == '<<<END_PROJECT>>>') {
        for (var i = index; i < lines.length; i++) {
          ignored[i] = true;
        }
        break;
      }
      if (!line.startsWith('<<<FILE:') || !line.endsWith('>>>')) {
        index++;
        continue;
      }

      final relativePath = line.substring('<<<FILE:'.length, line.length - 3).trim();
      if (relativePath.isEmpty) {
        throw const FormatException('Найден маркер FILE без имени файла.');
      }
      final contentLines = <String>[];
      final start = index;
      index++;
      var foundEnd = false;
      while (index < lines.length) {
        final contentLine = lines[index];
        if (contentLine.trim() == '<<<END>>>') {
          foundEnd = true;
          ignored[index] = true;
          break;
        }
        if (contentLine.trim().startsWith('<<<FILE:') ||
            contentLine.trim() == '<<<END_PROJECT>>>') {
          throw FormatException('Файл "$relativePath" не закрыт маркером <<<END>>>.');
        }
        contentLines.add(contentLine);
        ignored[index] = true;
        index++;
      }
      if (!foundEnd) {
        throw FormatException('В ответе нет маркера <<<END>>> для файла "$relativePath".');
      }
      for (var i = start; i <= index; i++) {
        ignored[i] = true;
      }
      final path = _normalizePath(relativePath);
      files.add(GeneratedFile(
        path: path,
        content: _normalizeContent(contentLines.join('\n')),
        sourceFormat: 'markers',
      ));
      index++;
    }
  }

  static void _parseMarkdownBlocks(
    List<String> lines,
    List<bool> ignored,
    List<GeneratedFile> files,
    List<String> warnings,
  ) {
    String? candidatePath;
    final context = <String>[];
    var blocksWithoutPath = 0;
    var index = 0;

    while (index < lines.length) {
      if (ignored[index]) {
        index++;
        continue;
      }

      final line = lines[index];
      final trimmed = line.trim();
      final fence = _readFence(trimmed);
      if (fence != null) {
        final contentLines = <String>[];
        final blockStart = index;
        index++;
        var closed = false;
        while (index < lines.length) {
          if (_isFenceClose(lines[index].trim(), fence)) {
            closed = true;
            break;
          }
          contentLines.add(lines[index]);
          index++;
        }
        if (!closed) {
          warnings.add('Найден незакрытый блок кода около строки ${blockStart + 1}; пропущен.');
          break;
        }

        final language = fence.language.toLowerCase();
        if (_isCommandLanguage(language)) {
          // Команды терминала не являются файлами, но контекст заголовка сохраняем:
          // после блока bash часто идёт YAML-конфигурация того же шага.
        } else if (candidatePath != null) {
          final content = _normalizeContent(contentLines.join('\n'));
          final isFragment = _looksLikeFragment(candidatePath, content, context.join('\n'));
          files.add(GeneratedFile(
            path: _normalizePath(candidatePath),
            content: content,
            isFragment: isFragment,
            selected: !isFragment,
            sourceFormat: 'markdown',
            note: isFragment
                ? 'Похоже на фрагмент конфигурации. Не будет записан как полный файл без проверки.'
                : null,
          ));
          candidatePath = null;
          context.clear();
        } else {
          blocksWithoutPath++;
        }
        index++;
        continue;
      }

      if (trimmed.startsWith('#')) {
        final headingPath = _extractPath(trimmed);
        if (headingPath != null) {
          candidatePath = headingPath;
          context
            ..clear()
            ..add(trimmed);
        } else {
          candidatePath = null;
          context.clear();
        }
        index++;
        continue;
      }

      final detectedPath = _extractPath(trimmed);
      if (detectedPath != null && _isFileCue(trimmed)) {
        // Если путь уже задан заголовком (например, `Код приложения
        // (`lib/main.dart`)`), последующая инструкция «замени main.dart»
        // не должна обрезать каталог и превращать его в `main.dart`.
        // Новый путь принимаем только когда ожидаем файл; после блока
        // candidatePath сбрасывается и следующий файл определяется отдельно.
        if (candidatePath == null) {
          candidatePath = detectedPath;
          context
            ..clear()
            ..add(trimmed);
        } else {
          context.add(trimmed);
          if (context.length > 8) context.removeAt(0);
        }
      } else if (candidatePath != null && trimmed.isNotEmpty) {
        context.add(trimmed);
        if (context.length > 8) context.removeAt(0);
      }
      index++;
    }

    if (blocksWithoutPath > 0) {
      warnings.add(
        'Пропущено блоков кода без однозначного имени файла: $blocksWithoutPath. '
        'Добавь перед каждым блоком заголовок с путём, например «Файл: lib/main.dart».',
      );
    }
  }

  static String? _extractPath(String text) {
    final expression = RegExp(
      '((?:[A-Za-z0-9_.@+-]+[/\\\\])*[A-Za-z0-9_.@+-]+\\.($_extensions))',
      caseSensitive: false,
    );
    final match = expression.firstMatch(text);
    if (match == null) return null;
    var value = match.group(1)!.replaceAll('\\', '/');
    value = value.replaceAll(RegExp(r'^[`*_({\[]+'), '').replaceAll(RegExp(r'[`*_}),\].:;]+$'), '');
    if (value.isEmpty || value.startsWith('/') || RegExp(r'^[a-zA-Z]:').hasMatch(value)) return null;
    if (value.split('/').any((part) => part == '..' || part == '.')) return null;
    return value;
  }

  static bool _isFileCue(String line) {
    final lower = line.toLowerCase();
    final hasCue = RegExp(
      r'(файл|file|код приложения|содержим|замени|создай|добав|встав|зависимост|package|код файла|полностью|source code)',
      caseSensitive: false,
    ).hasMatch(lower);
    return hasCue || lower.contains('`');
  }

  static bool _looksLikeFragment(String path, String content, String context) {
    final lowerContext = context.toLowerCase();
    final fullFileCue = RegExp(
      r'(полностью|полный файл|содержимое файла|полное содержимое|замени содержимое|замени на этот код|создай файл|complete file|full file|full contents|replace the contents)',
      caseSensitive: false,
    ).hasMatch(lowerContext);
    if (fullFileCue) return false;

    final lowerPath = path.toLowerCase();
    final trimmed = content.trimLeft();
    final pubspecDependencyFragment =
        (lowerPath == 'pubspec.yaml' || lowerPath == 'pubspec.yml') &&
        RegExp(r'^(dependencies|dev_dependencies|dependency_overrides):\s*(#.*)?$', multiLine: false)
            .hasMatch(trimmed.split('\n').first.trim());
    final fragmentCue = RegExp(
      r'(добав(ь|ить)|добав(ьте|ьте)|встав(ь|ить)|фрагмент|snippet|append|add (the )?(package|dependency|dependencies)|update (the )?(dependencies|section)|зависимост)',
      caseSensitive: false,
    ).hasMatch(lowerContext);
    return pubspecDependencyFragment || fragmentCue;
  }

  static String _normalizePath(String value) {
    final path = value.trim().replaceAll('\\', '/');
    if (path.isEmpty || path.startsWith('/') || RegExp(r'^[a-zA-Z]:').hasMatch(path)) {
      throw FormatException('Путь должен быть относительным: "$value".');
    }
    if (path.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Недопустимый относительный путь: "$value".');
    }
    return path;
  }

  static String _normalizeContent(String content) {
    var result = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst('\uFEFF', '');
    if (result.isNotEmpty && !result.endsWith('\n')) result += '\n';
    return result;
  }

  static bool _isCommandLanguage(String language) => const {
        'bash', 'sh', 'shell', 'powershell', 'pwsh', 'ps1', 'cmd', 'bat',
        'console', 'terminal', 'output',
      }.contains(language);

  static _Fence? _readFence(String line) {
    final match = RegExp(r'^(`{3,}|~{3,})\s*([A-Za-z0-9_+.-]*)').firstMatch(line);
    if (match == null) return null;
    return _Fence(match.group(1)![0], match.group(1)!.length, match.group(2) ?? '');
  }

  static bool _isFenceClose(String line, _Fence fence) {
    final marker = RegExp.escape(fence.character);
    final match = RegExp('^$marker{${fence.length},}\\s*\$').firstMatch(line);
    return match != null;
  }

  static int _countFences(List<String> lines) => lines.where((line) => _readFence(line.trim()) != null).length;
}

class _Fence {
  const _Fence(this.character, this.length, this.language);

  final String character;
  final int length;
  final String language;
}
