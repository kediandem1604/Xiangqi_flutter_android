// Xiangqi rules validation (simplified)
import 'dart:math';
import 'fen.dart';

class XiangqiRules {
  // Basic piece movement validation
  static bool isValidMove(String fen, String uciMove) {
    if (uciMove.length < 4) return false;

    // Parse UCI move - use same logic as FenParser.applyMove
    final fromFile = uciMove.codeUnitAt(0) - 97; // 'a' -> 0
    final fromRank = 9 - (uciMove[1].codeUnitAt(0) - 48); // 9=0, 8=1, etc.
    final toFile = uciMove.codeUnitAt(2) - 97;
    final toRank = 9 - (uciMove[3].codeUnitAt(0) - 48);

    // Check if coordinates are valid
    if (fromFile < 0 || fromFile > 8 || toFile < 0 || toFile > 8) return false;
    if (fromRank < 0 || fromRank > 9 || toRank < 0 || toRank > 9) return false;

    // Parse board from FEN (simplified)
    final board = _parseBoardFromFen(fen);

    // Check if there's a piece at the source square
    final fromPiece = board[fromRank][fromFile];
    if (fromPiece.isEmpty) return false;

    // Check if destination square is not occupied by own piece
    final toPiece = board[toRank][toFile];
    if (toPiece.isNotEmpty) {
      final isFromRed = fromPiece == fromPiece.toUpperCase();
      final isToRed = toPiece == toPiece.toUpperCase();
      if (isFromRed == isToRed) return false; // Can't capture own piece
    }

    // Basic piece movement rules (simplified)
    return _isValidPieceMove(
      board,
      fromFile,
      fromRank,
      toFile,
      toRank,
      fromPiece,
    );
  }

  static List<List<String>> _parseBoardFromFen(String fen) {
    // Parse FEN properly using FenParser
    return FenParser.parseBoard(fen);
  }

