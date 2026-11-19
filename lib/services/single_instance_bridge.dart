import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Портативный локальный IPC-мост на 127.0.0.1 для передачи пути к .zip
/// при запуске через «Открыть с помощью -> CodeBridge Mini».
class SingleInstanceBridge {
  SingleInstanceBridge(this.dataDirectory);

  final String dataDirectory;
  ServerSocket? _server;

  File get _portFile => File(p.join(dataDirectory, 'ipc_port.txt'));

  /// Пытается передать [zipPath] уже запущенному экземпляру.
  /// Возвращает true, если путь успешно передан и текущий процесс можно завершить.
  Future<bool> tryForwardToRunningInstance(String zipPath) async {
    try {
      if (!await _portFile.exists()) return false;
      final rawPort = (await _portFile.readAsString(encoding: utf8)).trim();
      final port = int.tryParse(rawPort);
      if (port == null || port <= 0) return false;

      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 800),
      );
      socket.writeln(zipPath);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Запускает локальный слушатель для приёма путей к ZIP от новых запусков EXE.
  Future<void> startListening(void Function(String zipPath) onZipReceived) async {
    try {
      await Directory(dataDirectory).create(recursive: true);
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      await _portFile.writeAsString('${_server!.port}\n', encoding: utf8, flush: true);

      _server!.listen((Socket client) {
        final buffer = StringBuffer();
        client.listen(
          (List<int> data) {
            buffer.write(utf8.decode(data, allowMalformed: true));
          },
          onDone: () {
            final received = buffer.toString().trim();
            if (received.isNotEmpty) {
              onZipReceived(received);
            }
            client.destroy();
          },
          onError: (_) => client.destroy(),
        );
      });
    } catch (_) {
      // Если порт не удалось открыть, приложение продолжает работать без IPC.
    }
  }

  Future<void> dispose() async {
    await _server?.close();
    _server = null;
    try {
      if (await _portFile.exists()) {
        await _portFile.delete();
      }
    } catch (_) {}
  }
}
