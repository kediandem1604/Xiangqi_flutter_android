import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  late final Future<File> _logFileFuture = _initLogFile();

  static Future<void> ensureInitialized() async {
    await AppLogger()._logFileFuture;
  }

  Future<File> _initLogFile() async {
    try {
      final Directory baseDir = await getApplicationSupportDirectory();
      final Directory logDir = Directory(
        '${baseDir.path}${Platform.pathSeparator}logs',
      );
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final String ts = _tsFileSafe(DateTime.now());
      final File file = File(
        '${logDir.path}${Platform.pathSeparator}xiangqi_$ts.log',
      );
      // Write header
      await file.writeAsString(
        '[LOG START] $ts\n',
        mode: FileMode.write,
        flush: true,
      );
      return file;
    } catch (_) {
      // Fallback to system temp directory
      final Directory tmp = Directory.systemTemp;
      final File file = File(
        '${tmp.path}${Platform.pathSeparator}xiangqi_fallback.log',
      );
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      return file;
    }
  }

  // Returns the preferred logs directory path. May not exist yet.
  Future<String> getLogsDirectoryPath() async {
    try {
      final Directory baseDir = await getApplicationSupportDirectory();
      return '${baseDir.path}${Platform.pathSeparator}logs';
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  Future<void> log(String message) async {
    final File file = await _logFileFuture;
    final String line = '${_ts(DateTime.now())}  INFO  $message\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<void> error(String message, [Object? err, StackTrace? st]) async {
    final File file = await _logFileFuture;
    final String line =
        '${_ts(DateTime.now())}  ERROR $message'
        '${err != null ? ' | $err' : ''}${st != null ? '\n$st' : ''}\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  String _ts(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  String _tsFileSafe(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_'
        '${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
  }
}
