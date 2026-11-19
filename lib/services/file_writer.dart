import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generated_file.dart';

class FileWriter {
  static String validateRelativePath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized) || normalized.startsWith('//')) {
      throw FormatException('Недопустимый абсолютный путь: "$filePath".');
    }

    final segments = normalized.split('/');
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        throw FormatException('Недопустимый сегмент пути: "$filePath".');
      }
      if (RegExp(r'[<>:"|?*]').hasMatch(segment) ||
          segment.endsWith('.') || segment.endsWith(' ')) {
        throw FormatException('Недопустимое имя файла в пути: "$filePath".');
      }
      final deviceName = segment.split('.').first.toUpperCase();
      if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(deviceName)) {
        throw FormatException('Имя "$segment" зарезервировано Windows.');
      }
    }
    return p.joinAll(segments);
  }

  static Future<List<String>> findConflicts(
    String outputDirectory,
    List<GeneratedFile> files,
  ) async {
    final conflicts = <String>[];
    for (final generated in files.where((file) => file.selected)) {
      final relative = validateRelativePath(generated.path);
      final target = p.normalize(p.join(outputDirectory, relative));
      if (!_isWithin(outputDirectory, target)) {
        throw FormatException('Путь выходит за пределы папки проекта: ${generated.path}');
      }
      if (await File(target).exists()) conflicts.add(generated.path);
    }
    return conflicts;
  }

  static Future<bool> canMergePubspecFragment(String outputDirectory, GeneratedFile generated) async {
    if (!generated.isFragment ||
        !const {'pubspec.yaml', 'pubspec.yml'}.contains(generated.path.toLowerCase())) {
      return false;
    }
    final target = File(p.join(outputDirectory, validateRelativePath(generated.path)));
    return target.exists();
  }

  /// Объединяет секции dependencies/dev_dependencies, не перезаписывая остальной pubspec.
  /// Комментарии и порядок существующего файла сохраняются, новые пакеты добавляются.
  static Future<GeneratedFile> mergePubspecFragment(
    String outputDirectory,
    GeneratedFile fragment,
  ) async {
    if (!await canMergePubspecFragment(outputDirectory, fragment)) {
      throw StateError('Для объединения фрагмента нужен существующий полный pubspec.yaml.');
    }
    final target = File(p.join(outputDirectory, validateRelativePath(fragment.path)));
    final existing = await target.readAsString(encoding: utf8);
    final merged = _mergePubspecText(existing, fragment.content);
    return fragment.copyWith(
      content: merged,
      isFragment: false,
      selected: true,
      note: 'Фрагмент зависимостей объединён с существующим pubspec.yaml.',
    );
  }

  static String _mergePubspecText(String existing, String fragment) {
    final existingLines = _normalize(existing).split('\n');
    final fragmentLines = _normalize(fragment).split('\n');
    final sectionsToMerge = <String>{'dependencies', 'dev_dependencies', 'dependency_overrides'};
    final fragmentSections = _topLevelSections(fragmentLines);
    var merged = List<String>.from(existingLines);
    var mergedAny = false;

    for (final section in fragmentSections.keys) {
      if (!sectionsToMerge.contains(section)) continue;
      final fragmentRange = fragmentSections[section]!;
      final fragmentChildren = _sectionEntryBlocks(fragmentLines, fragmentRange.start, fragmentRange.end);
      if (fragmentChildren.isEmpty) continue;

      var existingSections = _topLevelSections(merged);
      final existingRange = existingSections[section];
      if (existingRange == null) {
        if (merged.isNotEmpty && merged.last.trim().isNotEmpty) merged.add('');
        merged.add('$section:');
        for (final block in fragmentChildren.values) {
          merged.addAll(block);
        }
        mergedAny = true;
        continue;
      }

      final existingChildren = _sectionEntryBlocks(merged, existingRange.start, existingRange.end);
      final replacement = <String>[];
      for (final child in existingChildren.entries) {
        if (fragmentChildren.containsKey(child.key)) {
          replacement.addAll(fragmentChildren.remove(child.key)!);
        } else {
          replacement.addAll(child.value);
        }
      }
      for (final remaining in fragmentChildren.values) {
        if (replacement.isNotEmpty && replacement.last.trim().isNotEmpty) {
          replacement.add('');
        }
        replacement.addAll(remaining);
      }
      merged = [
        ...merged.take(existingRange.start + 1),
        ...replacement,
        ...merged.skip(existingRange.end),
      ];
      mergedAny = true;
    }

    if (!mergedAny) {
      throw const FormatException(
        'Не удалось безопасно объединить фрагмент. Поддерживаются секции '
        'dependencies, dev_dependencies и dependency_overrides.',
      );
    }
    final result = merged.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
    return '$result\n';
  }

  static Map<String, _SectionRange> _topLevelSections(List<String> lines) {
    final starts = <String, int>{};
    for (var index = 0; index < lines.length; index++) {
      final match = RegExp(r'^([A-Za-z0-9_-]+):\s*(?:#.*)?$').firstMatch(lines[index]);
      if (match != null) starts[match.group(1)!] = index;
    }
    final ordered = starts.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final result = <String, _SectionRange>{};
    for (var index = 0; index < ordered.length; index++) {
      final start = ordered[index].value;
      final end = index + 1 < ordered.length ? ordered[index + 1].value : lines.length;
      result[ordered[index].key] = _SectionRange(start, end);
    }
    return result;
  }

  static Map<String, List<String>> _sectionEntryBlocks(
    List<String> lines,
    int start,
    int end,
  ) {
    final result = <String, List<String>>{};
    String? currentKey;
    var current = <String>[];
    for (var index = start + 1; index < end; index++) {
      final line = lines[index];
      final match = RegExp(r'^  ([A-Za-z0-9_.-]+):(?:\s*.*)?$').firstMatch(line);
      if (match != null) {
        if (currentKey != null) result[currentKey] = current;
        currentKey = match.group(1)!;
        current = <String>[line];
      } else if (currentKey != null) {
        current.add(line);
      }
    }
    if (currentKey != null) result[currentKey] = current;
    return result;
  }

  static String _normalize(String value) =>
      value.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  static bool _isWithin(String root, String target) {
    final normalizedRoot = p.normalize(root);
    final normalizedTarget = p.normalize(target);
    final compareRoot = Platform.isWindows ? normalizedRoot.toLowerCase() : normalizedRoot;
    final compareTarget = Platform.isWindows ? normalizedTarget.toLowerCase() : normalizedTarget;
    return compareRoot == compareTarget || p.isWithin(normalizedRoot, normalizedTarget) ||
        (Platform.isWindows && p.isWithin(compareRoot, compareTarget));
  }

  static Future<void> writeFiles({
    required String outputDirectory,
    required List<GeneratedFile> files,
    required bool overwrite,
  }) async {
    final root = p.normalize(outputDirectory);
    await Directory(root).create(recursive: true);

    for (final generated in files.where((file) => file.selected)) {
      final relative = validateRelativePath(generated.path);
      final target = p.normalize(p.join(root, relative));
      if (!_isWithin(root, target)) {
        throw FormatException('Путь выходит за пределы папки проекта: ${generated.path}');
      }

      final file = File(target);
      if (!overwrite && await file.exists()) {
        throw FileSystemException('Файл уже существует', target);
      }
      await file.parent.create(recursive: true);
      final content = _normalize(generated.content);
      await file.writeAsString(content, encoding: utf8, flush: true);
    }
  }
}

class _SectionRange {
  const _SectionRange(this.start, this.end);

  final int start;
  final int end;
}
