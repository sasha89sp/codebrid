import 'package:code_bridge_mini/services/file_writer.dart';
import 'package:code_bridge_mini/services/response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponseParser', () {
    test('разбирает несколько файлов и CRLF', () {
      final files = ResponseParser.parse(
        '<<<FILE: pubspec.yaml>>>\r\nname: demo\r\n<<<END>>>\r\n'
        '<<<FILE: lib/main.dart>>>\r\nvoid main() {}\r\n<<<END>>>\r\n'
        '<<<END_PROJECT>>>',
      );

      expect(files, hasLength(2));
      expect(files.first.path, 'pubspec.yaml');
      expect(files.first.content, 'name: demo\n');
      expect(files.last.path, 'lib/main.dart');
    });

    test('распознаёт Markdown-файлы из ответа с шагами и пояснениями', () {
      const answer = r'''Привет! Подготовил калькулятор для Windows.

### Шаг 1: Создание проекта и зависимости
```bash
flutter create windows_calculator --platforms=windows
cd windows_calculator
```
Открой `pubspec.yaml` и добавь пакет `math_expressions` в зависимости:
```yaml
dependencies:
  flutter:
    sdk: flutter
  math_expressions: ^2.4.0
```
### Шаг 2: Код приложения (`lib/main.dart`)
Полностью замени содержимое `main.dart` на этот код:
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const CalculatorApp());
}
```
### Шаг 3: Запуск
```bash
flutter run -d windows
```''';

      final result = ResponseParser.parseDetailed(answer);
      expect(result.files, hasLength(2));
      final pubspec = result.files.firstWhere((file) => file.path == 'pubspec.yaml');
      final main = result.files.firstWhere((file) => file.path == 'lib/main.dart');
      expect(pubspec.isFragment, isTrue);
      expect(pubspec.selected, isFalse);
      expect(main.isFragment, isFalse);
      expect(main.content, contains('runApp(const CalculatorApp())'));
    });

    test('распознаёт заголовки с нумерацией и именем файла', () {
      const answer = '''
## 2. `pubspec.yaml`
```yaml
name: calculator
version: 1.0.0+1
```
## 3. `lib/calculator_controller.dart`
```dart
class CalculatorController {}
```
''';
      final files = ResponseParser.parse(answer);
      expect(
        files.map((file) => file.path),
        containsAll(<String>['pubspec.yaml', 'lib/calculator_controller.dart']),
      );
    });

    test('распознаёт ответ ИИ с приветствием, шагами, командами и полным файлом', () {
      const answer = r'''Привет! Подготовил для тебя калькулятор.

### Шаг 1: Создание проекта и зависимости
```bash
flutter create windows_calculator --platforms=windows
cd windows_calculator
```
Открой `pubspec.yaml` и добавь пакет `math_expressions` в зависимости:
```yaml
dependencies:
  flutter:
    sdk: flutter
  math_expressions: ^2.4.0
```
### Шаг 2: Код приложения (`lib/main.dart`)
Полностью замени содержимое `main.dart` на этот код:
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const CalculatorApp());
}
```
### Шаг 3: Запуск на Windows
```bash
flutter run -d windows
```
''';
      final result = ResponseParser.parseDetailed(answer);
      expect(result.files, hasLength(2));
      expect(result.files.map((file) => file.path), containsAll(['pubspec.yaml', 'lib/main.dart']));
      expect(result.files.firstWhere((file) => file.path == 'pubspec.yaml').isFragment, isTrue);
      expect(result.files.firstWhere((file) => file.path == 'lib/main.dart').isFragment, isFalse);
    });

    test('сообщает об отсутствующем END', () {
      expect(
        () => ResponseParser.parse('<<<FILE: lib/main.dart>>>\nvoid main() {}'),
        throwsFormatException,
      );
    });

    test('отклоняет повторяющиеся пути без учёта регистра', () {
      expect(
        () => ResponseParser.parse(
          '<<<FILE: Readme.md>>>\na\n<<<END>>>\n'
          '<<<FILE: README.md>>>\nb\n<<<END>>>',
        ),
        throwsFormatException,
      );
    });
  });

  group('FileWriter path validation', () {
    test('принимает нормальный относительный путь', () {
      expect(FileWriter.validateRelativePath('lib/screens/home.dart'), isNotEmpty);
    });

    test('отклоняет выход из output и абсолютные пути', () {
      expect(() => FileWriter.validateRelativePath('../outside.txt'), throwsFormatException);
      expect(() => FileWriter.validateRelativePath(r'C:\temp\evil.txt'), throwsFormatException);
      expect(() => FileWriter.validateRelativePath('/root/evil.txt'), throwsFormatException);
    });
  });
}
