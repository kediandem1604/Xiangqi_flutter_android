import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../pikafish_engine.dart';
import '../../core/xiangqi_rules.dart';
import '../../core/fen.dart';
import '../../core/logger.dart';
// Note: dùng trực tiếp PikafishEngine như trước để không ảnh hưởng cách gọi
import '../../services/game_status_service.dart';
import '../../widgets/game_notification.dart';
import '../../services/saved_games_service.dart';
import '../../models/saved_game.dart';

class ArrowData {
  final Offset from;
  final Offset to;
  final int scoreCp;

  const ArrowData({
    required this.from,
    required this.to,
    required this.scoreCp,
  });
}

class BestLine {
  final int index;
  final int depth;
  final int scoreCp;
  final List<String> pv;

  BestLine({
    required this.index,
    required this.depth,
    required this.scoreCp,
    required this.pv,
  });

  String get firstMove => pv.isNotEmpty ? pv.first : '';
  String get scoreString => scoreCp >= 0 ? '+$scoreCp' : '$scoreCp';
}

class MoveAnimation {
  final int fromFile;
  final int fromRank;
  final int toFile;
  final int toRank;
  final String piece;
  final String moveUci;
  final bool isEngineMove; // true if this is an engine move

  const MoveAnimation({
    required this.fromFile,
    required this.fromRank,
    required this.toFile,
    required this.toRank,
    required this.piece,
    required this.moveUci,
    this.isEngineMove = false,
  });
}

class BoardState {
  final String fen;
  final List<String> moves; // history in UCI-like coord
  final int pointer; // current index in history
  final bool redToMove;
  final List<BestLine> bestLines;
  final int multiPv; // 1..3
  final int analysisDepth; // 1..20 for engine analysis depth
  final bool canBack;
  final bool canNext;
  final String? selectedEngine;
  final bool isEngineThinking;
  final String? engineError; // last engine error message to display
  final String? enginePath; // resolved engine path for diagnostics
  final bool isInCheck;
  final bool isCheckmate;
  final bool isStalemate;
  final String? gameWinner; // 'red', 'black', 'draw', or null
  final bool isVsEngineMode;
  final String? vsEngineDifficulty; // 'easy', 'medium', 'hard'
  final bool isReplayMode;
  final int replayDelayMs;
  final bool isSetupMode;
  final Map<String, int> setupPieces; // piece symbol -> count available
  final String? selectedSetupPiece; // currently selected piece for placement
  final List<String> setupMoveHistory; // FEN history for undo/redo
  final int setupMoveHistoryPointer; // current position in setup history
  final Offset? arrowFrom;
  final Offset? arrowTo;
  final List<ArrowData> arrows; // all arrows from MultiPV results
  final bool boardLocked; // khóa bàn cờ khi ván đã kết thúc
  final int? selectedFile;
  final int? selectedRank;
  final List<Offset> possibleMoves; // possible moves for selected piece
  final MoveAnimation? pendingAnimation; // animation in progress
  final bool isEngineTurn; // true if it's engine's turn in vs engine mode
  final String? setupFen; // FEN for setup mode
  final bool isRedAtBottom; // true if red pieces are at bottom, false if black
  final bool analyzing;
  final String? error;
  final int engineMoveCount; // Count of engine moves for easy mode logic

  const BoardState({
    this.fen = defaultXqFen,
    this.moves = const [],
    this.pointer = 0,
    this.redToMove = true,
    this.bestLines = const [],
    this.multiPv = 1,
    this.analysisDepth = 8,
    this.canBack = false,
    this.canNext = false,
    this.selectedEngine,
    this.isEngineThinking = false,
    this.engineError,
    this.enginePath,
    this.isInCheck = false,
    this.isCheckmate = false,
    this.isStalemate = false,
    this.gameWinner,
    this.isVsEngineMode = false,
    this.vsEngineDifficulty,
    this.isReplayMode = false,
    this.replayDelayMs = 1000,
    this.isSetupMode = false,
    this.setupPieces = const {},
    this.selectedSetupPiece,
    this.setupMoveHistory = const [],
    this.setupMoveHistoryPointer = 0,
    this.arrowFrom,
    this.arrowTo,
    this.arrows = const <ArrowData>[],
    this.boardLocked = false, // khóa bàn cờ khi ván đã kết thúc
    this.selectedFile,
    this.selectedRank,
    this.possibleMoves = const [],
    this.pendingAnimation,
    this.isEngineTurn = false,
    this.setupFen,
    this.isRedAtBottom = true, // default: red at bottom
    this.analyzing = false,
    this.error,
    this.engineMoveCount = 0,
  });

  BoardState copyWith({
    String? fen,
    List<String>? moves,
    int? pointer,
    bool? redToMove,
    List<BestLine>? bestLines,
    int? multiPv,
    int? analysisDepth,
    bool? canBack,
    bool? canNext,
    String? selectedEngine,
    bool? isEngineThinking,
    String? engineError,
    String? enginePath,
    bool? isInCheck,
    bool? isCheckmate,
    bool? isStalemate,
    String? gameWinner,
    bool? isVsEngineMode,
    String? vsEngineDifficulty,
    bool? isReplayMode,
    int? replayDelayMs,
    bool? isSetupMode,
    Map<String, int>? setupPieces,
    String? selectedSetupPiece,
    List<String>? setupMoveHistory,
    int? setupMoveHistoryPointer,
    Offset? arrowFrom,
    Offset? arrowTo,
    List<ArrowData>? arrows,
    bool? boardLocked,
    int? selectedFile,
    int? selectedRank,
    List<Offset>? possibleMoves,
    MoveAnimation? pendingAnimation,
    bool? isEngineTurn,
    String? setupFen,
    bool? isRedAtBottom,
    bool? analyzing,
    String? error,
    int? engineMoveCount,
    bool clearPendingAnimation = false,
  }) {
    return BoardState(
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      pointer: pointer ?? this.pointer,
      redToMove: redToMove ?? this.redToMove,
      bestLines: bestLines ?? this.bestLines,
      multiPv: multiPv ?? this.multiPv,
      analysisDepth: analysisDepth ?? this.analysisDepth,
      canBack: canBack ?? this.canBack,
      canNext: canNext ?? this.canNext,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      isEngineThinking: isEngineThinking ?? this.isEngineThinking,
      engineError: engineError,
      enginePath: enginePath ?? this.enginePath,
      isInCheck: isInCheck ?? this.isInCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
      isStalemate: isStalemate ?? this.isStalemate,
      gameWinner: gameWinner,
      isVsEngineMode: isVsEngineMode ?? this.isVsEngineMode,
      vsEngineDifficulty: vsEngineDifficulty ?? this.vsEngineDifficulty,
      isReplayMode: isReplayMode ?? this.isReplayMode,
      replayDelayMs: replayDelayMs ?? this.replayDelayMs,
      isSetupMode: isSetupMode ?? this.isSetupMode,
      setupPieces: setupPieces ?? this.setupPieces,
      selectedSetupPiece: selectedSetupPiece ?? this.selectedSetupPiece,
      setupMoveHistory: setupMoveHistory ?? this.setupMoveHistory,
      setupMoveHistoryPointer:
          setupMoveHistoryPointer ?? this.setupMoveHistoryPointer,
      arrowFrom: arrowFrom,
      arrowTo: arrowTo,
      arrows: arrows ?? this.arrows,
      boardLocked: boardLocked ?? this.boardLocked,
      selectedFile: selectedFile ?? this.selectedFile,
      selectedRank: selectedRank ?? this.selectedRank,
      possibleMoves: possibleMoves ?? this.possibleMoves,
      pendingAnimation: clearPendingAnimation
          ? null
          : (pendingAnimation ?? this.pendingAnimation),
      isEngineTurn: isEngineTurn ?? this.isEngineTurn,
      setupFen: setupFen ?? this.setupFen,
      isRedAtBottom: isRedAtBottom ?? this.isRedAtBottom,
      analyzing: analyzing ?? this.analyzing,
      error: error,
      engineMoveCount: engineMoveCount ?? this.engineMoveCount,
    );
  }
}

class BoardController extends StateNotifier<BoardState> {
  PikafishEngine? _engine;
  Timer? _vsEngineTimer;
  Timer? _replayTimer;
  Timer? _animationAutoCommit;
  Timer? _animationWatchdog;
  Timer? _checkmateTimeoutTimer;
  int _replayIndex = 0;
  int _analysisSeq = 0; // Token để chống chồng lấp phân tích
  List<String> _replayMoves = [];
  String? _recentAppliedMove;
  DateTime? _recentAppliedAt;

  BoardController() : super(const BoardState());

  Future<void> init() async {
    try {
      await AppLogger.ensureInitialized();
      AppLogger().log('BoardController initialized');
    } catch (e) {
      AppLogger().error('Failed to initialize BoardController', e);
    }
  }

  // Giữ nguyên lối gọi cũ: không switch engine động, chỉ dùng PikafishEngine được set từ ngoài

  // Board interaction logic from flutter_application_window
  void onBoardTap(int file, int rank) {
    AppLogger().log(
      'onBoardTap called: file=$file, rank=$rank, engine=${_engine != null}',
    );

    // NEW: chặn toàn bộ tương tác nếu bàn cờ đã khóa
    if (state.boardLocked) {
      AppLogger().log('Board locked - ignoring tap');
      return;
    }

    if (_engine == null) {
      AppLogger().log('Engine is null, cannot process board tap');
      return;
    }

    AppLogger().log('Board tapped at file: $file, rank: $rank');

    final board = FenParser.parseBoard(state.fen);
    final piece = board[rank][file];

    // If no piece is selected, try to select a piece
    if (state.selectedFile == null || state.selectedRank == null) {
      if (piece.isNotEmpty) {
        // Check if it's the correct side to move based on FEN
        final isRedPiece = piece == piece.toUpperCase();
        final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
        AppLogger().log(
          'Select attempt piece=$piece isRed=$isRedPiece canSelect=${(isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)}',
        );
        if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
          // Select the piece and calculate possible moves
          final possibleMoves = _calculatePossibleMoves(file, rank, board);
          AppLogger().log(
            'Selected piece. possibleMoves=${possibleMoves.length}',
          );
      state = state.copyWith(
        selectedFile: file,
        selectedRank: rank,
        possibleMoves: possibleMoves,
            // Không ẩn mũi tên khi chọn quân
      );
        }
      }
    } else {
      // A piece is already selected
      final selectedFile = state.selectedFile!;
      final selectedRank = state.selectedRank!;

      // Check if clicking on the same piece - allow reselection
      if (file == selectedFile && rank == selectedRank) {
        // Allow reselecting the same piece to refresh possible moves
        final possibleMoves = _calculatePossibleMoves(file, rank, board);
        AppLogger().log('Reselected same piece. Refreshing possible moves.');
        state = state.copyWith(
          selectedFile: file,
          selectedRank: rank,
          possibleMoves: possibleMoves,
          // Không ẩn mũi tên khi chọn quân
        );
        return;
      }

      // If for some reason there are no possible moves cached (e.g. state
      // reset after turn switch), treat this tap as a new selection attempt
      if (state.possibleMoves.isEmpty) {
        if (piece.isNotEmpty) {
          final isRedPiece = piece == piece.toUpperCase();
          final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
          if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
            final possibleMoves = _calculatePossibleMoves(file, rank, board);
            state = state.copyWith(
              selectedFile: file,
              selectedRank: rank,
              possibleMoves: possibleMoves,
              // Không ẩn mũi tên khi chọn quân
            );
          }
        }
        return;
      }

