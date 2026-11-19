import 'dart:async';

import 'package:window_manager/window_manager.dart';

import 'app_storage.dart';

class WindowSizeListener extends WindowListener {
  WindowSizeListener(this.storage);

  final AppStorage storage;
  Timer? _saveTimer;

  @override
  void onWindowResize() {
    _scheduleSave();
  }

  @override
  void onWindowResized() {
    _scheduleSave(const Duration(milliseconds: 80));
  }

  void _scheduleSave([Duration delay = const Duration(milliseconds: 700)]) {
    _saveTimer?.cancel();
    _saveTimer = Timer(delay, () async {
      try {
        final size = await windowManager.getSize();
        await storage.writeWindowSize(size.width, size.height);
      } catch (_) {
        // Сбой сохранения размеров окна не влияет на работу программы.
      }
    });
  }

  void dispose() {
    _saveTimer?.cancel();
    windowManager.removeListener(this);
  }
}
