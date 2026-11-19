class ProjectNaming {
  static const Map<String, String> _transliteration = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e',
    'ё': 'yo', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k',
    'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
    'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
    'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '',
    'э': 'e', 'ю': 'yu', 'я': 'ya',
    'і': 'i', 'ї': 'yi', 'є': 'ye', 'ґ': 'g',
  };

  /// Converts a display name in any language to a stable Dart package slug.
  /// This implementation avoids Unicode regular-expression processing on each
  /// keystroke in the project creation dialog.
  static String packageName(String input) {
    final source = input.trim().toLowerCase();
    final result = StringBuffer();
    var separatorPending = false;

    for (final rune in source.runes) {
      final character = String.fromCharCode(rune);
      final converted = _transliteration[character];
      if (converted != null) {
        if (converted.isEmpty) continue;
        // Insert a separator before transliterated letters too. Previously
        // spaces were handled only in the ASCII branch, joining Russian words.
        if (separatorPending && result.isNotEmpty) result.write('_');
        result.write(converted);
        separatorPending = false;
      } else if (_isAsciiLetterOrDigit(rune)) {
        if (separatorPending && result.isNotEmpty) result.write('_');
        result.write(character);
        separatorPending = false;
      } else {
        separatorPending = true;
      }
    }

    var slug = result.toString();
    if (slug.isEmpty) slug = 'flutter_project';
    if (!_isAsciiLetter(slug.codeUnitAt(0))) slug = 'app_$slug';
    if (slug.length > 50) slug = slug.substring(0, 50).replaceFirst(RegExp(r'_+$'), '');
    return slug;
  }

  static bool _isAsciiLetterOrDigit(int rune) =>
      (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);

  static bool _isAsciiLetter(int rune) =>
      (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x41 && rune <= 0x5a);
}
