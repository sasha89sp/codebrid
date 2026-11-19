import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers/project_provider.dart';
import 'services/app_storage.dart';
import 'services/app_tray_service.dart';
import 'services/single_instance_bridge.dart';
import 'services/window_size_listener.dart';

String? _extractZipArgument(List<String> args) {
  for (final arg in args) {
    final cleaned = arg.trim();
    if (cleaned.toLowerCase().endsWith('.zip') && File(cleaned).existsSync()) {
      return cleaned;
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = AppStorage();
  await storage.initialize();

  final incomingZip = _extractZipArgument(args);
  final ipcBridge = SingleInstanceBridge(storage.dataDirectory);
  if (incomingZip != null) {
    final forwarded = await ipcBridge.tryForwardToRunningInstance(incomingZip);
    if (forwarded) {
      exit(0);
    }
  }

  final settings = await storage.loadSettings();

  await windowManager.ensureInitialized();
  final trayService = AppTrayService();
  await trayService.initialize(p.join(storage.applicationDirectory, 'tray.ico'));

  final windowCloseListener = AppWindowCloseListener(trayService);
  windowManager.addListener(windowCloseListener);
  windowManager.addListener(WindowSizeListener(storage));
  await windowManager.setPreventClose(trayService.isAvailable);

  final windowOptions = WindowOptions(
    size: Size(
      (settings.windowWidth ?? 1280).clamp(1000, 2200).toDouble(),
      (settings.windowHeight ?? 820).clamp(680, 1600).toDouble(),
    ),
    minimumSize: const Size(1000, 680),
    center: true,
    title: 'CodeBridge Mini 2.1',
    backgroundColor: const Color(0xFFF5F7FB),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final provider = ProjectProvider(storage, initialZipPath: incomingZip);
  unawaited(provider.initialize());

  await ipcBridge.startListening((String zipPath) {
    unawaited(trayService.restoreWindow());
    unawaited(provider.handleIncomingZipArgument(zipPath));
  });

  runApp(
    ChangeNotifierProvider<ProjectProvider>.value(
      value: provider,
      child: const CodeBridgeMiniApp(),
    ),
  );
}
