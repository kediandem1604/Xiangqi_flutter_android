// FEN (Forsyth-Edwards Notation) for Xiangqi
// Standard starting position for Chinese Chess

const String defaultXqFen =
    'rheakaehr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RHEAKAEHR w';

// Piece notation:
// Red (uppercase): R=車(Chariot), H=馬(Horse), E=象(Elephant), A=士(Advisor), K=帥(King), C=炮(Cannon), P=兵(Pawn)
// Black (lowercase): r=車, h=馬, e=象, a=士, k=將(King), c=炮, p=卒(Pawn)
// Numbers represent empty squares
// 'w' = white/red to move, 'b' = black to move

class FenParser {
  static bool isValidFen(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return false;

    final board = parts[0];
    final sideToMove = parts[1];

    // Check side to move
    if (sideToMove != 'w' && sideToMove != 'b') return false;

    // Check board format (10 ranks separated by '/')
    final ranks = board.split('/');
    if (ranks.length != 10) return false;

    for (final rank in ranks) {
      int squares = 0;
      for (final char in rank.split('')) {
        if (RegExp(r'[1-9]').hasMatch(char)) {
          squares += int.parse(char);
        } else if (RegExp(r'[RHEAKCPrheakcp]').hasMatch(char)) {
          squares += 1;
        } else {
          return false; // Invalid character
        }
      }
      if (squares != 9) return false; // Each rank must have 9 squares
    }

    return true;
  }

  static String getSideToMove(String fen) {
    final parts = fen.split(' ');
    return parts.length > 1 ? parts[1] : 'w';
  }

  static String flipSideToMove(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return fen;

    final newSide = parts[1] == 'w' ? 'b' : 'w';
    parts[1] = newSide;
    return parts.join(' ');
  }

  static List<List<String>> parseBoard(String fen) {
    final parts = fen.split(' ');
    final board = parts[0];
    final ranks = board.split('/');

    final result = <List<String>>[];
    for (final rank in ranks) {
      final rankList = <String>[];
      for (final char in rank.split('')) {
        if (RegExp(r'[1-9]').hasMatch(char)) {
          final emptySquares = int.parse(char);
          for (int i = 0; i < emptySquares; i++) {
            rankList.add('');
          }
        } else {
          rankList.add(char);
        }
      }
      result.add(rankList);
    }
    return result;
  }

  static String boardToFen(List<List<String>> board, String sideToMove) {
    final ranks = <String>[];
    for (final rank in board) {
      final rankStr = StringBuffer();
      int emptyCount = 0;

      for (final square in rank) {
        if (square.isEmpty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rankStr.write(emptyCount);
            emptyCount = 0;
          }
          rankStr.write(square);
        }
      }

      if (emptyCount > 0) {
        rankStr.write(emptyCount);
      }

      ranks.add(rankStr.toString());
    }

    return '${ranks.join('/')} $sideToMove';
  }

  static String applyMove(String fen, String moveUci) {
    // Parse the move (e.g., "e3e4" -> from e3 to e4)
    if (moveUci.length != 4) return fen;

    final fromFile = moveUci[0].codeUnitAt(0) - 97; // a=0, b=1, etc.
    final fromRank = 9 - (moveUci[1].codeUnitAt(0) - 48); // 9=0, 8=1, etc.
    final toFile = moveUci[2].codeUnitAt(0) - 97;
    final toRank = 9 - (moveUci[3].codeUnitAt(0) - 48);

    // Parse current board
    final board = parseBoard(fen);

    // Make the move
    final piece = board[fromRank][fromFile];
    board[fromRank][fromFile] = ''; // Remove piece from source
    board[toRank][toFile] = piece; // Place piece at destination

    // Flip side to move
    final currentSide = getSideToMove(fen);
    final newSide = currentSide == 'w' ? 'b' : 'w';

    return boardToFen(board, newSide);
  }
}
