import 'dart:ui';
import '../core/fen.dart';
import '../core/xiangqi_rules.dart';
import '../core/logger.dart';

/// Service for checking game status (check, checkmate, etc.)
class GameStatusService {
  /// Checks if the current player is in check
  static bool isInCheck(String fen) {
    try {
      final board = FenParser.parseBoard(fen);
      final sideToMove = FenParser.getSideToMove(fen);
      final isRedToMove = sideToMove == 'w';

      // IMPORTANT: Some positions/logs showed non-standard mappings.
      // Try multiple possible king symbols to be robust, prefer standard first.
      String? foundKingSymbol;
      KingPosition? kingPosition;

      final possibleKings = isRedToMove ? ['K', 'k'] : ['k', 'K', 'C', 'c'];
      for (final symbol in possibleKings) {
        final pos = _findKingPosition(board, symbol);
        if (pos != null) {
          foundKingSymbol = symbol;
          kingPosition = pos;
          AppLogger().log(
            'Found ${isRedToMove ? 'red' : 'black'} king: $symbol at (${pos.file}, ${pos.rank})',
          );
          break;
        }
      }

      if (kingPosition == null || foundKingSymbol == null) {
        AppLogger().log(
          'King not found for ${isRedToMove ? 'red' : 'black'} (tried: $possibleKings)',
        );
        // Debug: print board to see what pieces are actually there
        AppLogger().log('Board state:');
        for (int rank = 0; rank < 10; rank++) {
          final row = board[rank].join(' ');
          AppLogger().log('Rank $rank: $row');
        }
        return false;
      }

      // Check if any opponent piece can attack the king
      // Use wide set of symbols to be safe, then filter out own pieces.
      final opponentSymbols = isRedToMove
          ? [
              'p',
              'r',
              'h',
              'e',
              'a',
              'k',
              'c',
              'P',
              'R',
              'H',
              'E',
              'A',
              'K',
              'C',
            ]
          : [
              'P',
              'R',
              'H',
              'E',
              'A',
              'K',
              'C',
              'p',
              'r',
              'h',
              'e',
              'a',
              'k',
              'c',
            ];
      opponentSymbols.remove(foundKingSymbol);

      AppLogger().log(
        'Looking for opponent pieces against $foundKingSymbol king: $opponentSymbols',
      );
      AppLogger().log(
        'King position: file=${kingPosition.file}, rank=${kingPosition.rank}',
      );

      // Validate opponent moves using a FEN where it's the opponent's turn
      final fenForOpponentTurn = FenParser.flipSideToMove(fen);

      for (int rank = 0; rank < 10; rank++) {
        for (int file = 0; file < 9; file++) {
          final piece = board[rank][file];
          if (piece.isNotEmpty && opponentSymbols.contains(piece)) {
            // Ensure it's truly an opponent piece
            final isPieceRed = piece == piece.toUpperCase();
            if (isPieceRed == isRedToMove) {
              continue;
            }
            AppLogger().log('Found opponent piece $piece at ($file, $rank)');

            // Create UCI move from opponent piece to king
            // No coordinate conversion needed - both are already in correct format
            final moveUci = _fileRankToUci(
              file,
              rank,
              kingPosition.file,
              kingPosition.rank,
            );
            AppLogger().log('Checking attack move: $moveUci');

            if (XiangqiRules.isValidMove(fenForOpponentTurn, moveUci)) {
              AppLogger().log(
                '*** CHECK DETECTED *** King is in check by piece $piece at ($file, $rank)',
              );
              return true;
            }
          }
        }
      }

      AppLogger().log('No check detected');
      return false;
    } catch (e, stackTrace) {
      AppLogger().error('Error checking check status', e, stackTrace);
      return false;
    }
  }

