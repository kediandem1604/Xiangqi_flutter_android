import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PikafishEngine {
  static const String _tag = 'PikafishEngine';
  static const MethodChannel _channel = MethodChannel('app_paths');
  static const String _assetBinary = 'assets/pikafish_arm64';
  static const String _assetNnue = 'assets/pikafish.nnue';
  static const String _engineName = 'pikafish';

  Process? _engineProcess;
  StreamController<String>? _outputController;
  StreamSubscription? _outputSubscription;
  bool _isInitialized = false;
  String? _binaryPath;

  // Xiangqi positions for testing
  static const String startingPosition = 'startpos';
  static const String midgamePosition =
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';
  static const String endgamePosition = '4k4/9/9/9/9/9/9/9/4K4/9 w - - 0 1';

  /// Get native library directory via MethodChannel
  Future<String?> _getNativeLibraryDir() async {
    try {
      final dir = await _channel.invokeMethod<String>('getNativeLibraryDir');
      return dir;
    } catch (e) {
      debugPrint('$_tag: Failed to get native library dir: $e');
      return null;
    }
  }

  /// Copy NNUE file to writable directory
  Future<String> _ensureNnue() async {
    try {
      // Use ApplicationSupportDirectory (writable) instead of nativeLibraryDir (read-only)
      final support = await getApplicationSupportDirectory();
      await support.create(recursive: true);
      final dst = File(p.join(support.path, 'pikafish.nnue'));

      if (!await dst.exists() || (await dst.length()) == 0) {
        debugPrint('$_tag: Copying NNUE to: ${dst.path}');
        final data = await rootBundle.load(_assetNnue);
        await dst.writeAsBytes(data.buffer.asUint8List());
        debugPrint('$_tag: NNUE copied successfully');
      } else {
        debugPrint('$_tag: NNUE already exists');
      }

      return dst.path;
    } catch (e) {
      debugPrint('$_tag: Failed to setup NNUE: $e');
      rethrow;
    }
  }

  /// Copy binary to target directory
  Future<String> _copyBinaryTo(Directory dir) async {
    await dir.create(recursive: true);
    final dst = File(p.join(dir.path, _engineName));

    debugPrint('$_tag: Target binary path: ${dst.path}');
    debugPrint('$_tag: Directory exists: ${await dir.exists()}');
    debugPrint('$_tag: Binary exists: ${await dst.exists()}');

    // Always copy from assets to ensure fresh binary
    debugPrint('$_tag: Copying binary from assets: $_assetBinary');
    try {
      final data = await rootBundle.load(_assetBinary);
      debugPrint('$_tag: Asset data size: ${data.lengthInBytes} bytes');
      await dst.writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint('$_tag: Binary copied successfully');

      // Verify file was written
      final writtenFile = File(dst.path);
      if (await writtenFile.exists()) {
        final stat = await writtenFile.stat();
        debugPrint('$_tag: Written file size: ${stat.size} bytes');
      } else {
        debugPrint('$_tag: ERROR: File does not exist after writing!');
      }
    } catch (e) {
      debugPrint('$_tag: ERROR copying binary: $e');
      rethrow;
    }

    // chmod 700
    try {
      await Process.run('/system/bin/chmod', ['700', dst.path]);
      debugPrint('$_tag: chmod 700 successful');
    } catch (e) {
      debugPrint('$_tag: chmod failed: $e');
      // Fallback: try chmod +x
      try {
        await Process.run('chmod', ['+x', dst.path]);
        debugPrint('$_tag: chmod +x successful');
      } catch (e2) {
        debugPrint('$_tag: chmod +x also failed: $e2');
      }
    }

    return dst.path;
  }

  /// Choose executable path: prioritize nativeLibraryDir, then ApplicationSupport, then Temp
  Future<String> _ensureExecutablePath() async {
    debugPrint('$_tag: === Starting executable path detection ===');

    // A) nativeLibraryDir (most stable) - highest priority
    final libDir = await _getNativeLibraryDir();
    debugPrint('$_tag: Native library dir: $libDir');
    if (libDir != null) {
      final path = p.join(libDir, 'libpikafish_exec.so');
      debugPrint('$_tag: Checking native library path: $path');
      if (await File(path).exists()) {
        debugPrint('$_tag: ✓ Using native library (no copy needed): $path');
        return path;
      } else {
        debugPrint('$_tag: ✗ Native library not found at: $path');
        debugPrint(
          '$_tag: Native library approach failed, using asset copy approach',
        );
      }
    }

    // B) ApplicationSupportDirectory with linker64 fallback
    debugPrint(
      '$_tag: Trying Application Support Directory with linker64 fallback...',
    );
    try {
      final support = await getApplicationSupportDirectory();
      debugPrint('$_tag: Application Support dir: ${support.path}');
      final supportPath = await _copyBinaryTo(support);
      debugPrint(
        '$_tag: ✓ Using Application Support (will try linker64 if needed): $supportPath',
      );
      return supportPath;
    } catch (e) {
      debugPrint('$_tag: ✗ Application Support failed: $e');
    }

    // C) TemporaryDirectory with linker64 fallback
    debugPrint('$_tag: Trying Temporary Directory with linker64 fallback...');
    try {
      final tmp = await getTemporaryDirectory();
      debugPrint('$_tag: Temporary dir: ${tmp.path}');
      final tmpPath = await _copyBinaryTo(tmp);
      debugPrint(
        '$_tag: ✓ Using Temporary Directory (will try linker64 if needed): $tmpPath',
      );
      return tmpPath;
    } catch (e) {
      debugPrint('$_tag: ✗ Temporary Directory failed: $e');
      throw Exception('No suitable directory found for binary');
    }
  }

  /// Spawn engine process (simplified like OnlyEngine)
  Future<Process> _spawn(String execPath) async {
    debugPrint('$_tag: === Spawning engine: $execPath ===');

    // Verify file exists
    final file = File(execPath);
    if (!await file.exists()) {
      debugPrint('$_tag: ERROR: Binary file does not exist: $execPath');
      throw Exception('Binary file does not exist: $execPath');
    }

    final stat = await file.stat();
    debugPrint('$_tag: File size: ${stat.size} bytes');
    debugPrint('$_tag: File mode: ${stat.mode}');
    debugPrint('$_tag: File path: ${file.path}');

    // Set working directory to binary's parent (like OnlyEngine)
    final workingDir = file.parent.path;
    debugPrint('$_tag: Working directory: $workingDir');

    try {
      debugPrint('$_tag: Starting engine process...');
      final p = await Process.start(
        execPath,
        [],
        runInShell: false,
        workingDirectory: workingDir,
      );

      debugPrint('$_tag: Engine process started with PID: ${p.pid}');

      // Log stderr for debugging
      p.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((
        l,
      ) {
        debugPrint('$_tag: ERR: $l');
      });

      debugPrint('$_tag: ✓ Engine execution successful');
      return p;
    } catch (e) {
      debugPrint('$_tag: ✗ Engine start failed: $e');
      throw Exception('Engine failed to start: $execPath');
    }
  }

  void _sendCommand(String s) {
    debugPrint('$_tag: >>> $s');
    _engineProcess!.stdin.writeln(s);
  }

  /// Initialize UCI protocol with proper handshake
  Future<void> _initUciProtocol(String nnuePath) async {
    // Send UCI command
    debugPrint('$_tag: WAIT uciok');
    _sendCommand('uci');
    await _waitFor((line) => line.contains('uciok'), 5000);

    // Set NNUE path if available
    if (nnuePath.isNotEmpty) {
      _sendCommand('setoption name EvalFile value $nnuePath');
      debugPrint('$_tag: Set NNUE path: $nnuePath');
    } else {
      _sendCommand('setoption name EvalFile value ""');
      debugPrint('$_tag: NNUE disabled');
    }

    // Wait for ready
    debugPrint('$_tag: WAIT readyok (after setoption)');
    _sendCommand('isready');
    await _waitFor((line) => line.contains('readyok'), 5000);

    // New game
    _sendCommand('ucinewgame');
    debugPrint('$_tag: WAIT readyok (after ucinewgame)');
    _sendCommand('isready');
    await _waitFor((line) => line.contains('readyok'), 5000);
  }

  /// Wait for specific response with timeout
  Future<String> _waitFor(
    bool Function(String) predicate,
    int timeoutMs,
  ) async {
    final completer = Completer<String>();
    late StreamSubscription subscription;

    subscription = _outputController!.stream.listen((line) {
      if (predicate(line)) {
        subscription.cancel();
        completer.complete(line);
      }
    });

    // Timeout
    Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError('Timeout waiting for response');
      }
    });

    return completer.future;
  }

  /// Initialize the engine
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('$_tag: Engine already initialized');
      return;
    }

    try {
      _binaryPath = await _ensureExecutablePath();
      debugPrint('$_tag: Binary path: $_binaryPath');

      // Copy NNUE to writable directory
      final nnuePath = await _ensureNnue();

      // Spawn engine process
      _engineProcess = await _spawn(_binaryPath!);
      _outputController = StreamController<String>.broadcast();

      // Setup output stream
      _outputSubscription = _engineProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            debugPrint('$_tag: <<< $line');
            _outputController!.add(line);
          });

      // Initialize UCI protocol with overall timeout
      await _initUciProtocol(nnuePath).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('UCI handshake timeout');
        },
      );
      _isInitialized = true;

      debugPrint(
        '$_tag: Pikafish engine initialized successfully with neural network',
      );
    } catch (e) {
      debugPrint('$_tag: Failed to initialize engine: $e');
      // Ensure process cleanup on failure to prevent future hangs
      try {
        _engineProcess?.kill();
      } catch (_) {}
      _engineProcess = null;
      _isInitialized = false;
      rethrow;
    }
  }

  /// Send command to engine
  Future<void> sendCommand(String command) async {
    if (_engineProcess == null) {
      throw Exception('Engine not initialized');
    }

    debugPrint('$_tag: >>> $command');
    _engineProcess!.stdin.writeln(command);
    await _engineProcess!.stdin.flush();
  }

  /// Wait for response from engine
  Future<String> _waitForResponse(
    String expectedResponse,
    int timeoutMs,
  ) async {
    if (_outputController == null) {
      throw Exception('Output controller not initialized');
    }

    final completer = Completer<String>();
    late StreamSubscription subscription;

    subscription = _outputController!.stream.listen((line) {
      if (line.contains(expectedResponse)) {
        subscription.cancel();
        completer.complete(line);
      }
    });

    // Timeout
    Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError('Timeout waiting for $expectedResponse');
      }
    });

    return completer.future;
  }

  /// Set engine position with moves
  Future<void> setPosition(String fen, List<String> moves) async {
    if (!_isInitialized) {
      throw Exception('Engine not initialized');
    }

    // Build position command
    String positionCmd;
    if (fen == 'startpos') {
      if (moves.isNotEmpty) {
        positionCmd = 'position startpos moves ${moves.join(' ')}';
      } else {
        positionCmd = 'position startpos';
      }
    } else {
      if (moves.isNotEmpty) {
        positionCmd = 'position fen $fen moves ${moves.join(' ')}';
      } else {
        positionCmd = 'position fen $fen';
      }
    }

    debugPrint('$_tag: Setting position: $positionCmd');
    _sendCommand(positionCmd);

    // Wait for ready with longer timeout
    _sendCommand('isready');
    await _waitForResponse('readyok', 5000);
  }

  /// Get best move for given position
  Future<String> getBestMove(String fen, int depth) async {
    if (!_isInitialized) {
      throw Exception('Engine not initialized');
    }

    // Send position command
    if (fen == 'startpos') {
      _sendCommand('position startpos');
    } else {
      _sendCommand('position fen $fen');
    }

    // Send go command
    _sendCommand('go depth $depth');

    // Wait for bestmove with longer timeout
    final line = await _waitForResponse('bestmove', 15000);
    debugPrint('$_tag: Found bestmove: $line');

    // Parse: "bestmove e2e4 ponder ..." -> "e2e4"
    final parts = line.split(' ');
    final idx = parts.indexOf('bestmove');
    final bestMove = (idx >= 0 && idx + 1 < parts.length) ? parts[idx + 1] : '';

    return bestMove;
  }

  /// Get top N moves for given position
  Future<String> getTopMoves(
    String fen,
    int depth,
    int numMoves, [
    List<String>? moves,
  ]) async {
    if (!_isInitialized) {
      throw Exception('Engine not initialized');
    }

    // Set MultiPV and wait ready
    _sendCommand('setoption name MultiPV value $numMoves');
    _sendCommand('isready');
    await _waitForResponse('readyok', 3000);

    // Send position command
    if (fen == 'startpos') {
      if (moves != null && moves.isNotEmpty) {
        _sendCommand('position startpos moves ${moves.join(' ')}');
      } else {
        _sendCommand('position startpos');
      }
    } else {
      if (moves != null && moves.isNotEmpty) {
        _sendCommand('position fen $fen moves ${moves.join(' ')}');
      } else {
        _sendCommand('position fen $fen');
      }
    }

    // Send go command
    _sendCommand('go depth $depth');

    // Collect MultiPV info lines
    final results = <String>[];
    late StreamSubscription subscription;

    subscription = _outputController!.stream.listen((line) {
      if (line.startsWith('bestmove')) {
        subscription.cancel();
      } else if (line.contains('multipv')) {
        debugPrint('$_tag: MultiPV info: $line');
        results.add(line);
      }
    });

    // Wait for bestmove (longer for MultiPV)
    final perDepthMs = 3000;
    final extraPerPvMs = 3000;
    final timeoutMs = (depth * perDepthMs + (numMoves - 1) * extraPerPvMs)
        .clamp(15000, 90000);
    await _waitForResponse('bestmove', timeoutMs);
    subscription.cancel();

    // Reset MultiPV to 1 and wait ready
    _sendCommand('setoption name MultiPV value 1');
    _sendCommand('isready');
    await _waitForResponse('readyok', 3000);

    final result = results.join('\n');
    debugPrint('$_tag: Top moves result: $result');
    return result;
  }

  /// Close engine
  Future<void> close() async {
    if (_engineProcess != null) {
      try {
        _engineProcess!.kill();
        _engineProcess = null;
      } catch (e) {
        debugPrint('$_tag: Error closing engine: $e');
      }
    }
    _outputSubscription?.cancel();
    _outputController?.close();
    _isInitialized = false;
    debugPrint('$_tag: Engine closed');
  }

  /// Set MultiPV value
  Future<void> setMultiPV(int value) async {
    if (!_isInitialized) {
      throw Exception('Engine not initialized');
    }

    _sendCommand('setoption name MultiPV value $value');
    _sendCommand('isready'); // <- thêm dòng này
    await _waitForResponse('readyok', 3000); // giờ mới đợi readyok
    debugPrint('$_tag: MultiPV set to $value');
  }

  /// Stop any ongoing search (for reset)
  Future<void> stop() async {
    if (!_isInitialized) {
      return;
    }

    _sendCommand('stop');

    // Wait for bestmove to ensure clean state
    try {
      await _waitForResponse('bestmove', 5000);
    } catch (e) {
      // Ignore timeout - engine might not be searching
      debugPrint('$_tag: No ongoing search to stop: $e');
    }
  }

  /// Start a new game
  Future<void> newGame() async {
    if (!_isInitialized) {
      throw Exception('Engine not initialized');
    }

    // Start new game
    _sendCommand('ucinewgame');
    // PHẢI có isready thì engine mới trả readyok
    _sendCommand('isready');
    await _waitForResponse('readyok', 3000);
    debugPrint('$_tag: New game started');
  }

  /// Check if engine is initialized
  bool get isInitialized => _isInitialized;
}
