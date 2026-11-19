import 'package:flutter_test/flutter_test.dart';
import 'package:code_bridge_mini/services/project_naming.dart';

void main() {
  group('ProjectNaming.packageName', () {
    test('transliterates Russian project names without losing the display name', () {
      expect(ProjectNaming.packageName('Мой первый проект'), 'moy_pervyy_proekt');
    });

    test('handles mixed Russian, English, spaces and punctuation', () {
      expect(ProjectNaming.packageName('Заметки Pro 2.0!'), 'zametki_pro_2_0');
    });

    test('preserves separators between consecutive Russian words', () {
      expect(ProjectNaming.packageName('Мой   первый, проект!'), 'moy_pervyy_proekt');
    });

    test('returns a valid fallback for names without supported letters', () {
      expect(ProjectNaming.packageName('中文项目'), 'flutter_project');
    });

    test('limits package name length', () {
      expect(ProjectNaming.packageName('А' * 100).length, lessThanOrEqualTo(50));
    });
  });
}
