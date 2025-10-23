import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../pikafish_engine.dart';
import '../../core/xiangqi_rules.dart';
import '../../core/fen.dart';
import '../../core/logger.dart';
// Note: dùng trực tiếp PikafishEngine như trước để không ảnh hưởng cách gọi
import '../../services/game_status_service.dart';
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
  final Map<String, String> setupPieces; // file,rank -> piece symbol
  final Offset? arrowFrom;
  final Offset? arrowTo;
  final List<ArrowData> arrows; // all arrows from MultiPV results
  final int? selectedFile;
  final int? selectedRank;
  final List<Offset> possibleMoves; // possible moves for selected piece
  final MoveAnimation? pendingAnimation; // animation in progress
  final bool isEngineTurn; // true if it's engine's turn in vs engine mode
  final String? setupFen; // FEN for setup mode
  final bool isRedAtBottom; // true if red pieces are at bottom, false if black
  final bool analyzing;
  final String? error;

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
    this.arrowFrom,
    this.arrowTo,
    this.arrows = const <ArrowData>[],
    this.selectedFile,
    this.selectedRank,
    this.possibleMoves = const [],
    this.pendingAnimation,
    this.isEngineTurn = false,
    this.setupFen,
    this.isRedAtBottom = true, // default: red at bottom
    this.analyzing = false,
    this.error,
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
    Map<String, String>? setupPieces,
    Offset? arrowFrom,
    Offset? arrowTo,
    List<ArrowData>? arrows,
    int? selectedFile,
    int? selectedRank,
    List<Offset>? possibleMoves,
    MoveAnimation? pendingAnimation,
    bool? isEngineTurn,
    String? setupFen,
    bool? isRedAtBottom,
    bool? analyzing,
    String? error,
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
      arrowFrom: arrowFrom,
      arrowTo: arrowTo,
      arrows: arrows ?? this.arrows,
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
    );
  }
}