      // Allow move if the click is near one of possible moves (tolerance)
        final click = Offset(file.toDouble(), rank.toDouble());
        Offset? chosen;
        double best = 1e9;
        for (final m in state.possibleMoves) {
          final d = (m.dx - click.dx).abs() + (m.dy - click.dy).abs();
          if (d < best) {
            best = d;
            chosen = m;
          }
        }
      // Accept if within ~0.3 cell from a legal destination (more precise touch area)
      if (chosen == null || best > 0.3) {
        // Not near any legal destination
        AppLogger().log(
          'No near legal destination. best=$best, pmCount=${state.possibleMoves.length}.',
        );

        // Only try to select different piece if clicking on a piece
        if (piece.isNotEmpty) {
          final isRedPiece = piece == piece.toUpperCase();
          final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';

          // Only allow selecting piece of the same side to move
          if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
            final possibleMoves = _calculatePossibleMoves(file, rank, board);
            AppLogger().log(
              'Selected different piece of same side. possibleMoves=${possibleMoves.length}',
            );
            state = state.copyWith(
              selectedFile: file,
              selectedRank: rank,
              possibleMoves: possibleMoves,
              arrows: const <ArrowData>[], // Ẩn mũi tên khi bắt đầu chọn quân
            );
          } else {
            // Clicked on opponent piece or wrong side, deselect current piece
            AppLogger().log(
              'Clicked on opponent piece or wrong side. Deselect current piece.',
            );
            state = state.copyWith(
              selectedFile: null,
              selectedRank: null,
              possibleMoves: [],
            );
          }
        } else {
          // Clicked on empty square, deselect
          AppLogger().log('Clicked empty square. Deselect.');
          state = state.copyWith(
            selectedFile: null,
            selectedRank: null,
            possibleMoves: [],
          );
        }
        return;
      }

          final snappedToFile = chosen.dx.round();
          final snappedToRank = chosen.dy.round();
          final moveUci = _fileRankToUci(
            selectedFile,
            selectedRank,
            snappedToFile,
            snappedToRank,
          );
      AppLogger().log('Attempt move: $moveUci');
      if (XiangqiRules.isValidMove(state.fen, moveUci)) {
        // Queue animation first; BoardView will commit and then we apply
        final board = FenParser.parseBoard(state.fen);
        final piece = board[selectedRank][selectedFile];
          state = state.copyWith(
            pendingAnimation: MoveAnimation(
              fromFile: selectedFile,
              fromRank: selectedRank,
              toFile: snappedToFile,
              toRank: snappedToRank,
              piece: piece,
              moveUci: moveUci,
            isEngineMove: false, // Player move
            ),
          // Clear selection immediately when move is confirmed
            selectedFile: null,
            selectedRank: null,
            possibleMoves: [],
          // ✨ Ẩn toàn bộ mũi tên ngay khi người chơi click ô đích
          arrows: const <ArrowData>[],
        );
        AppLogger().log('Move queued for animation.');
        // Failsafe: auto-commit after animation duration in case the
        // widget callback is skipped due to rebuilds
        _animationAutoCommit?.cancel();
        _animationAutoCommit = Timer(const Duration(milliseconds: 80), () {
          if (state.pendingAnimation != null) {
            AppLogger().log('Auto-commit animated move (failsafe)');
            commitAnimatedMove();
          }
        });
        // Additional watchdog: force clear if animation is stuck for too long
        _animationWatchdog?.cancel();
        _animationWatchdog = Timer(const Duration(milliseconds: 1000), () {
          if (state.pendingAnimation != null) {
            AppLogger().log(
              'Animation watchdog: force clearing stuck animation',
            );
            state = state.copyWith(pendingAnimation: null);
          }
        });
      }
    }
  }

  // Helper methods for board interaction
  List<Offset> _calculatePossibleMoves(
    int file,
    int rank,
    List<List<String>> board,
  ) {
    final piece = board[rank][file];
    if (piece.isEmpty) return [];

    final pieceType = piece.toLowerCase();
    final possibleMoves = <Offset>[];

    switch (pieceType) {
      case 'r': // Chariot
        possibleMoves.addAll(_getChariotMoves(board, file, rank, piece));
        break;
      case 'h': // Horse
        possibleMoves.addAll(_getHorseMoves(board, file, rank, piece));
        break;
      case 'e': // Elephant
        possibleMoves.addAll(_getElephantMoves(board, file, rank, piece));
        break;
      case 'a': // Advisor
        possibleMoves.addAll(_getAdvisorMoves(board, file, rank, piece));
        break;
      case 'k': // King
        possibleMoves.addAll(_getKingMoves(board, file, rank, piece));
        break;
      case 'c': // Cannon
        possibleMoves.addAll(_getCannonMoves(board, file, rank, piece));
        break;
      case 'p': // Pawn
        possibleMoves.addAll(_getPawnMoves(board, file, rank, piece));
        break;
    }

    return possibleMoves;
  }

  List<Offset> _getChariotMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // Vertical moves
    for (int r = rank - 1; r >= 0; r--) {
      if (board[r][file].isEmpty) {
        moves.add(Offset(file.toDouble(), r.toDouble()));
      } else {
        final targetPiece = board[r][file];
        final isTargetRed = targetPiece == targetPiece.toUpperCase();
        if (isRedPiece != isTargetRed) {
          moves.add(Offset(file.toDouble(), r.toDouble()));
        }
        break;
      }
    }
    for (int r = rank + 1; r < 10; r++) {
      if (board[r][file].isEmpty) {
        moves.add(Offset(file.toDouble(), r.toDouble()));
      } else {
        final targetPiece = board[r][file];
        final isTargetRed = targetPiece == targetPiece.toUpperCase();
        if (isRedPiece != isTargetRed) {
          moves.add(Offset(file.toDouble(), r.toDouble()));
        }
        break;
      }
    }

    // Horizontal moves
    for (int f = file - 1; f >= 0; f--) {
      if (board[rank][f].isEmpty) {
        moves.add(Offset(f.toDouble(), rank.toDouble()));
      } else {
        final targetPiece = board[rank][f];
        final isTargetRed = targetPiece == targetPiece.toUpperCase();
        if (isRedPiece != isTargetRed) {
          moves.add(Offset(f.toDouble(), rank.toDouble()));
        }
        break;
      }
    }
    for (int f = file + 1; f < 9; f++) {
      if (board[rank][f].isEmpty) {
        moves.add(Offset(f.toDouble(), rank.toDouble()));
      } else {
        final targetPiece = board[rank][f];
        final isTargetRed = targetPiece == targetPiece.toUpperCase();
        if (isRedPiece != isTargetRed) {
          moves.add(Offset(f.toDouble(), rank.toDouble()));
        }
        break;
      }
    }

    return moves;
  }

  List<Offset> _getHorseMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // Horse moves in L-shape: 2 squares in one direction, then 1 square perpendicular
    final horseMoves = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];

    for (final move in horseMoves) {
      final toRank = rank + move[0];
      final toFile = file + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check if horse leg is blocked
      int legRank, legFile;
      if (move[0].abs() == 2) {
        legRank = rank + (move[0] > 0 ? 1 : -1);
        legFile = file;
      } else {
        legRank = rank;
        legFile = file + (move[1] > 0 ? 1 : -1);
      }

      if (board[legRank][legFile].isNotEmpty) continue; // Leg is blocked

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isEmpty ||
          (isRedPiece != (toPiece == toPiece.toUpperCase()))) {
        moves.add(Offset(toFile.toDouble(), toRank.toDouble()));
      }
    }

    return moves;
  }

  List<Offset> _getElephantMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // Elephant moves diagonally 2 squares, cannot cross river
    final elephantMoves = [
      [-2, -2],
      [-2, 2],
      [2, -2],
      [2, 2],
    ];

    for (final move in elephantMoves) {
      final toRank = rank + move[0];
      final toFile = file + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check river crossing
      if (isRedPiece && toRank < 5) continue; // Red can't cross river
      if (!isRedPiece && toRank > 4) continue; // Black can't cross river

      // Check if blocking piece exists (elephant can't jump)
      final blockRank = rank + move[0] ~/ 2;
      final blockFile = file + move[1] ~/ 2;
      if (board[blockRank][blockFile].isNotEmpty) continue;

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isEmpty ||
          (isRedPiece != (toPiece == toPiece.toUpperCase()))) {
        moves.add(Offset(toFile.toDouble(), toRank.toDouble()));
      }
    }

    return moves;
  }

  List<Offset> _getAdvisorMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // Advisor moves diagonally 1 square, stays in palace
    final advisorMoves = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];

    for (final move in advisorMoves) {
      final toRank = rank + move[0];
      final toFile = file + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check if stays in palace
      if (isRedPiece) {
        if (toRank < 7 || toFile < 3 || toFile > 5) continue;
      } else {
        if (toRank > 2 || toFile < 3 || toFile > 5) continue;
      }

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isEmpty ||
          (isRedPiece != (toPiece == toPiece.toUpperCase()))) {
        moves.add(Offset(toFile.toDouble(), toRank.toDouble()));
      }
    }

    return moves;
  }

  List<Offset> _getKingMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // King moves 1 square horizontally or vertically, stays in palace
    final kingMoves = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    for (final move in kingMoves) {
      final toRank = rank + move[0];
      final toFile = file + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check if stays in palace
      if (isRedPiece) {
        if (toRank < 7 || toFile < 3 || toFile > 5) continue;
      } else {
        if (toRank > 2 || toFile < 3 || toFile > 5) continue;
      }

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isEmpty ||
          (isRedPiece != (toPiece == toPiece.toUpperCase()))) {
        moves.add(Offset(toFile.toDouble(), toRank.toDouble()));
      }
    }

    return moves;
  }

  List<Offset> _getCannonMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    // Vertical moves
    bool hasJumped = false;
    for (int r = rank - 1; r >= 0; r--) {
      if (board[r][file].isEmpty) {
        if (!hasJumped) {
          moves.add(Offset(file.toDouble(), r.toDouble()));
        }
      } else {
        if (!hasJumped) {
          hasJumped = true;
        } else {
          final targetPiece = board[r][file];
          final isTargetRed = targetPiece == targetPiece.toUpperCase();
          if (isRedPiece != isTargetRed) {
            moves.add(Offset(file.toDouble(), r.toDouble()));
          }
          break;
        }
      }
    }

    hasJumped = false;
    for (int r = rank + 1; r < 10; r++) {
      if (board[r][file].isEmpty) {
        if (!hasJumped) {
          moves.add(Offset(file.toDouble(), r.toDouble()));
        }
      } else {
        if (!hasJumped) {
          hasJumped = true;
        } else {
          final targetPiece = board[r][file];
          final isTargetRed = targetPiece == targetPiece.toUpperCase();
          if (isRedPiece != isTargetRed) {
            moves.add(Offset(file.toDouble(), r.toDouble()));
          }
          break;
        }
      }
    }

    // Horizontal moves
    hasJumped = false;
    for (int f = file - 1; f >= 0; f--) {
      if (board[rank][f].isEmpty) {
        if (!hasJumped) {
          moves.add(Offset(f.toDouble(), rank.toDouble()));
        }
      } else {
        if (!hasJumped) {
          hasJumped = true;
        } else {
          final targetPiece = board[rank][f];
          final isTargetRed = targetPiece == targetPiece.toUpperCase();
          if (isRedPiece != isTargetRed) {
            moves.add(Offset(f.toDouble(), rank.toDouble()));
          }
          break;
        }
      }
    }

    hasJumped = false;
    for (int f = file + 1; f < 9; f++) {
      if (board[rank][f].isEmpty) {
        if (!hasJumped) {
          moves.add(Offset(f.toDouble(), rank.toDouble()));
        }
      } else {
        if (!hasJumped) {
          hasJumped = true;
        } else {
          final targetPiece = board[rank][f];
          final isTargetRed = targetPiece == targetPiece.toUpperCase();
          if (isRedPiece != isTargetRed) {
            moves.add(Offset(f.toDouble(), rank.toDouble()));
          }
          break;
        }
      }
    }

    return moves;
  }

  List<Offset> _getPawnMoves(
    List<List<String>> board,
    int file,
    int rank,
    String piece,
  ) {
    final moves = <Offset>[];
    final isRedPiece = piece == piece.toUpperCase();

    if (isRedPiece) {
      // Red pawn moves UP (decreasing rank numbers)
      final hasCrossedRiver = rank <= 4; // Red pawn crossed river

      if (hasCrossedRiver) {
        // After crossing river: can move forward (UP) OR sideways
        // Forward (UP)
        if (rank > 0) {
          final toPiece = board[rank - 1][file];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add(Offset(file.toDouble(), (rank - 1).toDouble()));
          }
        }
        // Sideways
        if (file > 0) {
          final toPiece = board[rank][file - 1];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add(Offset((file - 1).toDouble(), rank.toDouble()));
          }
        }
        if (file < 8) {
          final toPiece = board[rank][file + 1];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add(Offset((file + 1).toDouble(), rank.toDouble()));
          }
        }
      } else {
        // Before crossing river: can ONLY move forward (UP)
        if (rank > 0) {
          final toPiece = board[rank - 1][file];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add(Offset(file.toDouble(), (rank - 1).toDouble()));
          }
        }
      }
    } else {
      // Black pawn moves DOWN (increasing rank numbers)
      final hasCrossedRiver = rank >= 5; // Black pawn crossed river

      if (hasCrossedRiver) {
        // After crossing river: can move forward (DOWN) OR sideways
        // Forward (DOWN)
        if (rank < 9) {
          final toPiece = board[rank + 1][file];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add(Offset(file.toDouble(), (rank + 1).toDouble()));
          }
        }
        // Sideways
        if (file > 0) {
          final toPiece = board[rank][file - 1];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add(Offset((file - 1).toDouble(), rank.toDouble()));
          }
        }
        if (file < 8) {
          final toPiece = board[rank][file + 1];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add(Offset((file + 1).toDouble(), rank.toDouble()));
          }
        }
      } else {
        // Before crossing river: can ONLY move forward (DOWN)
        if (rank < 9) {
          final toPiece = board[rank + 1][file];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add(Offset(file.toDouble(), (rank + 1).toDouble()));
          }
        }
      }
    }

    return moves;
  }

  String _fileRankToUci(int fromFile, int fromRank, int toFile, int toRank) {
    // Convert board coordinates to UCI notation
    final fromFileUci = String.fromCharCode(97 + fromFile); // a=0, b=1, etc.
    final fromRankUci = 9 - fromRank; // Convert to UCI rank (0=bottom, 9=top)
    final toFileUci = String.fromCharCode(97 + toFile);
    final toRankUci = 9 - toRank;
    return '$fromFileUci$fromRankUci$toFileUci$toRankUci';
  }

  void _scheduleNextEngineMove() {
    if (!state.isVsEngineMode || state.gameWinner != null) return;

    // Schedule engine move based on difficulty
    int delayMs = 300; // giảm từ 500ms
    switch (state.vsEngineDifficulty) {
      case 'easy':
        delayMs = 500; // giảm từ 800ms
        break;
      case 'medium':
        delayMs = 400; // giảm từ 600ms
        break;
      case 'hard':
        delayMs = 250; // giảm từ 400ms
        break;
    }

    _vsEngineTimer?.cancel();
    _vsEngineTimer = Timer(Duration(milliseconds: delayMs), () {
      if (state.isVsEngineMode && state.gameWinner == null) {
        _engineTurn();
      }
    });
  }

  // Unified engine turn logic that respects difficulty setting
  Future<void> _engineTurn() async {
    if (_engine == null || !state.isVsEngineMode || state.gameWinner != null) {
      return;
    }

    // Guard: Chỉ chạy nếu FEN cho thấy đang là lượt của máy (máy = bên đen trong app)
    final sideToMove = FenParser.getSideToMove(state.fen); // 'w'|'b'
    final engineToMove = (sideToMove == 'b');
    if (!engineToMove) {
      AppLogger().log(
        'Engine turn skipped - not engine\'s turn (sideToMove: $sideToMove)',
      );
      return;
    }

    try {
      AppLogger().log(
        'Engine turn with difficulty: ${state.vsEngineDifficulty}',
      );

      final startedAt = DateTime.now(); // Bắt đầu đo thời gian nghĩ

      // Số lượng nước cần phân tích - chỉ dùng MultiPV = 2 khi đánh với máy
      final engineMultiPv = state.isVsEngineMode ? 2 : 1;

      // Đồng bộ MultiPV của engine riêng cho lượt máy (không đụng UI)
      await _engine!.setMultiPV(engineMultiPv);
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Thay thế waitReady

      // Phân tích vị trí hiện tại để có bestLines mới (depth 8 cho máy)
      await analyzeTopMoves(
        engine: _engine!,
        fen: _isFromStartpos() ? 'startpos' : state.setupFen!,
        depth: 8, // Fixed depth 8 for engine moves
        numMoves: engineMultiPv,
        moves: currentMoves(),
      );

      if (state.bestLines.isEmpty) {
        // fallback chắc chắn: best move (depth 8 cho máy)
        final bestMove = await _engine!.getBestMove(
          _isFromStartpos() ? 'startpos' : state.setupFen!,
          8, // Fixed depth 8 for engine moves
        );
        // Guard cuối: chỉ đi nếu vẫn tới lượt máy & nước hợp lệ
        if (bestMove.isNotEmpty &&
            bestMove != 'null' &&
            FenParser.getSideToMove(state.fen) == 'b' &&
            XiangqiRules.isValidMove(state.fen, bestMove)) {
          await _applyEngineMove(bestMove);
        }

        // Thời gian nghĩ tối thiểu cho fallback case
        final elapsed = DateTime.now().difference(startedAt);
        final minThink = const Duration(milliseconds: 150); // giảm từ 250ms
        if (elapsed < minThink) {
          AppLogger().log(
            'Engine fallback thinking too fast (${elapsed.inMilliseconds}ms), waiting ${(minThink - elapsed).inMilliseconds}ms more',
          );
          await Future.delayed(minThink - elapsed);
        }
        return;
      }

      // Chọn nước theo độ khó
      final pick = _selectEngineMove(state.bestLines);
      // Guard cuối: chỉ đi nếu vẫn tới lượt máy & nước hợp lệ
      if (pick.isNotEmpty &&
          pick != 'null' &&
          FenParser.getSideToMove(state.fen) == 'b' &&
          XiangqiRules.isValidMove(state.fen, pick)) {
        await _applyEngineMove(pick);
      } else {
        // Không có nước đi hợp lệ - game đã kết thúc
        AppLogger().log('Engine turn: No valid moves available - game ended');
        // Không cần làm gì thêm vì _checkGameStatusForNoMoves đã xử lý thông báo
      }

      // Thời gian nghĩ tối thiểu để tránh cảm giác "đi ngay"
      final elapsed = DateTime.now().difference(startedAt);
      final minThink = const Duration(milliseconds: 250);
      if (elapsed < minThink) {
        AppLogger().log(
          'Engine thinking too fast (${elapsed.inMilliseconds}ms), waiting ${(minThink - elapsed).inMilliseconds}ms more',
        );
        await Future.delayed(minThink - elapsed);
      }
    } catch (e) {
      AppLogger().error('Engine turn failed', e);
    }
  }

  // Select engine move based on difficulty
  String _selectEngineMove(List<BestLine> bestLines) {
    if (bestLines.isEmpty) {
      AppLogger().log(
        'No best moves available - checking for checkmate/stalemate',
      );
      // Cancel any existing timeout timer
      _checkmateTimeoutTimer?.cancel();

      // Set timeout to check for checkmate after 1 second
      _checkmateTimeoutTimer = Timer(const Duration(milliseconds: 500), () {
        AppLogger().log('Checkmate timeout triggered - checking game status');
        _checkGameStatusForNoMoves();
      });

    return '';
  }

    // Cancel timeout if we got best moves
    _checkmateTimeoutTimer?.cancel();
    _checkmateTimeoutTimer = null;

    final difficulty = state.vsEngineDifficulty ?? 'hard';
    AppLogger().log('Selecting move for difficulty: $difficulty');

    switch (difficulty) {
      case 'easy':
        return _selectEasyMove(bestLines);
      case 'medium':
        return _selectMediumMove(bestLines);
      case 'hard':
      default:
        return _selectHardMove(bestLines);
    }
  }

  // Easy: Random valid move, but every 2 moves use best move, and always use best move when in check
  String _selectEasyMove(List<BestLine> bestLines) {
    // ✅ tính trực tiếp từ FEN hiện tại để chắc chắn
    final inCheckNow = GameStatusService.isInCheck(state.fen);
    if (inCheckNow) {
      AppLogger().log('Easy mode: In check, using best move for defense');
      return bestLines.first.firstMove;
    }

    // Every 2 engine moves, use the best move
    if (state.engineMoveCount % 2 == 0) {
      AppLogger().log('Easy mode: Every 2nd engine move, using best move');
      return bestLines.first.firstMove;
    } else {
      // For random moves, get all legal moves and choose randomly
      final allLegalMoves = XiangqiRules.getAllLegalMoves(state.fen);
      if (allLegalMoves.isNotEmpty) {
        // Remove best moves from legal moves to get truly random moves
        final bestMoves = bestLines.map((line) => line.firstMove).toSet();
        final randomMoves = allLegalMoves
            .where((move) => !bestMoves.contains(move))
            .toList();

        if (randomMoves.isNotEmpty) {
          final randomIndex =
              DateTime.now().millisecondsSinceEpoch % randomMoves.length;
          final randomMove = randomMoves[randomIndex];
          AppLogger().log(
            'Easy mode: Using truly random move (not in best moves)',
          );
          return randomMove;
        } else {
          // Fallback to any legal move if all moves are best moves
          final randomIndex =
              DateTime.now().millisecondsSinceEpoch % allLegalMoves.length;
          final randomMove = allLegalMoves[randomIndex];
          AppLogger().log('Easy mode: Using random legal move (fallback)');
          return randomMove;
        }
      } else {
        // Không có nước đi hợp lệ nào - có thể là chiếu hết hoặc bí cờ
        AppLogger().log(
          'Easy mode: No legal moves found - checking for checkmate/stalemate',
        );
        _checkGameStatusForNoMoves();
        return '';
      }
    }
  }

  // Medium: Use lower scoring best move
  String _selectMediumMove(List<BestLine> bestLines) {
    // Kiểm tra nước đi hợp lệ trước
    final allLegalMoves = XiangqiRules.getAllLegalMoves(state.fen);
    if (allLegalMoves.isEmpty) {
      AppLogger().log(
        'Medium mode: No legal moves found - checking for checkmate/stalemate',
      );
      _checkGameStatusForNoMoves();
      return '';
    }

    if (bestLines.length >= 2) {
      // Use the move with lower score (worse move)
      final move1 = bestLines[0];
      final move2 = bestLines[1];
      final selectedMove = move1.scoreCp < move2.scoreCp
          ? move1.firstMove
          : move2.firstMove;
      AppLogger().log(
        'Medium mode: Using lower scoring move (${move1.scoreCp} vs ${move2.scoreCp})',
      );
      return selectedMove;
    } else {
      // Fallback to first move
      return bestLines.first.firstMove;
    }
  }

  // Hard: Use highest scoring best move
  String _selectHardMove(List<BestLine> bestLines) {
    // Kiểm tra nước đi hợp lệ trước
    final allLegalMoves = XiangqiRules.getAllLegalMoves(state.fen);
    if (allLegalMoves.isEmpty) {
      AppLogger().log(
        'Hard mode: No legal moves found - checking for checkmate/stalemate',
      );
      _checkGameStatusForNoMoves();
      return '';
    }

    // Use the best move (highest score)
    final selectedMove = bestLines.first.firstMove;
    AppLogger().log(
      'Hard mode: Using best move (score: ${bestLines.first.scoreCp})',
    );
    return selectedMove;
  }

  // Apply engine move with animation
  Future<void> _applyEngineMove(String moveUci) async {
    if (moveUci.isEmpty || moveUci == 'null') return;

    // Validate move
    if (!XiangqiRules.isValidMove(state.fen, moveUci)) {
      AppLogger().error('Invalid engine move', moveUci);
      return;
    }

    // Parse move to get from/to coordinates
    final fromFile = moveUci.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toFile = moveUci.codeUnitAt(2) - 'a'.codeUnitAt(0);

    // ✅ UCI rank 0..9 ⇒ rank trên bảng = 9 - uciRank
    final fromRankUci = int.parse(moveUci[1]);
    final toRankUci = int.parse(moveUci[3]);
    final fromRank = 9 - fromRankUci;
    final toRank = 9 - toRankUci;

    // Get piece from current board
    final board = FenParser.parseBoard(state.fen);
    final piece = board[fromRank][fromFile];

    // Create animation for engine move
    state = state.copyWith(
      pendingAnimation: MoveAnimation(
        fromFile: fromFile,
        fromRank: fromRank,
        toFile: toFile,
        toRank: toRank,
        piece: piece,
        moveUci: moveUci,
        isEngineMove: true, // Engine move
      ),
    );

    AppLogger().log('Engine move queued for animation: $moveUci');

    // Auto-commit after animation duration
    _animationAutoCommit?.cancel();
    _animationAutoCommit = Timer(const Duration(milliseconds: 80), () {
      if (state.pendingAnimation != null) {
        AppLogger().log('Auto-commit engine animated move (failsafe)');
        commitEngineAnimatedMove();
      }
    });

    // Additional watchdog: force clear if animation is stuck for too long
    _animationWatchdog?.cancel();
    _animationWatchdog = Timer(const Duration(milliseconds: 1000), () {
      if (state.pendingAnimation != null) {
        AppLogger().log(
          'Engine animation watchdog: force clearing stuck animation',
        );
        state = state.copyWith(pendingAnimation: null);
      }
    });
  }

  // Commit engine animated move
  // Flag to prevent re-entrancy in commitEngineAnimatedMove
  bool _committingEngineAnim = false;

  Future<void> commitEngineAnimatedMove() async {
    // ✅ Guard quan trọng: CHẶN TOÀN BỘ nếu không ở vs-engine mode hoặc đang setup
    if (!state.isVsEngineMode || state.isSetupMode) {
      AppLogger().log(
        'BLOCKED: Attempted to commit engine move but not in vs-engine mode or in setup mode',
      );
      state = state.copyWith(pendingAnimation: null);
      return;
    }

    if (_committingEngineAnim) return; // ✅ chống re-entrancy
    final anim = state.pendingAnimation;
    if (anim == null) return;

    _committingEngineAnim = true;
    // ✅ dọn timer để auto-commit không bắn thêm lần nữa
    _animationAutoCommit?.cancel();
    _animationWatchdog?.cancel();

    try {
      // ✅ Nếu nước cuối cùng đã là anim.moveUci thì thôi
      if (state.pointer > 0 && state.moves[state.pointer - 1] == anim.moveUci) {
        state = state.copyWith(pendingAnimation: null);
        return;
      }

      AppLogger().log('Committing engine animated move: ${anim.moveUci}');

      final newMoves = [...state.moves];
      if (state.pointer < newMoves.length) {
        newMoves.removeRange(state.pointer, newMoves.length);
      }
      // Add engine move to history to keep startpos + moves consistent
    newMoves.add(anim.moveUci);

      // Update FEN after the move
      final newFen = FenParser.applyMove(state.fen, anim.moveUci);

    state = state.copyWith(
      fen: newFen,
      moves: newMoves,
        pointer: newMoves.length,
      redToMove: !state.redToMove, // Switch sides
        bestLines: [],
        canBack: newMoves.isNotEmpty,
        canNext: false,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
        isEngineThinking: false,
        isEngineTurn: false, // Switch back to human turn
        engineMoveCount:
            state.engineMoveCount + 1, // Increment engine move count
      );

      // Clear animation after a small delay to prevent flickering
      await Future.delayed(const Duration(milliseconds: 50));
      state = state.copyWith(pendingAnimation: null);

      // Update engine position without waiting for readyok
      try {
        if (_isFromStartpos()) {
          await _engine!.setPosition('startpos', currentMoves());
        } else {
          await _engine!.setPosition(state.setupFen!, currentMoves());
        }
      } catch (e) {
        AppLogger().log('Engine position update failed (non-critical): $e');
        // Don't show error notification for this as it's not critical
      }

      // Check game status
      try {
        await _checkGameStatus();
      } catch (e) {
        AppLogger().error('Game status check failed after engine move', e);
      }

      // Start analysis for human's turn
      final winner = GameStatusService.getWinner(state.fen);
      final isCheckmate = GameStatusService.isCheckmate(state.fen);

      if (!isCheckmate && (winner == null || winner == 'Draw')) {
        await _analyzePosition();
      }
    } finally {
      _committingEngineAnim = false;
    }
  }

  void _showNotification(
    String message, {
    Color? backgroundColor,
    Duration? duration,
  }) {
    AppLogger().log('Notification: $message');
    GameNotificationCenter.show(
      message: message,
      backgroundColor: backgroundColor ?? Colors.red,
      duration: duration ?? const Duration(seconds: 2), // giảm từ 3s
    );
  }

  Future<void> applyMove(String moveUci) async {
    if (_engine == null) return;

    await AppLogger().log('Apply move: $moveUci');

    // Dừng phân tích engine đang chạy khi người dùng đánh ngay
    if (state.isEngineThinking) {
      AppLogger().log('Stopping ongoing engine analysis - user made move');
      try {
        await _engine!.stop(); // Dừng phân tích hiện tại
        await Future.delayed(
          const Duration(milliseconds: 30), // giảm từ 50ms
        ); // Thay thế waitReady
      } catch (e) {
        AppLogger().log('Error stopping engine analysis: $e');
      }
      state = state.copyWith(isEngineThinking: false);
    }

    // Hard de-dup: if the last committed move equals the incoming move, ignore
    if (state.pointer > 0 && state.moves[state.pointer - 1] == moveUci) {
      await AppLogger().log('Skip apply - duplicate of last move: $moveUci');
      return;
    }

    // Deduplicate quick double commits
    final now = DateTime.now();
    if (_recentAppliedMove == moveUci &&
        _recentAppliedAt != null &&
        now.difference(_recentAppliedAt!).inMilliseconds < 800) {
      await AppLogger().log('Skip duplicate apply for: $moveUci');
      return;
    }
    _recentAppliedMove = moveUci;
    _recentAppliedAt = now;

    // Validate move
    if (!XiangqiRules.isValidMove(state.fen, moveUci)) {
      print('Invalid move: $moveUci');
      await AppLogger().error('Invalid move', moveUci);
      return;
    }

    final newMoves = [...state.moves];
    if (state.pointer < newMoves.length) {
      newMoves.removeRange(state.pointer, newMoves.length);
    }
    newMoves.add(moveUci);

    // Update FEN after the move
    final newFen = FenParser.applyMove(state.fen, moveUci);

    // Store current animation before clearing
    final hadAnimation = state.pendingAnimation != null;

    state = state.copyWith(
      fen: newFen,
      moves: newMoves,
      pointer: newMoves.length,
      redToMove: !state.redToMove, // Switch sides
      bestLines: [],
      canBack: newMoves.isNotEmpty,
      canNext: false,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      // Keep animation until FEN is fully applied if we had one
      pendingAnimation: hadAnimation ? state.pendingAnimation : null,
      isEngineThinking: false,
    );

    // Set position FIRST - use startpos or original setupFen, not current fen
    if (_isFromStartpos()) {
      await _engine!.setPosition('startpos', currentMoves());
      } else {
      await _engine!.setPosition(state.setupFen!, currentMoves());
    }
    await Future.delayed(
      const Duration(milliseconds: 30), // giảm từ 50ms
    ); // Thay thế waitReady

    // Only NOW clear animation after everything is set
    if (hadAnimation) {
      state = state.copyWith(pendingAnimation: null);
    }

    // ALWAYS check game status after applying a move
    try {
      await AppLogger().log('=== CHECKING GAME STATUS AFTER MOVE ===');
      await _checkGameStatus();
      await AppLogger().log('=== GAME STATUS CHECK COMPLETED ===');
    } catch (e, stackTrace) {
      await AppLogger().error(
        'CRITICAL: _checkGameStatus failed',
        e,
        stackTrace,
      );
      // Force show error notification
      _showNotification(
        'ERROR: Could not check game status',
        backgroundColor: Colors.red,
      );
    }

    // Only start analysis if game is not over
    final winner = GameStatusService.getWinner(state.fen);
    final isCheckmate = GameStatusService.isCheckmate(state.fen);

    if (!isCheckmate && (winner == null || winner == 'Draw')) {
      // Game is still ongoing, start analysis
      await _analyzePosition();

      // Check if it's engine's turn in vs engine mode
      if (state.isVsEngineMode) {
        final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
        // Engine plays as Black (red pieces at top, black pieces at bottom)
        final shouldBeEngineTurn = !isRedToMove;

        if (shouldBeEngineTurn && !state.isEngineTurn) {
          // Switch to engine's turn
          state = state.copyWith(isEngineTurn: true);
          AppLogger().log(
            'Switching to engine turn - difficulty: ${state.vsEngineDifficulty}',
          );
          _engineTurn();
        } else if (!shouldBeEngineTurn && state.isEngineTurn) {
          // Switch to human's turn
          state = state.copyWith(isEngineTurn: false);
          AppLogger().log('Switching to human turn');
        }
      }
    }

    // If game is over, stop vs engine mode
    if (winner != null && state.isVsEngineMode) {
      stopVsEngineMode();
    }
  }

  // Helper method to check if game is from initial position
  bool _isFromStartpos() => state.setupFen == null;

  // Quyết định nhanh khi hết nước → checkmate/stalemate
  void _decideTerminalByLegalMoves(String fen) {
    final legalMoves = XiangqiRules.getAllLegalMoves(fen);
    if (legalMoves.isNotEmpty) return; // còn nước -> không xử lý ở đây

    final inCheck = GameStatusService.isInCheck(fen);
    final sideToMove = FenParser.getSideToMove(fen); // 'w' or 'b'

    if (inCheck) {
      // Checkmate
      final winningPlayer = sideToMove == 'w' ? 'Black' : 'Red';
      state = state.copyWith(
        isInCheck: true,
        isCheckmate: true,
        isStalemate: false,
        gameWinner: winningPlayer,
        boardLocked: true,
      );
      _showNotification(
        '$winningPlayer WINS! Checkmate!',
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      );
    } else {
      // Stalemate
      state = state.copyWith(
        isInCheck: false,
        isCheckmate: false,
        isStalemate: true,
        gameWinner: 'Draw',
        boardLocked: true,
      );
      _showNotification(
        'DRAW! Stalemate!',
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Public method for external access
  bool isFromStartpos() => _isFromStartpos();

  // Helper method to get current moves for engine
  List<String> currentMoves() {
    return state.moves.take(state.pointer).toList();
  }

  /// Checks game status when no moves are available (checkmate/stalemate)
  void _checkGameStatusForNoMoves() {
    try {
      AppLogger().log('=== CHECKING GAME STATUS FOR NO MOVES (fast rule) ===');
      final fen = state.fen;

      // Nếu không còn nước, quyết định ngay bằng quy tắc nhanh
      final legalMoves = XiangqiRules.getAllLegalMoves(fen);
      if (legalMoves.isEmpty) {
        _decideTerminalByLegalMoves(fen);
        return;
      }

      // Vẫn còn nước -> fallback sang kiểm tra chi tiết (hiếm khi rơi vào)
      final isInCheck = GameStatusService.isInCheck(fen);
      final isCheckmate = GameStatusService.isCheckmate(fen);
      final isStalemate = GameStatusService.isStalemate(fen);
      final winner = GameStatusService.getWinner(fen);

      state = state.copyWith(
        isInCheck: isInCheck,
        isCheckmate: isCheckmate,
        isStalemate: isStalemate,
        gameWinner: winner,
        boardLocked:
            isCheckmate || isStalemate || (winner != null && winner != 'Draw'),
      );

      if (isCheckmate) {
        final sideToMove = FenParser.getSideToMove(fen);
        final winningPlayer = sideToMove == 'w' ? 'Black' : 'Red';
        _showNotification(
          '$winningPlayer WINS! Checkmate!',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
      } else if (isStalemate) {
        _showNotification(
          'DRAW! Stalemate!',
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
      } else if (winner != null && winner != 'Draw') {
        _showNotification(
          '$winner WINS! King captured!',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
      } else {
        _showNotification(
          'Game state unclear - No moves available',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2), // giảm từ 3s
        );
      }
    } catch (e, st) {
      AppLogger().error('Error checking game status for no moves', e, st);
    }
  }

  /// Checks game status and shows notifications
  Future<void> _checkGameStatus() async {
    try {
      AppLogger().log('=== CHECKING GAME STATUS ===');
      final fen = state.fen;
      AppLogger().log('Current FEN: $fen');

      // Fallback nhanh: nếu không còn nước, quyết định ngay (tránh miss của service)
      final legalMovesQuick = XiangqiRules.getAllLegalMoves(fen);
      if (legalMovesQuick.isEmpty) {
        _decideTerminalByLegalMoves(fen);
        return;
      }

      // Check for check FIRST
      AppLogger().log('Checking for check...');
      final isInCheck = GameStatusService.isInCheck(fen);
      AppLogger().log('Is in check: $isInCheck');

      // Check for checkmate BEFORE checking for winner
      AppLogger().log('Checking for checkmate...');
      final isCheckmate = GameStatusService.isCheckmate(fen);
      AppLogger().log('Is checkmate: $isCheckmate');

      // Check for stalemate
      AppLogger().log('Checking for stalemate...');
      final isStalemate = GameStatusService.isStalemate(fen);
      AppLogger().log('Is stalemate: $isStalemate');

      // Check for king captured (winner)
      final winner = GameStatusService.getWinner(fen);
      AppLogger().log('Winner: $winner');

      // ✅ luôn đồng bộ cờ trạng thái vào state
      state = state.copyWith(
        isInCheck: isInCheck,
        isCheckmate: isCheckmate,
        isStalemate: isStalemate,
        gameWinner: winner,
        boardLocked:
            isCheckmate || isStalemate || (winner != null && winner != 'Draw'),
      );

      // Handle checkmate (highest priority)
      if (isCheckmate) {
        final sideToMove = FenParser.getSideToMove(fen);
        final winningPlayer = sideToMove == 'w' ? 'Black' : 'Red';
        AppLogger().log(
          '*** SHOWING CHECKMATE NOTIFICATION for $winningPlayer ***',
        );
        _showNotification(
          '$winningPlayer WINS! Checkmate!',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
        return; // Don't check other conditions if checkmate
      }

      // Handle king captured (if not checkmate)
      if (winner != null && winner != 'Draw') {
        AppLogger().log(
          '*** SHOWING KING CAPTURED NOTIFICATION for $winner ***',
        );
        _showNotification(
          '$winner WINS! King captured!',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
        return; // Don't check other conditions if game is over
      }

      // Handle check (only if not checkmate or game over)
      if (isInCheck) {
        final sideToMove = FenParser.getSideToMove(fen);
        final currentPlayer = sideToMove == 'w' ? 'Red' : 'Black';
        AppLogger().log(
          '*** SHOWING CHECK NOTIFICATION for $currentPlayer ***',
        );
        _showNotification(
          '$currentPlayer is in CHECK!',
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2), // giảm từ 4s
        );
      } else if (isStalemate) {
        // Check for stalemate only if not in check and game is not over
        AppLogger().log('*** SHOWING STALEMATE NOTIFICATION ***');
        _showNotification(
          'DRAW! Stalemate!',
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2), // giảm từ 3s // giảm từ 5s
        );
      }
    } catch (e, stackTrace) {
      AppLogger().error('Error checking game status', e, stackTrace);
    }
  }

  // Chuyển đổi FEN từ ký hiệu nội bộ sang chuẩn engine
  String _toEngineFen(String fen) {
    // Đổi H/h -> N/n (mã), E/e -> B/b (tượng) để khớp chuẩn XQFEN engine
    return fen
        .replaceAll('H', 'N')
        .replaceAll('h', 'n')
        .replaceAll('E', 'B')
        .replaceAll('e', 'b');
  }

  // Analyze current position
  Future<void> _analyzePosition() async {
    if (_engine == null) return;

    // Check game status first - if game is over, don't analyze
    final isCheckmate = GameStatusService.isCheckmate(state.fen);
    final isStalemate = GameStatusService.isStalemate(state.fen);
    final winner = GameStatusService.getWinner(state.fen);

    if (isCheckmate || isStalemate || (winner != null && winner != 'Draw')) {
      AppLogger().log(
        'Game is over - checkmate: $isCheckmate, stalemate: $isStalemate, winner: $winner - skipping engine analysis',
      );
      state = state.copyWith(
        bestLines: [],
        isEngineThinking: false,
        isCheckmate: isCheckmate,
        isStalemate: isStalemate,
        gameWinner: winner,
      );
      return;
    }

    // Stop any ongoing analysis before starting new one
    if (state.isEngineThinking) {
      AppLogger().log('Stopping ongoing analysis to start new one');
      // Note: PikafishEngine doesn't have a send method, so we just clear the state
      // The engine will naturally stop when we start a new analysis
    }

    // Token để chống chồng lấp phân tích
    final seq = ++_analysisSeq;

    // Clear previous best lines when starting a fresh analysis
    state = state.copyWith(bestLines: [], isEngineThinking: true);

    // ĐẢM BẢO MultiPV đúng theo UI trước khi phân tích (không ép)
    try {
      await _engine!.setMultiPV(state.multiPv);
      await Future.delayed(
        const Duration(milliseconds: 30), // giảm từ 50ms
      ); // Thay thế waitReady
    } catch (_) {}

    try {
      AppLogger().log('Starting position analysis (seq: $seq)');

      // In setup mode, use current FEN directly without moves
      if (state.isSetupMode) {
      await analyzeTopMoves(
        engine: _engine!,
          fen: _toEngineFen(state.fen), // ✅ Chuẩn hóa FEN cho engine
          depth: state.analysisDepth,
          numMoves: state.multiPv,
          moves: [], // No moves in setup mode
        );
      } else {
        await analyzeTopMoves(
          engine: _engine!,
          fen: _isFromStartpos() ? 'startpos' : state.setupFen!,
          depth: state.analysisDepth,
          numMoves: state.multiPv,
          moves: currentMoves(),
        );
      }
    } catch (e) {
      AppLogger().error('Position analysis failed', e);
      // Chỉ cập nhật state nếu đây vẫn là lần phân tích mới nhất
      if (seq == _analysisSeq) {
        state = state.copyWith(isEngineThinking: false);
      }
    }
  }

  Future<void> back() async {
    if (!state.canBack || _engine == null) return;

    final newPointer = state.pointer - 1;

    // Reconstruct FEN from move history up to the new pointer
    String newFen =
        state.setupFen ?? defaultXqFen; // Use setup FEN if available
    bool newRedToMove = true;

    for (int i = 0; i < newPointer; i++) {
      newFen = FenParser.applyMove(newFen, state.moves[i]);
      newRedToMove = !newRedToMove;
    }

    AppLogger().log(
      'Back: pointer ${state.pointer} -> $newPointer, FEN updated',
    );

    state = state.copyWith(
      pointer: newPointer,
      fen: newFen,
      redToMove: newRedToMove,
      bestLines: [],
      canBack: newPointer > 0,
      canNext: true,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      pendingAnimation: null, // Clear any pending animation
    );

    // Set engine position to match the board state
    if (_isFromStartpos()) {
      await _engine!.setPosition(
        'startpos',
        state.moves.take(newPointer).toList(),
      );
    } else {
      await _engine!.setPosition(newFen, state.moves.take(newPointer).toList());
    }
    await Future.delayed(
      const Duration(milliseconds: 30), // giảm từ 50ms
    ); // Thay thế waitReady
    await _analyzePosition();
  }

  Future<void> next() async {
    if (!state.canNext || _engine == null) return;

    final newPointer = state.pointer + 1;

    // Reconstruct FEN from move history up to the new pointer
    String newFen =
        state.setupFen ?? defaultXqFen; // Use setup FEN if available
    bool newRedToMove = true;

    for (int i = 0; i < newPointer; i++) {
      newFen = FenParser.applyMove(newFen, state.moves[i]);
      newRedToMove = !newRedToMove;
    }

    AppLogger().log(
      'Next: pointer ${state.pointer} -> $newPointer, FEN updated',
    );

    state = state.copyWith(
      pointer: newPointer,
      fen: newFen,
      redToMove: newRedToMove,
      bestLines: [],
      canBack: true,
      canNext: newPointer < state.moves.length,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      pendingAnimation: null, // Clear any pending animation
    );

    // Set engine position to match the board state
    if (_isFromStartpos()) {
      await _engine!.setPosition(
        'startpos',
        state.moves.take(newPointer).toList(),
      );
    } else {
      await _engine!.setPosition(newFen, state.moves.take(newPointer).toList());
    }
    await Future.delayed(
      const Duration(milliseconds: 30), // giảm từ 50ms
    ); // Thay thế waitReady
    await _analyzePosition();
  }

  Future<void> reset() async {
    // Reset to initial state
    state = const BoardState();

    // Reset engine settings to default
    if (_engine != null) {
      try {
        // Stop any ongoing search first
        await _engine!.stop();

        // Start new game (không đợi isready)
        await _engine!.newGameFast();

        // Reset engine settings to default values (không đợi isready)
        await _engine!.setMultiPVFast(1);

        // Đặt lại vị trí rõ ràng về startpos không moves (không đợi isready)
        await _engine!.setPositionFast('startpos', const []);

        // Bắt đầu phân tích ngay lập tức
        await _analyzePosition();

        AppLogger().log('Game reset - engine settings restored to default');
      } catch (e) {
        AppLogger().error('Error during reset', e);
        // Still update state even if engine fails
        state = state.copyWith(
          bestLines: [],
          isEngineThinking: false,
          error: 'Reset failed: ${e.toString()}',
        );
      }
    } else {
      AppLogger().log('No engine available for reset');
    }
  }

  /// Reset with UI settings callback
  Future<void> resetWithCallback(VoidCallback? onResetSettings) async {
    // Reset to initial state
    state = const BoardState();

    // Reset UI settings if callback is set
    onResetSettings?.call();

    // Reset engine settings to default
    if (_engine != null) {
      try {
        // Stop any ongoing search first
        await _engine!.stop();

        // Start new game
        await _engine!.newGame();

        // Reset engine settings to default values
        await _engine!.setMultiPV(1);

        // Đặt lại vị trí rõ ràng về startpos không moves
        await _engine!.setPosition('startpos', const []);

        // Bắt đầu phân tích
        await _analyzePosition();

        AppLogger().log(
          'Game reset - engine and UI settings restored to default',
        );
      } catch (e) {
        AppLogger().error('Error during reset', e);
        // Still update state even if engine fails
        state = state.copyWith(
          bestLines: [],
          isEngineThinking: false,
          error: 'Reset failed: ${e.toString()}',
        );
      }
    } else {
      AppLogger().log('No engine available for reset');
    }
  }

  Future<void> startVsEngineMode(String difficulty) async {
    if (_engine == null) {
      AppLogger().log('No engine available for vs mode');
      return;
    }

    AppLogger().log('Starting vs engine mode with difficulty: $difficulty');

    // Engine + state đều về 2
    await _engine!.setMultiPV(2);

    state = state.copyWith(
      isVsEngineMode: true,
      isEngineTurn: false, // Human starts first
      vsEngineDifficulty: difficulty,
      gameWinner: null,
      multiPv: 2, // QUAN TRỌNG: cập nhật state.multiPv
    );

    // Start analysis for the current position
    await _analyzePosition();

    // If it's engine's turn, request move
    if (!state.redToMove) {
      _scheduleNextEngineMove();
    }
  }

  void stopVsEngineMode() {
    AppLogger().log('Stopping vs engine mode');

    // ✅ Hủy tất cả timers
    _vsEngineTimer?.cancel();
    _vsEngineTimer = null;
    _checkmateTimeoutTimer?.cancel();
    _checkmateTimeoutTimer = null;
    _animationAutoCommit?.cancel();
    _animationAutoCommit = null;
    _animationWatchdog?.cancel();
    _animationWatchdog = null;

    // ✅ Dừng search hiện tại
    try {
      _engine?.stop();
    } catch (_) {}

    // ✅ Set MultiPV về 1 khi thoát khỏi chế độ đánh với máy
    if (_engine != null) {
      _engine!.setMultiPV(1);
    }

    // ✅ Xóa animation nếu có
    state = state.copyWith(
      isVsEngineMode: false,
      vsEngineDifficulty: null,
      isEngineThinking: false,
      multiPv: 1, // QUAN TRỌNG: cập nhật state.multiPv
      boardLocked: false, // Mở khóa khi thoát chế độ đánh với máy
      pendingAnimation: null, // Xóa animation
    );

    AppLogger().log('Stopped vs engine mode - MultiPV reset to 1');
  }

  Future<bool> saveCurrentGame(String name, {String? description}) async {
    try {
      final game = SavedGame(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        initialFen: defaultXqFen,
        moves: state.moves,
        savedAt: DateTime.now(),
        description: description,
        winner: state.gameWinner,
        totalMoves: state.moves.length,
      );

      final success = await SavedGamesService.instance.saveGame(game);
      if (success) {
        AppLogger().log('Game saved: $name');
      }
      return success;
    } catch (e) {
      AppLogger().error('Failed to save game: $name', e);
      return false;
    }
  }

  Future<bool> loadSavedGame(String gameId) async {
    try {
      final game = await SavedGamesService.instance.getGame(gameId);
      if (game == null) return false;

      // Reconstruct FEN from moves
      String fen = game.initialFen;
      for (final move in game.moves) {
        fen = FenParser.applyMove(fen, move);
      }

      state = state.copyWith(
        fen: fen,
        moves: game.moves,
        pointer: game.moves.length,
        redToMove: game.moves.length % 2 == 0,
        canBack: game.moves.isNotEmpty,
        canNext: false,
        gameWinner: game.winner,
        arrows: const <ArrowData>[], // Xóa mũi tên khi load game
        bestLines: const [], // Xóa phân tích cũ
        selectedFile: null, // Xóa lựa chọn quân
        selectedRank: null,
        possibleMoves: const [], // Xóa nước đi có thể
      );

      AppLogger().log('Game loaded: ${game.name}');
      return true;
    } catch (e) {
      AppLogger().error('Failed to load game: $gameId', e);
      return false;
    }
  }

  Future<void> startReplay(List<String> moves, {int delayMs = 500}) async {
    _replayMoves = List.from(moves);
    _replayIndex = 0;

    state = state.copyWith(
      isReplayMode: true,
      replayDelayMs: delayMs,
      fen: defaultXqFen,
      moves: [],
      pointer: 0,
      redToMove: true,
    );

    _scheduleNextReplayMove();
    AppLogger().log('Started replay with ${moves.length} moves');
  }

  void _scheduleNextReplayMove() {
    if (_replayIndex >= _replayMoves.length) {
      state = state.copyWith(isReplayMode: false);
      AppLogger().log('Replay completed');
      return;
    }

    _replayTimer?.cancel();
    _replayTimer = Timer(Duration(milliseconds: state.replayDelayMs), () {
      final move = _replayMoves[_replayIndex];
      applyMove(move);
      _replayIndex++;
      _scheduleNextReplayMove();
    });
  }

  void commitAnimatedMove() async {
    final anim = state.pendingAnimation;
    if (anim == null) return;

    // ✅ Nếu là nước của engine, chuyển qua commitEngineAnimatedMove
    if (anim.isEngineMove) {
      await commitEngineAnimatedMove();
      return;
    }

    // Người chơi
    print('Committing animated move: ${anim.moveUci}');
    applyMove(anim.moveUci);
    state = state.copyWith(pendingAnimation: null, clearPendingAnimation: true);
  }

  List<BestLine> _parseMultiPv(String s) {
    final lines = <BestLine>[];
    for (final raw in s.split('\n')) {
      if (!raw.contains(' pv ')) continue; // chỉ cần có pv là đủ

      final parts = raw.trim().split(RegExp(r'\s+'));
      final depth = _findInt(parts, 'depth') ?? 0;

      // Nếu engine không in "multipv", coi như multipv=1
      final idx = _findInt(parts, 'multipv') ?? 1;

      // score: ưu tiên cp, nếu không có thì bắt 'mate'
      final score = _parseScore(parts);

      final pvStart = raw.indexOf(' pv ');
      final pv = pvStart >= 0
          ? raw.substring(pvStart + 4).trim().split(' ')
          : const <String>[];

      lines.add(BestLine(index: idx, depth: depth, scoreCp: score, pv: pv));
    }

    // chỉ giữ các dòng trong phạm vi MultiPV yêu cầu
    final want = state.multiPv;
    final filtered =
        lines.where((l) => l.index >= 1 && l.index <= want).toList()
          ..sort((a, b) => b.scoreCp.compareTo(a.scoreCp));
    return filtered;
  }

  int _parseScore(List<String> parts) {
    final iCp = parts.indexOf('cp');
    if (iCp >= 0 && iCp + 1 < parts.length) {
      return int.tryParse(parts[iCp + 1]) ?? 0;
    }
    final iMate = parts.indexOf('mate');
    if (iMate >= 0 && iMate + 1 < parts.length) {
      final m = int.tryParse(parts[iMate + 1]);
      // quy ước: mate-in-N ~ 32000 - 2N (dương cho bên tốt hơn)
      if (m != null) return (m > 0) ? (32000 - 2 * m) : (-32000 - 2 * m);
    }
    return 0;
  }

  int? _findInt(List<String> parts, String key) {
    final i = parts.indexOf(key);
    if (i >= 0 && i + 1 < parts.length) {
      return int.tryParse(parts[i + 1]);
    }
    return null;
  }

  (Offset, Offset)? _parseMoveToOffsets(String mv) {
    if (mv.length < 4) return null;
    final fromFile = mv.codeUnitAt(0);
    final fromRank = int.tryParse(mv[1]);
    final toFile = mv.codeUnitAt(2);
    final toRank = int.tryParse(mv[3]);
    if (fromRank == null || toRank == null) return null;
    int fx = (fromFile - 'a'.codeUnitAt(0));
    int tx = (toFile - 'a'.codeUnitAt(0));
    if (fx < 0 || fx > 8 || tx < 0 || tx > 8) return null;
    if (fromRank < 0 || fromRank > 9 || toRank < 0 || toRank > 9) return null;
    final boardFromRank = 9 - fromRank;
    final boardToRank = 9 - toRank;
    final from = Offset(fx.toDouble(), boardFromRank.toDouble());
    final to = Offset(tx.toDouble(), boardToRank.toDouble());
    return (from, to);
  }

  Future<void> analyzeTopMoves({
    required PikafishEngine engine,
    required String fen,
    required int depth,
    int? numMoves,
    List<String>? moves,
  }) async {
    final movesToAnalyze = numMoves ?? state.multiPv;
    final currentSeq = _analysisSeq; // Lưu token hiện tại
    state = state.copyWith(analyzing: true, error: null, bestLines: []);

    try {
      AppLogger().log(
        'Starting analysis: depth=$depth, multiPV=$movesToAnalyze',
      );
      final result = await engine.getTopMoves(
        fen,
        depth,
        movesToAnalyze,
        moves,
      );
      final allLines = _parseMultiPv(result);

      if (allLines.isEmpty) {
        AppLogger().log(
          'No lines parsed. Maybe MultiPV=1 without tag or endgame. Raw result: $result',
        );
      }

      // Group by multipv index and take only the latest depth for each multipv
      final Map<int, BestLine> latestLines = {};
      for (final line in allLines) {
        if (line.index <= movesToAnalyze) {
          if (!latestLines.containsKey(line.index) ||
              latestLines[line.index]!.depth < line.depth) {
            latestLines[line.index] = line;
          }
        }
      }

      final lines = latestLines.values.toList()
        ..sort(
          (a, b) => b.scoreCp.compareTo(a.scoreCp),
        ); // Sắp xếp theo điểm số từ cao xuống thấp

      final arrows = <ArrowData>[];
      for (final line in lines) {
        if (line.pv.isNotEmpty) {
          final pts = _parseMoveToOffsets(line.pv.first);
          if (pts != null) {
            arrows.add(
              ArrowData(from: pts.$1, to: pts.$2, scoreCp: line.scoreCp),
            );
          }
        }
      }

      AppLogger().log(
        'Analysis completed: ${lines.length} lines, ${arrows.length} arrows (seq: $currentSeq)',
      );
      // Chỉ cập nhật state nếu đây vẫn là lần phân tích mới nhất
      if (currentSeq == _analysisSeq) {
        state = state.copyWith(
          analyzing: false,
          bestLines: lines,
          arrows: arrows,
          isEngineThinking: false,
        );
      }
    } catch (e, st) {
      AppLogger().error('BoardController analyze error', e, st);
      // Chỉ cập nhật state nếu đây vẫn là lần phân tích mới nhất
      if (currentSeq == _analysisSeq) {
        state = state.copyWith(
          analyzing: false,
          error: e.toString(),
          isEngineThinking: false,
        );
      }
    }
  }

  // Legacy methods for compatibility
  void setEngine(PikafishEngine engine) {
    _engine = engine;
  }

  void setSettings(int depth, int multiPV) {
    // Nếu đang đánh với máy và muốn hiển thị phân tích tốt nhất, dùng min 2
    // Nhưng vẫn cho phép người dùng chọn nhiều hơn (3, 4...)
    final effectiveMultiPv = state.isVsEngineMode
        ? (multiPV < 2 ? 2 : multiPV)
        : multiPV;

    state = state.copyWith(analysisDepth: depth, multiPv: effectiveMultiPv);

    if (_engine != null) {
      _engine!.setMultiPV(effectiveMultiPv);
    }
  }

  Future<void> setRedAtBottom(bool isRedAtBottom) async {
    state = state.copyWith(isRedAtBottom: isRedAtBottom);
  }

  // Setup mode methods
  void enterSetupMode() {
    AppLogger().log('Entering setup mode');

    // ✅ Nếu đang ở chế độ đánh với máy, phải dừng lại để máy không tự đi
    if (state.isVsEngineMode) {
      AppLogger().log('Stopping vs engine mode before entering setup mode');
      stopVsEngineMode();
    }

    // Initialize setup pieces (standard Xiangqi set)
    final setupPieces = <String, int>{
      'R': 2, 'H': 2, 'E': 2, 'A': 2, 'K': 1, 'C': 2, 'P': 5, // Red pieces
      'r': 2, 'h': 2, 'e': 2, 'a': 2, 'k': 1, 'c': 2, 'p': 5, // Black pieces
    };

    state = state.copyWith(
      isSetupMode: true,
      setupPieces: setupPieces,
      selectedSetupPiece: null,
      fen: '9/9/9/9/9/9/9/9/9/9 w', // Empty board
      moves: const [], // Clear moves history when entering setup
      pointer: 0,
      redToMove: true,
      bestLines: const [], // Clear previous analysis arrows
      setupMoveHistory: [
        '9/9/9/9/9/9/9/9/9/9 w',
      ], // Initialize with empty board
      setupMoveHistoryPointer: 0,
    );
  }

  void exitSetupMode() {
    AppLogger().log('Exiting setup mode');
    state = state.copyWith(
      isSetupMode: false,
      setupPieces: const {},
      selectedSetupPiece: null,
    );
  }

  void resetFromSetup() {
    AppLogger().log('Resetting from setup - clearing all history');
    state = state.copyWith(
      isSetupMode: false,
      setupPieces: const {},
      selectedSetupPiece: null,
      moves: const [],
      pointer: 0,
      bestLines: const [],
    );
  }

  void selectSetupPiece(String piece) {
    if (state.setupPieces[piece] != null && state.setupPieces[piece]! > 0) {
      // If clicking the same piece that's already selected, deselect it
      if (state.selectedSetupPiece == piece) {
        AppLogger().log('Deselected setup piece: $piece');
        state = state.copyWith(selectedSetupPiece: null);
      } else {
        // Select the new piece
        AppLogger().log('Selected setup piece: $piece');
        state = state.copyWith(selectedSetupPiece: piece);
      }
    }
  }

  /// Validate if a piece can be placed at the given position
  bool _isValidPlacementPosition(String piece, int file, int rank) {
    final pieceType = piece.toLowerCase();
    final isRedPiece = piece == piece.toUpperCase();

    // ✅ Tướng (King): chỉ được trong cung (palace), đi ngang/dọc trong cung
    if (pieceType == 'k') {
      if (isRedPiece) {
        // Red King: file 3-5, rank 7-9 (9 ô trong cung)
        if (rank < 7 || rank > 9 || file < 3 || file > 5) {
          return false;
        }
      } else {
        // Black King: file 3-5, rank 0-2 (9 ô trong cung)
        if (rank > 2 || file < 3 || file > 5) {
          return false;
        }
      }
      return true;
    }

    // ✅ Sĩ (Advisor): chỉ được đặt ở 5 ô chéo trong cung (trung tâm + 4 ô chéo)
    // Cung là 3x3: file 3-5, rank 0-2 (đen) hoặc rank 7-9 (đỏ)
    // 5 vị trí hợp lệ: (3,0), (3,2), (4,1), (5,0), (5,2) và vị trí trung tâm
    // Đen: (3,0), (3,2), (4,1), (5,0), (5,2)
    // Đỏ: (3,7), (3,9), (4,8), (5,7), (5,9)
    if (pieceType == 'a') {
      if (isRedPiece) {
        // Red Advisor phải ở cung và phải là vị trí chéo
        if (rank < 7 || rank > 9 || file < 3 || file > 5) {
          return false;
        }
        // Kiểm tra vị trí chéo: (3,7), (3,9), (4,8), (5,7), (5,9)
        if ((file == 3 && rank == 7) ||
            (file == 3 && rank == 9) ||
            (file == 4 && rank == 8) ||
            (file == 5 && rank == 7) ||
            (file == 5 && rank == 9)) {
          return true;
        }
        return false;
      } else {
        // Black Advisor phải ở cung và phải là vị trí chéo
        if (rank > 2 || file < 3 || file > 5) {
          return false;
        }
        // Kiểm tra vị trí chéo: (3,0), (3,2), (4,1), (5,0), (5,2)
        if ((file == 3 && rank == 0) ||
            (file == 3 && rank == 2) ||
            (file == 4 && rank == 1) ||
            (file == 5 && rank == 0) ||
            (file == 5 && rank == 2)) {
          return true;
        }
        return false;
      }
    }

    // ✅ Tượng (Elephant) – đúng 7 vị trí mỗi bên
    // Tượng chỉ có thể đứng ở các "mắt tượng" (vị trí chéo đặc biệt)
    if (pieceType == 'e') {
      // 7 ô hợp lệ cho ĐEN (nửa trên, ranks 0..4)
      const blackElephantSpots = <(int, int)>{
        (2, 0),
        (6, 0),
        (0, 2),
        (4, 2),
        (8, 2),
        (2, 4),
        (6, 4),
      };

      // 7 ô hợp lệ cho ĐỎ (nửa dưới, ranks 5..9)
      const redElephantSpots = <(int, int)>{
        (2, 9),
        (6, 9),
        (0, 7),
        (4, 7),
        (8, 7),
        (2, 5),
        (6, 5),
      };

      final ok = isRedPiece
          ? redElephantSpots.contains((file, rank))
          : blackElephantSpots.contains((file, rank));
      return ok;
    }

    // ✅ Tốt (Pawn)
    // - Bên mình (chưa qua sông):
    //   * Đỏ: rank 6 và rank 5, chỉ files 0,2,4,6,8 (5 + 5 ô)
    //   * Đen: rank 3 và rank 4, chỉ files 0,2,4,6,8 (5 + 5 ô)
    // - Bên kia (đã qua sông): bất kỳ ô nào nửa bàn đối diện
    if (pieceType == 'p') {
      const evenFiles = <int>{0, 2, 4, 6, 8};

      if (isRedPiece) {
        // Bên kia sông của Đỏ: ranks 0..4 → đặt tự do
        if (rank <= 4) return true;

        // Chưa qua sông của Đỏ: chỉ 2 hàng 6 và 5, file chẵn
        if ((rank == 6 || rank == 5) && evenFiles.contains(file)) {
          return true;
        }

        return false;
      } else {
        // Bên kia sông của Đen: ranks 5..9 → đặt tự do
        if (rank >= 5) return true;

        // Chưa qua sông của Đen: chỉ 2 hàng 3 và 4, file chẵn
        if ((rank == 3 || rank == 4) && evenFiles.contains(file)) {
          return true;
        }

        return false;
      }
    }

    // ✅ Các quân khác (Xe, Pháo, Mã): có thể đặt bất kỳ đâu (trừ cung và quân đối phương)
    return true;
  }

  String _getPieceTypeName(String piece) {
    final pieceType = piece.toLowerCase();
    final isRedPiece = piece == piece.toUpperCase();
    final color = isRedPiece ? 'Red' : 'Black';
    switch (pieceType) {
      case 'r':
        return '$color Chariot';
      case 'h':
        return '$color Horse';
      case 'e':
        return '$color Elephant';
      case 'a':
        return '$color Advisor';
      case 'k':
        return '$color King';
      case 'c':
        return '$color Cannon';
      case 'p':
        return '$color Pawn';
      default:
        return '$color Piece';
    }
  }

  void placePieceOnBoard(int file, int rank) {
    if (!state.isSetupMode || state.selectedSetupPiece == null) return;

    final piece = state.selectedSetupPiece!;
    final currentFen = state.fen;
    final board = FenParser.parseBoard(currentFen);

    // Check if square is empty
    if (board[rank][file].isNotEmpty) {
      return;
    }

    // Check if we have pieces available to place
    final availableCount = state.setupPieces[piece] ?? 0;
    if (availableCount <= 0) {
      AppLogger().log('No more $piece pieces available to place');
      return;
    }

    // ✅ Kiểm tra vị trí đặt có hợp lệ không
    if (!_isValidPlacementPosition(piece, file, rank)) {
      final pieceName = _getPieceTypeName(piece);
      _showNotification(
        'Cannot place $pieceName at this position! Invalid placement.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      );
      AppLogger().log('Invalid placement: $piece at ($file, $rank)');
      return;
    }

    // Place piece on board
    board[rank][file] = piece;
    final newFen = FenParser.boardToFen(board, state.redToMove ? 'w' : 'b');

    // Update setup pieces count
    final newSetupPieces = Map<String, int>.from(state.setupPieces);
    newSetupPieces[piece] = (newSetupPieces[piece] ?? 0) - 1;

    AppLogger().log('Placed $piece at ($file, $rank)');

    // Add to setup move history
    final newHistory = List<String>.from(state.setupMoveHistory);
    // Remove any future history if we're not at the end
    if (state.setupMoveHistoryPointer < newHistory.length - 1) {
      newHistory.removeRange(
        state.setupMoveHistoryPointer + 1,
        newHistory.length,
      );
    }
    newHistory.add(newFen);

    state = state.copyWith(
      fen: newFen,
      setupPieces: newSetupPieces,
      selectedSetupPiece: newSetupPieces[piece] == 0
          ? null
          : state.selectedSetupPiece,
      setupMoveHistory: newHistory,
      setupMoveHistoryPointer: newHistory.length - 1,
    );
  }

  void removePieceFromBoard(int file, int rank) {
    if (!state.isSetupMode) return;

    final currentFen = state.fen;
    final board = FenParser.parseBoard(currentFen);
    final piece = board[rank][file];

    if (piece.isEmpty) return;

    // Remove piece from board
    board[rank][file] = '';
    final newFen = FenParser.boardToFen(board, state.redToMove ? 'w' : 'b');

    // Return piece to setup pieces
    final newSetupPieces = Map<String, int>.from(state.setupPieces);
    newSetupPieces[piece] = (newSetupPieces[piece] ?? 0) + 1;

    AppLogger().log('Removed $piece from ($file, $rank)');

    // Add to setup move history
    final newHistory = List<String>.from(state.setupMoveHistory);
    // Remove any future history if we're not at the end
    if (state.setupMoveHistoryPointer < newHistory.length - 1) {
      newHistory.removeRange(
        state.setupMoveHistoryPointer + 1,
        newHistory.length,
      );
    }
    newHistory.add('remove:$piece:$file:$rank');

    state = state.copyWith(
      fen: newFen,
      setupPieces: newSetupPieces,
      setupMoveHistory: newHistory,
      setupMoveHistoryPointer: newHistory.length - 1,
    );
  }

  /// Move a piece from one square to another on the board (without affecting setupPieces count)
  void movePieceOnBoard(int fromFile, int fromRank, int toFile, int toRank) {
    if (!state.isSetupMode) return;

    final board = FenParser.parseBoard(state.fen);
    final piece = board[fromRank][fromFile];

    if (piece.isEmpty) return;

    // ✅ Kiểm tra vị trí mới có hợp lệ không
    if (!_isValidPlacementPosition(piece, toFile, toRank)) {
      final pieceName = _getPieceTypeName(piece);
      _showNotification(
        'Cannot move $pieceName to this position! Invalid placement.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      );
      AppLogger().log(
        'Invalid move: $piece from ($fromFile, $fromRank) to ($toFile, $toRank)',
      );
      return;
    }

    // If destination has a piece, remove it first (return to setupPieces)
    if (board[toRank][toFile].isNotEmpty) {
      final removedPiece = board[toRank][toFile];
      final newSetupPieces = Map<String, int>.from(state.setupPieces);
      newSetupPieces[removedPiece] = (newSetupPieces[removedPiece] ?? 0) + 1;
      state = state.copyWith(setupPieces: newSetupPieces);
    }

    // Perform the move
    board[fromRank][fromFile] = '';
    board[toRank][toFile] = piece;

    final newFen = FenParser.boardToFen(board, state.redToMove ? 'w' : 'b');

    AppLogger().log(
      'Moved $piece from ($fromFile, $fromRank) to ($toFile, $toRank)',
    );

    // Update setup move history (lightweight, no setupPieces change)
    final newHistory = List<String>.from(state.setupMoveHistory);
    if (state.setupMoveHistoryPointer < newHistory.length - 1) {
      newHistory.removeRange(
        state.setupMoveHistoryPointer + 1,
        newHistory.length,
      );
    }
    newHistory.add(newFen);

    state = state.copyWith(
      fen: newFen,
      setupMoveHistory: newHistory,
      setupMoveHistoryPointer: newHistory.length - 1,
    );
  }

  void startGameFromSetup() {
    if (!state.isSetupMode) return;

    AppLogger().log('Starting game from setup position');

    // Validate setup (must have exactly one king of each color)
    final board = FenParser.parseBoard(state.fen);
    int redKings = 0, blackKings = 0;

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece == 'K') redKings++;
        if (piece == 'k') blackKings++;
      }
    }

    if (redKings != 1 || blackKings != 1) {
      _showNotification(
        'Invalid setup: Must have exactly one king of each color',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Check if the setup position is already checkmate/stalemate
    final isCheckmate = GameStatusService.isCheckmate(state.fen);
    final isStalemate = GameStatusService.isStalemate(state.fen);
    final winner = GameStatusService.getWinner(state.fen);

    if (isCheckmate) {
      final sideToMove = FenParser.getSideToMove(state.fen);
      final winningPlayer = sideToMove == 'w' ? 'Black' : 'Red';

      // Khóa bàn cờ khi checkmate ở setup mode
      state = state.copyWith(
        isInCheck: true,
        isCheckmate: true,
        isStalemate: false,
        gameWinner: winningPlayer,
        boardLocked: true, // ✅ Khóa bàn cờ
      );

      _showNotification(
        'Setup position is already checkmate! $winningPlayer wins.',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3), // giảm từ 4s
      );
      return;
    }

    if (isStalemate) {
      // Khóa bàn cờ khi stalemate ở setup mode
      state = state.copyWith(
        isInCheck: false,
        isCheckmate: false,
        isStalemate: true,
        gameWinner: 'Draw',
        boardLocked: true, // ✅ Khóa bàn cờ
      );

      _showNotification(
        'Setup position is already stalemate! Game is a draw.',
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3), // giảm từ 4s
      );
      return;
    }

    if (winner != null && winner != 'Draw') {
      // Khóa bàn cờ khi đã có winner ở setup mode
      state = state.copyWith(
        gameWinner: winner,
        boardLocked: true, // ✅ Khóa bàn cờ
      );

      _showNotification(
        'Setup position already has a winner: $winner',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3), // giảm từ 4s
      );
      return;
    }

    // Exit setup mode and start game
    state = state.copyWith(
      isSetupMode: false,
      setupPieces: const {},
      selectedSetupPiece: null,
      moves: const [], // Start fresh moves history from setup position
      pointer: 0,
      setupFen: _toEngineFen(state.fen), // ✅ Lưu FEN đúng chuẩn engine
      bestLines: const [], // Clear any previous analysis arrows
      boardLocked: false, // Mở khóa khi bắt đầu game từ setup
    );

    // Reset engine to ensure clean state
    if (_engine != null) {
      _engine!.newGame();
    }

    // Trigger engine analysis for the new position
    _analyzePosition();

    _showNotification(
      'Game started from setup position',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    );
  }

  bool canUndoSetupMove() {
    return state.setupMoveHistoryPointer > 0;
  }

  bool canRedoSetupMove() {
    return state.setupMoveHistoryPointer < state.setupMoveHistory.length - 1;
  }

  void undoSetupMove() {
    if (!canUndoSetupMove()) return;

    AppLogger().log('Undoing setup move');
    final newPointer = state.setupMoveHistoryPointer - 1;
    final newFen = state.setupMoveHistory[newPointer];

    // Calculate which pieces need to be returned to the selection bar
    final currentBoard = FenParser.parseBoard(state.fen);
    final previousBoard = FenParser.parseBoard(newFen);

    // Find pieces that were removed (present in current but not in previous)
    final newSetupPieces = Map<String, int>.from(state.setupPieces);

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final currentPiece = currentBoard[rank][file];
        final previousPiece = previousBoard[rank][file];

        // If piece was removed (was in current, is not in previous)
        if (currentPiece.isNotEmpty && previousPiece.isEmpty) {
          newSetupPieces[currentPiece] =
              (newSetupPieces[currentPiece] ?? 0) + 1;
          AppLogger().log('Returned piece $currentPiece to selection bar');
        }
      }
    }

    state = state.copyWith(
      setupMoveHistoryPointer: newPointer,
      fen: newFen,
      setupPieces: newSetupPieces,
    );
  }

  void redoSetupMove() {
    if (!canRedoSetupMove()) return;

    AppLogger().log('Redoing setup move');
    final newPointer = state.setupMoveHistoryPointer + 1;
    final newFen = state.setupMoveHistory[newPointer];

    // Calculate which pieces need to be removed from the selection bar
    final currentBoard = FenParser.parseBoard(state.fen);
    final nextBoard = FenParser.parseBoard(newFen);

    // Find pieces that were added (present in next but not in current)
    final newSetupPieces = Map<String, int>.from(state.setupPieces);

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final currentPiece = currentBoard[rank][file];
        final nextPiece = nextBoard[rank][file];

        // If piece was added (was not in current, is in next)
        if (currentPiece.isEmpty && nextPiece.isNotEmpty) {
          newSetupPieces[nextPiece] = (newSetupPieces[nextPiece] ?? 0) - 1;
          AppLogger().log('Removed piece $nextPiece from selection bar');
        }
      }
    }

    state = state.copyWith(
      setupMoveHistoryPointer: newPointer,
      fen: newFen,
      setupPieces: newSetupPieces,
    );
  }

  void resetSetupBoard() {
    if (!state.isSetupMode) return;

    AppLogger().log('Resetting setup board');

    // Initialize setup pieces (standard Xiangqi set) - trả lại tất cả quân cờ
    final setupPieces = <String, int>{
      'R': 2, 'H': 2, 'E': 2, 'A': 2, 'K': 1, 'C': 2, 'P': 5, // Red pieces
      'r': 2, 'h': 2, 'e': 2, 'a': 2, 'k': 1, 'c': 2, 'p': 5, // Black pieces
    };

    state = state.copyWith(
      fen: '9/9/9/9/9/9/9/9/9/9 w', // Empty board
      setupMoveHistory: ['9/9/9/9/9/9/9/9/9/9 w'],
      setupMoveHistoryPointer: 0,
      selectedSetupPiece: null,
      setupPieces: setupPieces, // Trả lại tất cả quân cờ
    );
  }

  @override
  void dispose() {
    _vsEngineTimer?.cancel();
    _replayTimer?.cancel();
    _engine?.close();
    super.dispose();
  }
}

final boardControllerProvider =
    StateNotifierProvider<BoardController, BoardState>((ref) {
      return BoardController();
    });