  /// Checks if the current player is in checkmate
  static bool isCheckmate(String fen) {
    try {
      AppLogger().log('=== CHECKMATE DETECTION START ===');
      AppLogger().log('FEN: $fen');

      // First, the king must be in check for it to be checkmate
      if (!isInCheck(fen)) {
        AppLogger().log('Not in check, so not checkmate');
        return false;
      }

      AppLogger().log('King is in check, checking if checkmate...');

      final board = FenParser.parseBoard(fen);
      final sideToMove = FenParser.getSideToMove(fen);
      final isRedToMove = sideToMove == 'w';

      // Find all pieces for the side to move
      final pieces = <String, List<Offset>>{};
      for (int rank = 0; rank < 10; rank++) {
        for (int file = 0; file < 9; file++) {
          final piece = board[rank][file];
          if (piece.isNotEmpty) {
            final isPieceRed = piece == piece.toUpperCase();
            if ((isRedToMove && isPieceRed) || (!isRedToMove && !isPieceRed)) {
              pieces
                  .putIfAbsent(piece, () => <Offset>[])
                  .add(Offset(file.toDouble(), rank.toDouble()));
            }
          }
        }
      }

      AppLogger().log(
        'Found ${pieces.length} piece types for ${isRedToMove ? 'Red' : 'Black'}',
      );

      // Try all possible moves for all pieces
      int totalMovesChecked = 0;
      int legalEscapeMoves = 0;

      for (final entry in pieces.entries) {
        final pieceType = entry.key;
        final positions = entry.value;

        for (final pos in positions) {
          final fromFile = pos.dx.toInt();
          final fromRank = pos.dy.toInt();

          AppLogger().log(
            'Checking moves for $pieceType at ($fromFile, $fromRank)',
          );

          // Try all possible destination squares
          for (int toRank = 0; toRank < 10; toRank++) {
            for (int toFile = 0; toFile < 9; toFile++) {
              if (toFile == fromFile && toRank == fromRank) continue;

              final moveUci = _fileRankToUci(
                fromFile,
                fromRank,
                toFile,
                toRank,
              );
              totalMovesChecked++;

              // Check if this is a legal move
              if (XiangqiRules.isValidMove(fen, moveUci)) {
                AppLogger().log('Found legal move: $moveUci');

                // Apply the move and check if still in check
                try {
                  final newFen = FenParser.applyMove(fen, moveUci);
                  final stillInCheck = isInCheck(newFen);

                  if (!stillInCheck) {
                    AppLogger().log(
                      'Move $moveUci escapes check - NOT CHECKMATE',
                    );
                    legalEscapeMoves++;
                    return false; // Found a move that escapes check
                  } else {
                    AppLogger().log('Move $moveUci still leaves king in check');
                  }
                } catch (e) {
                  AppLogger().log('Error testing move $moveUci: $e');
                }
              }
            }
          }
        }
      }

      AppLogger().log('=== CHECKMATE ANALYSIS COMPLETE ===');
      AppLogger().log('Total moves checked: $totalMovesChecked');
      AppLogger().log('Legal escape moves found: $legalEscapeMoves');
      AppLogger().log('Result: CHECKMATE = ${legalEscapeMoves == 0}');

      // If no legal move can escape check, it's checkmate
      return legalEscapeMoves == 0;
    } catch (e, stackTrace) {
      AppLogger().error('Error in checkmate detection', e, stackTrace);
      return false;
    }
  }

  /// Checks if the game is a draw (stalemate)
  static bool isStalemate(String fen) {
    try {
      AppLogger().log('Checking for stalemate...');

      // Check if not in check but no legal moves
      if (isInCheck(fen)) {
        AppLogger().log('In check, cannot be stalemate');
        return false;
      }

      final legalMoves = _getAllLegalMoves(fen);
      final isStalemate = legalMoves.isEmpty;
      AppLogger().log(
        'Stalemate check: ${isStalemate ? 'YES' : 'NO'} (legal moves: ${legalMoves.length})',
      );
      return isStalemate;
    } catch (e, stackTrace) {
      AppLogger().error('Error checking stalemate status', e, stackTrace);
      return false;
    }
  }