class BoardController extends StateNotifier<BoardState> {
  PikafishEngine? _engine;
  Timer? _vsEngineTimer;
  Timer? _replayTimer;
  Timer? _animationAutoCommit;
  Timer? _animationWatchdog;
  int _replayIndex = 0;
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
    if (_engine == null) return;

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
            arrows: const <ArrowData>[], // Ẩn mũi tên khi bắt đầu chọn quân
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
          arrows: const <ArrowData>[], // Ẩn mũi tên khi bắt đầu chọn quân
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
              arrows: const <ArrowData>[], // Ẩn mũi tên khi bắt đầu chọn quân
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
        _animationAutoCommit = Timer(const Duration(milliseconds: 120), () {
          if (state.pendingAnimation != null) {
            AppLogger().log('Auto-commit animated move (failsafe)');
            commitAnimatedMove();
          }
        });
        // Additional watchdog: force clear if animation is stuck for too long
        _animationWatchdog?.cancel();
        _animationWatchdog = Timer(const Duration(milliseconds: 800), () {
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

  void _handleBestMove(String bestMove) {
    if (bestMove.isEmpty) return;

    // Apply engine move
    applyMove(bestMove);

    // If in vs engine mode, continue the game
    if (state.isVsEngineMode) {
      _scheduleNextEngineMove();
    }
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
        _requestEngineMove();
      }
    });
  }

  Future<void> _requestEngineMove() async {
    if (_engine == null || state.gameWinner != null) return;

    try {
      state = state.copyWith(isEngineThinking: true);
      final bestMove = await _engine!.getBestMove(
        state.fen,
        state.analysisDepth,
      );
      state = state.copyWith(isEngineThinking: false);
      _handleBestMove(bestMove);
    } catch (e) {
      AppLogger().error('Failed to request engine move', e);
      state = state.copyWith(
        isEngineThinking: false,
        engineError: 'Engine move failed: $e',
      );
    }
  }

  Future<void> _makeEngineMove() async {
    if (_engine == null || !state.isVsEngineMode) return;

    try {
      AppLogger().log(
        'Engine making move with difficulty: ${state.vsEngineDifficulty}',
      );

      // Check if we already have best lines from previous analysis
      if (state.bestLines.isNotEmpty) {
        AppLogger().log('Using existing best lines for engine move');
        String selectedMove = _selectEngineMove(state.bestLines);
        if (selectedMove.isNotEmpty && selectedMove != 'null') {
          AppLogger().log('Engine selected move: $selectedMove');
          await _applyEngineMove(selectedMove);
          return;
        }
      }

      // If no best lines available, start new analysis
      AppLogger().log('Starting new engine analysis for move selection');
      final bestMove = await _engine!.getBestMove(
        state.fen,
        state.analysisDepth,
      );

      if (bestMove.isNotEmpty && bestMove != 'null') {
        AppLogger().log('Engine selected move: $bestMove');
        await _applyEngineMove(bestMove);
      }
    } catch (e) {
      AppLogger().error('Engine move failed', e);
      _showNotification(
        'Engine move failed: ${e.toString()}',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      );
    }
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
    final fromRank = int.parse(moveUci[1]) - 1;
    final toFile = moveUci.codeUnitAt(2) - 'a'.codeUnitAt(0);
    final toRank = int.parse(moveUci[3]) - 1;

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
    _animationAutoCommit = Timer(const Duration(milliseconds: 120), () {
      if (state.pendingAnimation != null) {
        AppLogger().log('Auto-commit engine animated move (failsafe)');
        commitEngineAnimatedMove();
      }
    });

    // Additional watchdog: force clear if animation is stuck for too long
    _animationWatchdog?.cancel();
    _animationWatchdog = Timer(const Duration(milliseconds: 800), () {
      if (state.pendingAnimation != null) {
        AppLogger().log(
          'Engine animation watchdog: force clearing stuck animation',
        );
        state = state.copyWith(pendingAnimation: null);
      }
    });
  }

  // Commit engine animated move
  Future<void> commitEngineAnimatedMove() async {
    final anim = state.pendingAnimation;
    if (anim == null) return;

    AppLogger().log('Committing engine animated move: ${anim.moveUci}');

    final newMoves = [...state.moves];
    if (state.pointer < newMoves.length) {
      newMoves.removeRange(state.pointer, newMoves.length);
    }
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
      pendingAnimation: null,
    );

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
  }

  String _selectEngineMove(List<BestLine> bestLines) {
    if (bestLines.isEmpty) return '';

    // Simple difficulty selection based on best lines
    switch (state.vsEngineDifficulty) {
      case 'easy':
        // Use worst move (last in list)
        return bestLines.last.firstMove;
      case 'medium':
        // Use random move from top 3
        if (bestLines.length >= 3) {
          final random = DateTime.now().millisecondsSinceEpoch % 3;
          return bestLines[random].firstMove;
        }
        return bestLines.last.firstMove;
      case 'hard':
      default:
        // Use best move (first in list)
        return bestLines.first.firstMove;
    }
  }

  void _showNotification(
    String message, {
    Color? backgroundColor,
    Duration? duration,
  }) {
    // This would typically show a snackbar or notification
    AppLogger().log('Notification: $message');
  }

  Future<void> applyMove(String moveUci) async {
    if (_engine == null) return;

    await AppLogger().log('Apply move: $moveUci');

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
          _makeEngineMove();
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

  // Public method for external access
  bool isFromStartpos() => _isFromStartpos();

  // Helper method to get current moves for engine
  List<String> currentMoves() {
    return state.moves.take(state.pointer).toList();
  }

  /// Checks game status and shows notifications
  Future<void> _checkGameStatus() async {
    try {
      AppLogger().log('=== CHECKING GAME STATUS ===');
      final fen = state.fen;
      AppLogger().log('Current FEN: $fen');

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

      // Handle checkmate (highest priority)
      if (isCheckmate) {
        AppLogger().log('CHECKMATE DETECTED!');
        state = state.copyWith(
          isInCheck: isInCheck,
          isCheckmate: isCheckmate,
          isStalemate: isStalemate,
          gameWinner: winner,
        );
        _showNotification(
          'Checkmate! ${winner == 'w' ? 'Red' : 'Black'} wins!',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Handle stalemate
      if (isStalemate) {
        AppLogger().log('STALEMATE DETECTED!');
        state = state.copyWith(
          isInCheck: isInCheck,
          isCheckmate: isCheckmate,
          isStalemate: isStalemate,
          gameWinner: 'Draw',
        );
        _showNotification(
          'Stalemate! Game is a draw.',
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Handle check
      if (isInCheck) {
        AppLogger().log('CHECK DETECTED!');
        state = state.copyWith(
          isInCheck: isInCheck,
          isCheckmate: isCheckmate,
          isStalemate: isStalemate,
          gameWinner: winner,
        );
        _showNotification(
          'Check!',
          backgroundColor: Colors.yellow,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // Handle king captured
      if (winner != null && winner != 'Draw') {
        AppLogger().log('KING CAPTURED! Winner: $winner');
        state = state.copyWith(
          isInCheck: isInCheck,
          isCheckmate: isCheckmate,
          isStalemate: isStalemate,
          gameWinner: winner,
        );
        _showNotification(
          'King captured! ${winner == 'w' ? 'Red' : 'Black'} wins!',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Normal position - just update state
      state = state.copyWith(
        isInCheck: isInCheck,
        isCheckmate: isCheckmate,
        isStalemate: isStalemate,
        gameWinner: winner,
      );
      AppLogger().log('Normal position - no special status');
    } catch (e, stackTrace) {
      AppLogger().error('Error checking game status', e, stackTrace);
      // Don't throw - this is not critical enough to crash the app
    }
  }

  // Analyze current position
  Future<void> _analyzePosition() async {
    if (_engine == null) return;

    // Check game status first - if game is over, don't analyze
    final winner = GameStatusService.getWinner(state.fen);
    if (winner != null && winner != 'Draw') {
      AppLogger().log('Game is over: $winner wins - skipping engine analysis');
      state = state.copyWith(bestLines: [], isEngineThinking: false);
      return;
    }

    // Stop any ongoing analysis before starting new one
    if (state.isEngineThinking) {
      AppLogger().log('Stopping ongoing analysis to start new one');
      // Note: PikafishEngine doesn't have a send method, so we just clear the state
      // The engine will naturally stop when we start a new analysis
    }

    // Clear previous best lines when starting a fresh analysis
    state = state.copyWith(bestLines: [], isEngineThinking: true);

    try {
      AppLogger().log('Starting position analysis');
      await analyzeTopMoves(
        engine: _engine!,
        fen: _isFromStartpos() ? 'startpos' : state.setupFen!,
        depth: state.analysisDepth,
        numMoves: state.multiPv,
        moves: currentMoves(),
      );
    } catch (e) {
      AppLogger().error('Position analysis failed', e);
      state = state.copyWith(isEngineThinking: false);
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

        // Start new game
        await _engine!.newGame();

        // Reset engine settings to default values
        await _engine!.setMultiPV(1);

        // Đặt lại vị trí rõ ràng về startpos không moves
        await _engine!.setPosition('startpos', const []);

        // Bắt đầu phân tích
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

    state = state.copyWith(
      isVsEngineMode: true,
      vsEngineDifficulty: difficulty,
      gameWinner: null,
    );

    AppLogger().log('Started vs engine mode with difficulty: $difficulty');

    // If it's engine's turn, request move
    if (!state.redToMove) {
      _scheduleNextEngineMove();
    }
  }

  void stopVsEngineMode() {
    _vsEngineTimer?.cancel();
    state = state.copyWith(
      isVsEngineMode: false,
      vsEngineDifficulty: null,
      isEngineThinking: false,
    );

    AppLogger().log('Stopped vs engine mode');
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
      );

      AppLogger().log('Game loaded: ${game.name}');
      return true;
    } catch (e) {
      AppLogger().error('Failed to load game: $gameId', e);
      return false;
    }
  }

  Future<void> startReplay(List<String> moves, {int delayMs = 1000}) async {
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

  void enterSetupMode() {
    state = state.copyWith(isSetupMode: true, setupPieces: {});
    AppLogger().log('Entered setup mode');
  }

  void exitSetupMode() {
    state = state.copyWith(isSetupMode: false, setupPieces: {});
    AppLogger().log('Exited setup mode');
  }

  void commitAnimatedMove() {
    final anim = state.pendingAnimation;
    if (anim == null) return;

    print('Committing animated move: ${anim.moveUci}');
    applyMove(anim.moveUci);

    state = state.copyWith(
      pendingAnimation: null,
      clearPendingAnimation: true,
      // Selection already cleared when move was confirmed
    );
  }

  List<BestLine> _parseMultiPv(String s) {
    final lines = <BestLine>[];
    for (final raw in s.split('\n')) {
      if (!raw.contains(' multipv ')) continue;
      final parts = raw.split(RegExp(r'\s+'));
      int depth = _findInt(parts, 'depth') ?? 0;
      int idx = _findInt(parts, 'multipv') ?? 0;
      int score = _findInt(parts, 'cp') ?? 0;
      final pvStart = raw.indexOf(' pv ');
      final pvMoves = pvStart >= 0
          ? raw.substring(pvStart + 4).trim().split(' ')
          : <String>[];
      lines.add(
        BestLine(index: idx, depth: depth, scoreCp: score, pv: pvMoves),
      );
    }
    lines.sort((a, b) => a.index.compareTo(b.index));
    return lines;
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
        ..sort((a, b) => b.scoreCp.compareTo(a.scoreCp)); // Sắp xếp theo điểm số từ cao xuống thấp

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
        'Analysis completed: ${lines.length} lines, ${arrows.length} arrows',
      );
      state = state.copyWith(
        analyzing: false,
        bestLines: lines,
        arrows: arrows,
        isEngineThinking: false,
      );
    } catch (e, st) {
      AppLogger().error('BoardController analyze error', e, st);
      state = state.copyWith(
        analyzing: false,
        error: e.toString(),
        isEngineThinking: false,
      );
    }
  }

  // Legacy methods for compatibility
  void setEngine(PikafishEngine engine) {
    _engine = engine;
  }

  void setSettings(int depth, int multiPV) {
    state = state.copyWith(analysisDepth: depth, multiPv: multiPV);
  }

  Future<void> setRedAtBottom(bool isRedAtBottom) async {
    state = state.copyWith(isRedAtBottom: isRedAtBottom);
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
