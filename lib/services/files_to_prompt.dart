import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class FilesToPromptResult {
  const FilesToPromptResult({required this.text, required this.included, required this.skipped});

  final String text;
  final int included;
  final List<String> skipped;
}

class FilesToPrompt {
  static const int maxFileBytes = 2 * 1024 * 1024;
  static const int maxTotalBytes = 12 * 1024 * 1024;
  static const int maxFiles = 1200;
  static const Set<String> _ignoredDirectories = {
    '.git', '.dart_tool', '.idea', '.vscode', 'build', 'node_modules',
    '.gradle', '.next', 'dist', 'coverage', 'ephemeral',
  };
  static const Set<String> _ignoredFileSuffixes = {
    '.g.dart', '.freezed.dart', '.gr.dart',
  };

  static Future<FilesToPromptResult> fromFiles(List<String> paths) async {
    final files = paths.map((path) => File(path)).toList();
    return _convert(files, _commonParent(paths));
  }

  static Future<FilesToPromptResult> fromDirectory(String directoryPath) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) throw const FileSystemException('Выбранная папка не существует.');
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: directoryPath);
      final parts = p.split(relative);
      if (parts.any((part) => _ignoredDirectories.contains(part.toLowerCase()))) continue;
      final lowerName = p.basename(entity.path).toLowerCase();
      if (_ignoredFileSuffixes.any((suffix) => lowerName.endsWith(suffix))) continue;
      files.add(entity);
      if (files.length >= maxFiles) break;
    }
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return _convert(files, directoryPath);
  }

  static String _commonParent(List<String> paths) {
    if (paths.isEmpty) return Directory.current.path;
    var parent = p.normalize(p.dirname(paths.first));
    for (final path in paths.skip(1)) {
      while (parent != p.dirname(parent) && !p.isWithin(parent, p.normalize(path))) {
        parent = p.dirname(parent);
      }
    }
    return parent;
  }

  static Future<FilesToPromptResult> _convert(List<File> files, String root) async {
    if (files.isEmpty) throw const FormatException('В выбранном расположении не найдено файлов.');
    final output = StringBuffer();
    final skipped = <String>[];
    var included = 0;
    var totalBytes = 0;

    output.writeln('Ниже приведено содержимое файлов проекта. Сохраняй пути и структуру каталогов.');
    output.writeln('Для каждого файла используй указанный путь и полное содержимое.');
    output.writeln();

    for (final file in files) {
      if (included >= maxFiles) {
        skipped.add('Достигнут лимит $maxFiles файлов.');
        break;
      }
      try {
        final length = await file.length();
        if (length > maxFileBytes) {
          skipped.add('${p.basename(file.path)} — больше 2 МБ');
          continue;
        }
        if (totalBytes + length > maxTotalBytes) {
          skipped.add('Превышен общий лимит 12 МБ; остальные файлы пропущены.');
          break;
        }
        final bytes = await file.readAsBytes();
        if (bytes.contains(0)) {
          skipped.add('${p.basename(file.path)} — бинарный файл');
          continue;
        }
        final content = utf8.decode(bytes, allowMalformed: false).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final relative = (p.isWithin(root, file.path) || p.equals(root, file.path))
            ? p.relative(file.path, from: root)
            : p.basename(file.path);
        final displayPath = relative.replaceAll('\\', '/');
        output.writeln('<<<FILE: $displayPath>>>');
        output.writeln(content);
        if (!content.endsWith('\n')) output.writeln();
        output.writeln('<<<END>>>');
        output.writeln();
        included++;
        totalBytes += length;
      } on FormatException {
        skipped.add('${p.basename(file.path)} — не UTF-8 текст');
      } on FileSystemException catch (error) {
        skipped.add('${p.basename(file.path)} — ${error.message}');
      }
    }

    if (included == 0) throw FormatException('Не удалось прочитать текстовые файлы. ${skipped.join('; ')}');
    output.writeln('<<<END_PROJECT>>>');
    return FilesToPromptResult(text: output.toString(), included: included, skipped: skipped);
  }
}
