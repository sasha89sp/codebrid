import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_bridge_mini/services/files_to_prompt.dart';

void main() {
  group('FilesToPrompt', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp('codebridge_prompt_test_');
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('converts selected text files to marked UTF-8 text', () async {
      final source = File('${temporaryDirectory.path}/lib/main.dart');
      await source.parent.create(recursive: true);
      await source.writeAsString("void main() {\n  print('Привет');\n}\n", encoding: utf8);

      final result = await FilesToPrompt.fromFiles([source.path]);

      expect(result.included, 1);
      expect(result.text, contains('<<<FILE: main.dart>>>'));
      expect(result.text, contains('Привет'));
      expect(result.text, contains('<<<END_PROJECT>>>'));
    });

    test('skips generated folders when converting a project directory', () async {
      final source = File('${temporaryDirectory.path}/lib/main.dart');
      final generated = File('${temporaryDirectory.path}/build/generated.txt');
      await source.parent.create(recursive: true);
      await generated.parent.create(recursive: true);
      await source.writeAsString('void main() {}');
      await generated.writeAsString('do not include');

      final result = await FilesToPrompt.fromDirectory(temporaryDirectory.path);

      expect(result.included, 1);
      expect(result.text, contains('lib/main.dart'));
      expect(result.text, isNot(contains('do not include')));
    });

    test('skips generated dart files and windows ephemeral directory per AGENTS.md', () async {
      final source = File('${temporaryDirectory.path}/lib/main.dart');
      final generatedG = File('${temporaryDirectory.path}/lib/model.g.dart');
      final generatedFreezed = File('${temporaryDirectory.path}/lib/model.freezed.dart');
      final generatedGr = File('${temporaryDirectory.path}/lib/router.gr.dart');
      final ephemeral = File('${temporaryDirectory.path}/windows/flutter/ephemeral/generated_config.cmake');

      for (final file in [source, generatedG, generatedFreezed, generatedGr, ephemeral]) {
        await file.parent.create(recursive: true);
        await file.writeAsString('content of ${file.path}');
      }

      final result = await FilesToPrompt.fromDirectory(temporaryDirectory.path);

      expect(result.included, 1);
      expect(result.text, contains('lib/main.dart'));
      expect(result.text, isNot(contains('model.g.dart')));
      expect(result.text, isNot(contains('model.freezed.dart')));
      expect(result.text, isNot(contains('router.gr.dart')));
      expect(result.text, isNot(contains('generated_config.cmake')));
    });
  });
}