  /// Gets the winner of the game
  static String? getWinner(String fen) {
    try {
      // Check checkmate first
      if (isCheckmate(fen)) {
        final sideToMove = FenParser.getSideToMove(fen);
        final isRedToMove = sideToMove == 'w';
        final winner = isRedToMove ? 'Black' : 'Red';
        AppLogger().log('Winner determined: $winner (checkmate)');
        return winner;
      }

      // If a king has been captured (non-standard flow), declare winner by presence
      try {
        final board = FenParser.parseBoard(fen);
        final hasRedKing = _findKingPosition(board, 'K') != null;
        final hasBlackKing = _findKingPosition(board, 'k') != null;
        if (hasRedKing && !hasBlackKing) {
          AppLogger().log('Winner determined: Red (black king missing)');
          return 'Red';
        }
        if (!hasRedKing && hasBlackKing) {
          AppLogger().log('Winner determined: Black (red king missing)');
          return 'Black';
        }
      } catch (_) {
        // ignore board parse issues here
      }

      if (isStalemate(fen)) {
        AppLogger().log('Game result: Draw (stalemate)');
        return 'Draw';
      }

      return null; // Game continues
    } catch (e, stackTrace) {
      AppLogger().error('Error determining winner', e, stackTrace);
      return null;
    }
  }

  /// Gets all legal moves for the current position
  static List<String> _getAllLegalMoves(String fen) {
    final legalMoves = <String>[];

    try {
      final board = FenParser.parseBoard(fen);
      final sideToMove = FenParser.getSideToMove(fen);
      final isRedToMove = sideToMove == 'w';

      for (int rank = 0; rank < 10; rank++) {
        for (int file = 0; file < 9; file++) {
          final piece = board[rank][file];
          if (piece.isEmpty) continue;

          // Check if this piece belongs to current player
          final isRedPiece = piece == piece.toUpperCase();
          if (isRedToMove != isRedPiece) continue;

          // Try all possible moves for this piece
          for (int toRank = 0; toRank < 10; toRank++) {
            for (int toFile = 0; toFile < 9; toFile++) {
              if (toFile == file && toRank == rank) continue;

              final moveUci = _fileRankToUci(file, rank, toFile, toRank);
              if (XiangqiRules.isValidMove(fen, moveUci)) {
                legalMoves.add(moveUci);
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger().error('Error getting legal moves', e, stackTrace);
    }

    return legalMoves;
  }

  /// Finds the position of the king
  static KingPosition? _findKingPosition(
    List<List<String>> board,
    String kingSymbol,
  ) {
    // Restrict search to palace squares for kings to avoid mis-detection
    // Red king 'K' resides within files 3..5 and ranks 7..9 (bottom palace)
    // Black king 'k' resides within files 3..5 and ranks 0..2 (top palace)
    Iterable<int> files = [3, 4, 5];
    Iterable<int> ranks;

    if (kingSymbol == 'K') {
      // Red king at bottom palace
      ranks = [7, 8, 9];
    } else if (kingSymbol == 'k') {
      // Black king at top palace
      ranks = [0, 1, 2];
    } else {
      files = List<int>.generate(9, (i) => i);
      ranks = List<int>.generate(10, (i) => i);
    }

    for (final rank in ranks) {
      for (final file in files) {
        if (board[rank][file] == kingSymbol) {
          return KingPosition(file: file, rank: rank);
        }
      }
    }

    // Fallback: full board scan (in case of non-standard setups)
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        if (board[rank][file] == kingSymbol) {
          return KingPosition(file: file, rank: rank);
        }
      }
    }
    return null;
  }

  /// Convert file/rank coordinates to UCI notation
  static String _fileRankToUci(
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Board coordinates are already 0-9 from top to bottom
    // Convert to UCI: rank 0 (top) -> '9', rank 9 (bottom) -> '0'
    final fromSquare = '${String.fromCharCode(97 + fromFile)}${9 - fromRank}';
    final toSquare = '${String.fromCharCode(97 + toFile)}${9 - toRank}';
    return '$fromSquare$toSquare';
  }
}

/// Represents a king's position on the board
class KingPosition {
  final int file;
  final int rank;

  const KingPosition({required this.file, required this.rank});
}
