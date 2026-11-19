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

  @override
  void onWindowMaximize() {
    _scheduleSave(const Duration(milliseconds: 50));
  }

  @override
  void onWindowUnmaximize() {
    _scheduleSave(const Duration(milliseconds: 80));
  }

  @override
  void onWindowEnterFullScreen() {
    _scheduleSave(const Duration(milliseconds: 50));
  }

  @override
  void onWindowLeaveFullScreen() {
    _scheduleSave(const Duration(milliseconds: 80));
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    try {
      final isMinimized = await windowManager.isMinimized();
      final isMaximized = await windowManager.isMaximized();
      final isFullScreen = await windowManager.isFullScreen();
      final size = await windowManager.getSize();
      final current = await storage.loadSettings();
      if (isMinimized) {
        return;
      }
      // Сохраняем нормальные размеры только когда окно не развёрнуто и не в полноэкранном режиме,
      // чтобы при последующем снятии максимизации сохранялся исходный размер окна.
      final saveWidth = (!isMaximized && !isFullScreen)
          ? size.width
          : (current.windowWidth ?? size.width);
      final saveHeight = (!isMaximized && !isFullScreen)
          ? size.height
          : (current.windowHeight ?? size.height);
      await storage.writeWindowState(
        width: saveWidth,
        height: saveHeight,
        isMaximized: isMaximized,
        isFullScreen: isFullScreen,
      );
    } catch (_) {
      // Сбой сохранения состояния окна не влияет на работу программы.
    }
  }

  void _scheduleSave([Duration delay = const Duration(milliseconds: 500)]) {
    _saveTimer?.cancel();
    _saveTimer = Timer(delay, () {
      unawaited(saveNow());
    });
  }

  void dispose() {
    _saveTimer?.cancel();
    windowManager.removeListener(this);
  }
}
