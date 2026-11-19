import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'window_size_listener.dart';

class AppTrayService with TrayListener {
  bool isAvailable = false;

  Future<void> initialize(String iconPath) async {
    if (!Platform.isWindows) return;
    var resolvedIconPath = iconPath;
    if (!await File(resolvedIconPath).exists()) {
      final developmentIcon = p.join(Directory.current.path, 'assets', 'tray.ico');
      if (await File(developmentIcon).exists()) {
        resolvedIconPath = developmentIcon;
      } else {
        return;
      }
    }
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(resolvedIconPath);
      await trayManager.setToolTip('CodeBridge Mini 2.0');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Открыть CodeBridge Mini'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Полностью выйти'),
          ],
        ),
      );
      isAvailable = true;
    } catch (_) {
      trayManager.removeListener(this);
      isAvailable = false;
    }
  }

  Future<void> restoreWindow() async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() {
    restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open') {
      restoreWindow();
    } else if (menuItem.key == 'exit') {
      exitApplication();
    }
  }

  WindowSizeListener? windowSizeListener;

  Future<void> exitApplication() async {
    try {
      await windowSizeListener?.saveNow();
      trayManager.removeListener(this);
      await trayManager.destroy();
    } catch (_) {
      // Завершение приложения должно работать и при сбое значка трея.
    }
    exit(0);
  }
}

class AppWindowCloseListener extends WindowListener {
  AppWindowCloseListener(this.trayService, {this.windowSizeListener});

  final AppTrayService trayService;
  final WindowSizeListener? windowSizeListener;

  @override
  void onWindowClose() async {
    await windowSizeListener?.saveNow();
    if (trayService.isAvailable) {
      await windowManager.hide();
    } else {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }
}
