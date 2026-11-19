import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef ZipReadyCallback = Future<void> Function(String zipPath);

class DownloadsWatcherService {
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _pollTimer;
  String? _watchedDirectory;
  final Set<String> _knownSignatures = <String>{};
  final Set<String> _inFlightPaths = <String>{};
  ZipReadyCallback? _onZipReady;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  String? get watchedDirectory => _watchedDirectory;

  static String defaultDownloadsPath() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final profile = env['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return p.join(profile, 'Downloads');
      }
    }
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      return p.join(home, 'Downloads');
    }
    return Directory.current.path;
  }

  Future<void> start({
    required String directoryPath,
    required ZipReadyCallback onZipReady,
  }) async {
    await stop();
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw FileSystemException('Папка для мониторинга не найдена.', directoryPath);
    }

    _watchedDirectory = directoryPath;
    _onZipReady = onZipReady;
    _knownSignatures.clear();
    _inFlightPaths.clear();

    // Запоминаем уже существующие ZIP-архивы, чтобы не отправлять старые файлы.
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isZipFile(entity.path)) {
        final sig = await _fileSignature(entity);
        if (sig != null) _knownSignatures.add(sig);
      }
    }

    _isRunning = true;

    try {
      _subscription = dir
          .watch(
            events: FileSystemEvent.create | FileSystemEvent.move | FileSystemEvent.modify,
            recursive: false,
          )
          .listen(
            (event) {
              if (!_isRunning) return;
              final candidatePath = event is FileSystemMoveEvent
                  ? (event.destination ?? event.path)
                  : event.path;
              if (_isZipFile(candidatePath)) {
                unawaited(_handleCandidate(candidatePath));
              }
            },
            onError: (_) {},
          );
    } catch (_) {
      // На некоторых ФС watch может не поддерживаться — подстрахует таймер.
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isRunning) return;
      unawaited(_scanDirectory());
    });
  }

  Future<void> stop() async {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _inFlightPaths.clear();
  }

  Future<void> _scanDirectory() async {
    final path = _watchedDirectory;
    if (path == null) return;
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (!_isRunning) return;
      if (entity is File && _isZipFile(entity.path)) {
        unawaited(_handleCandidate(entity.path));
      }
    }
  }

  Future<void> _handleCandidate(String filePath) async {
    final normalized = p.normalize(filePath);
    if (_inFlightPaths.contains(normalized)) return;
    _inFlightPaths.add(normalized);
    try {
      final file = File(normalized);
      if (!await _waitUntilStable(file)) return;

      final signature = await _fileSignature(file);
      if (signature == null || _knownSignatures.contains(signature)) return;
      _knownSignatures.add(signature);

      final callback = _onZipReady;
      if (_isRunning && callback != null) {
        await callback(normalized);
      }
    } finally {
      _inFlightPaths.remove(normalized);
    }
  }

  Future<bool> _waitUntilStable(File file) async {
    int? previousSize;
    for (var attempt = 0; attempt < 25; attempt++) {
      if (!_isRunning) return false;
      if (!await file.exists()) return false;
      try {
        final stat = await file.stat();
        if (stat.size > 0 && previousSize == stat.size) {
          // Проверяем, что файл уже не заблокирован браузером на запись.
          final raf = await file.open(mode: FileMode.read);
          await raf.close();
          return true;
        }
        previousSize = stat.size;
      } catch (_) {
        previousSize = null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return false;
  }

  Future<String?> _fileSignature(File file) async {
    try {
      final stat = await file.stat();
      return '${p.normalize(file.path).toLowerCase()}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  static bool _isZipFile(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.zip') &&
        !lower.endsWith('.crdownload') &&
        !lower.endsWith('.part') &&
        !lower.endsWith('.tmp');
  }
}