  static bool _isValidPieceMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
    String piece,
  ) {
    final pieceType = piece.toLowerCase();

    switch (pieceType) {
      case 'r': // Rook/Chariot
        return _isValidRookMove(board, fromFile, fromRank, toFile, toRank);
      case 'h': // Horse
        return _isValidHorseMove(board, fromFile, fromRank, toFile, toRank);
      case 'e': // Elephant
        return _isValidElephantMove(board, fromFile, fromRank, toFile, toRank);
      case 'a': // Advisor
        return _isValidAdvisorMove(board, fromFile, fromRank, toFile, toRank);
      case 'k': // King
        return _isValidKingMove(board, fromFile, fromRank, toFile, toRank);
      case 'c': // Cannon
        return _isValidCannonMove(board, fromFile, fromRank, toFile, toRank);
      case 'p': // Pawn
        return _isValidPawnMove(board, fromFile, fromRank, toFile, toRank);
      default:
        return false;
    }
  }

  static bool _isValidRookMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Rook moves horizontally or vertically, any distance
    if (fromFile != toFile && fromRank != toRank) {
      return false; // Must move in straight line
    }

    // Check if path is clear
    if (fromFile == toFile) {
      // Vertical move
      final start = min(fromRank, toRank);
      final end = max(fromRank, toRank);
      for (int rank = start + 1; rank < end; rank++) {
        if (board[rank][fromFile].isNotEmpty) {
          return false; // Path blocked
        }
      }
    } else {
      // Horizontal move
      final start = min(fromFile, toFile);
      final end = max(fromFile, toFile);
      for (int file = start + 1; file < end; file++) {
        if (board[fromRank][file].isNotEmpty) {
          return false; // Path blocked
        }
      }
    }

    return true;
  }

  static bool _isValidHorseMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Horse moves in L-shape: 2 squares in one direction, then 1 square perpendicular
    final fileDiff = (toFile - fromFile).abs();
    final rankDiff = (toRank - fromRank).abs();

    if (!((fileDiff == 2 && rankDiff == 1) ||
        (fileDiff == 1 && rankDiff == 2))) {
      return false;
    }

    // Check if the "leg" is blocked
    int legFile = fromFile;
    int legRank = fromRank;

    if (fileDiff == 2) {
      legFile = fromFile + (toFile - fromFile) ~/ 2;
    } else {
      legRank = fromRank + (toRank - fromRank) ~/ 2;
    }

    return board[legRank][legFile].isEmpty; // Leg must be clear
  }

  static bool _isValidElephantMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Elephant moves diagonally 2 squares
    final fileDiff = (toFile - fromFile).abs();
    final rankDiff = (toRank - fromRank).abs();

    if (fileDiff != 2 || rankDiff != 2) {
      return false;
    }

    // Check if the "eye" is blocked
    final eyeFile = fromFile + (toFile - fromFile) ~/ 2;
    final eyeRank = fromRank + (toRank - fromRank) ~/ 2;

    if (board[eyeRank][eyeFile].isNotEmpty) {
      return false; // Eye blocked
    }

    // Elephant cannot cross the river
    final isRedElephant =
        board[fromRank][fromFile] == board[fromRank][fromFile].toUpperCase();
    if (isRedElephant && toRank < 5) {
      return false; // Red elephant cannot cross river
    }
    if (!isRedElephant && toRank > 4) {
      return false; // Black elephant cannot cross river
    }

    return true;
  }

  static bool _isValidAdvisorMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Advisor moves diagonally 1 square
    final fileDiff = (toFile - fromFile).abs();
    final rankDiff = (toRank - fromRank).abs();

    if (fileDiff != 1 || rankDiff != 1) {
      return false;
    }

    // Advisor can only move within palace
    final isRedAdvisor =
        board[fromRank][fromFile] == board[fromRank][fromFile].toUpperCase();
    if (isRedAdvisor) {
      // Red palace: ranks 7-9, files 3-5
      if (toRank < 7 || toRank > 9 || toFile < 3 || toFile > 5) return false;
    } else {
      // Black palace: ranks 0-2, files 3-5
      if (toRank < 0 || toRank > 2 || toFile < 3 || toFile > 5) return false;
    }

    return true;
  }

  static bool _isValidKingMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // King moves 1 square horizontally or vertically
    final fileDiff = (toFile - fromFile).abs();
    final rankDiff = (toRank - fromRank).abs();

    if ((fileDiff == 1 && rankDiff == 0) || (fileDiff == 0 && rankDiff == 1)) {
      // King can only move within palace
      final isRedKing =
          board[fromRank][fromFile] == board[fromRank][fromFile].toUpperCase();
      if (isRedKing) {
        // Red palace: ranks 7-9, files 3-5
        if (toRank < 7 || toRank > 9 || toFile < 3 || toFile > 5) return false;
      } else {
        // Black palace: ranks 0-2, files 3-5
        if (toRank < 0 || toRank > 2 || toFile < 3 || toFile > 5) return false;
      }

      // Kiểm tra các ràng buộc bổ sung cho tướng
      if (!_isKingMoveSafe(board, fromFile, fromRank, toFile, toRank)) {
        return false;
      }

      return true;
    }

    return false;
  }

  /// Kiểm tra nước đi của tướng có an toàn không
  static bool _isKingMoveSafe(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // 1. Kiểm tra tướng không thể chạm mặt với tướng/xe địch
    if (_isKingFacingEnemyKingOrRook(board, toFile, toRank)) {
      return false;
    }

    // 2. Kiểm tra tướng không đi vào điểm ăn của mã địch
    if (_isKingAttackedByHorse(board, toFile, toRank)) {
      return false;
    }

    // 3. Kiểm tra tướng không đi vào điểm ăn của tốt địch
    if (_isKingAttackedByPawn(board, toFile, toRank)) {
      return false;
    }

    // 4. Kiểm tra tướng không đi vào điểm ăn của pháo địch
    if (_isKingAttackedByCannon(board, toFile, toRank)) {
      return false;
    }

    return true;
  }

  /// Kiểm tra tướng có chạm mặt với tướng/xe địch không
  static bool _isKingFacingEnemyKingOrRook(
    List<List<String>> board,
    int kingFile,
    int kingRank,
  ) {
    // Lấy thông tin về tướng hiện tại để xác định màu
    final kingPiece = board[kingRank][kingFile];
    if (kingPiece.isEmpty) return false;

    final isRedKing = kingPiece == kingPiece.toUpperCase();

    // Kiểm tra theo chiều dọc (cùng file)
    for (int rank = 0; rank < 10; rank++) {
      if (rank == kingRank) continue;

      final piece = board[rank][kingFile];
      if (piece.isEmpty) continue;

      final isRedPiece = piece == piece.toUpperCase();
      if (isRedPiece == isRedKing) continue; // Cùng màu, bỏ qua

      // Kiểm tra có phải tướng hoặc xe không
      final pieceType = piece.toLowerCase();
      if (pieceType == 'k' || pieceType == 'r') {
        // Kiểm tra đường đi có bị chặn không
        bool pathBlocked = false;
        final start = min(kingRank, rank);
        final end = max(kingRank, rank);

        for (int r = start + 1; r < end; r++) {
          if (board[r][kingFile].isNotEmpty) {
            pathBlocked = true;
            break;
          }
        }

        if (!pathBlocked) {
          return true; // Chạm mặt với tướng/xe địch
        }
      }
    }

    return false;
  }

  /// Kiểm tra tướng có bị mã địch tấn công không
  static bool _isKingAttackedByHorse(
    List<List<String>> board,
    int kingFile,
    int kingRank,
  ) {
    // Lấy thông tin về tướng hiện tại để xác định màu
    final kingPiece = board[kingRank][kingFile];
    if (kingPiece.isEmpty) return false;

    final isRedKing = kingPiece == kingPiece.toUpperCase();

    // Kiểm tra tất cả mã trên bàn cờ
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece.isEmpty) continue;

        final isRedPiece = piece == piece.toUpperCase();
        if (isRedPiece == isRedKing) continue; // Cùng màu, bỏ qua

        if (piece.toLowerCase() == 'h') {
          // Kiểm tra mã có thể ăn tướng không
          if (_isValidHorseMove(board, file, rank, kingFile, kingRank)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Kiểm tra tướng có bị tốt địch tấn công không
  static bool _isKingAttackedByPawn(
    List<List<String>> board,
    int kingFile,
    int kingRank,
  ) {
    // Lấy thông tin về tướng hiện tại để xác định màu
    final kingPiece = board[kingRank][kingFile];
    if (kingPiece.isEmpty) return false;

    final isRedKing = kingPiece == kingPiece.toUpperCase();

    // Kiểm tra tất cả tốt trên bàn cờ
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece.isEmpty) continue;

        final isRedPiece = piece == piece.toUpperCase();
        if (isRedPiece == isRedKing) continue; // Cùng màu, bỏ qua

        if (piece.toLowerCase() == 'p') {
          // Kiểm tra tốt có thể ăn tướng không
          if (_isValidPawnMove(board, file, rank, kingFile, kingRank)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Kiểm tra tướng có bị pháo địch tấn công không
  static bool _isKingAttackedByCannon(
    List<List<String>> board,
    int kingFile,
    int kingRank,
  ) {
    // Lấy thông tin về tướng hiện tại để xác định màu
    final kingPiece = board[kingRank][kingFile];
    if (kingPiece.isEmpty) return false;

    final isRedKing = kingPiece == kingPiece.toUpperCase();

    // Kiểm tra tất cả pháo trên bàn cờ
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece.isEmpty) continue;

        final isRedPiece = piece == piece.toUpperCase();
        if (isRedPiece == isRedKing) continue; // Cùng màu, bỏ qua

        if (piece.toLowerCase() == 'c') {
          // Kiểm tra pháo có thể ăn tướng không
          if (_isValidCannonMove(board, file, rank, kingFile, kingRank)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  static bool _isValidCannonMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Cannon moves like rook, but must jump over exactly one piece to capture
    if (fromFile != toFile && fromRank != toRank) {
      return false; // Must move in straight line
    }

    final toPiece = board[toRank][toFile];
    final isCapturing = toPiece.isNotEmpty;

    if (isCapturing) {
      // When capturing, must jump over exactly one piece
      int piecesInPath = 0;
      if (fromFile == toFile) {
        // Vertical move
        final start = min(fromRank, toRank);
        final end = max(fromRank, toRank);
        for (int rank = start + 1; rank < end; rank++) {
          if (board[rank][fromFile].isNotEmpty) {
            piecesInPath++;
          }
        }
      } else {
        // Horizontal move
        final start = min(fromFile, toFile);
        final end = max(fromFile, toFile);
        for (int file = start + 1; file < end; file++) {
          if (board[fromRank][file].isNotEmpty) {
            piecesInPath++;
          }
        }
      }
      return piecesInPath == 1; // Must jump over exactly one piece
    } else {
      // When not capturing, path must be clear (like rook)
      if (fromFile == toFile) {
        // Vertical move
        final start = min(fromRank, toRank);
        final end = max(fromRank, toRank);
        for (int rank = start + 1; rank < end; rank++) {
          if (board[rank][fromFile].isNotEmpty) {
            return false; // Path blocked
          }
        }
      } else {
        // Horizontal move
        final start = min(fromFile, toFile);
        final end = max(fromFile, toFile);
        for (int file = start + 1; file < end; file++) {
          if (board[fromRank][file].isNotEmpty) {
            return false; // Path blocked
          }
        }
      }
      return true;
    }
  }

  static bool _isValidPawnMove(
    List<List<String>> board,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    final isRedPawn =
        board[fromRank][fromFile] == board[fromRank][fromFile].toUpperCase();
    final hasCrossedRiver = isRedPawn ? fromRank < 5 : fromRank > 4;

    if (hasCrossedRiver) {
      // After crossing river: can move forward OR sideways
      if (fromFile == toFile && (toRank - fromRank).abs() == 1) {
        return true; // Forward
      }
      if (fromRank == toRank && (toFile - fromFile).abs() == 1) {
        return true; // Sideways
      }
      return false;
    } else {
      // Before crossing river: can ONLY move forward
      if (fromFile == toFile && (toRank - fromRank).abs() == 1) {
        return true; // Forward only
      }
      return false;
    }
  }

  /// Get all legal moves for the current position
  static List<String> getAllLegalMoves(String fen) {
    final moves = <String>[];
    final board = FenParser.parseBoard(fen);

    for (int fromRank = 0; fromRank < 10; fromRank++) {
      for (int fromFile = 0; fromFile < 9; fromFile++) {
        final piece = board[fromRank][fromFile];
        if (piece.isEmpty) continue;

        // Check if it's the current player's piece
        final sideToMove = FenParser.getSideToMove(fen);
        final isRedPiece = piece == piece.toUpperCase();
        if ((sideToMove == 'w' && !isRedPiece) ||
            (sideToMove == 'b' && isRedPiece)) {
          continue; // Skip opponent's pieces
        }

        // Check all possible destinations
        for (int toRank = 0; toRank < 10; toRank++) {
          for (int toFile = 0; toFile < 9; toFile++) {
            if (fromFile == toFile && fromRank == toRank) continue;

            final uci = _fileRankToUci(fromFile, fromRank, toFile, toRank);
            if (isValidMove(fen, uci)) {
              moves.add(uci);
            }
          }
        }
      }
    }

    return moves;
  }

  /// Convert file/rank coordinates to UCI notation
  static String _fileRankToUci(
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    final fromSquare = '${String.fromCharCode(97 + fromFile)}${9 - fromRank}';
    final toSquare = '${String.fromCharCode(97 + toFile)}${9 - toRank}';
    return '$fromSquare$toSquare';
  }
}
