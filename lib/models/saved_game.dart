// Model for saved games
class SavedGame {
  final String id;
  final String name;
  final String initialFen;
  final List<String> moves;
  final DateTime savedAt;
  final String? description;
  final String? winner; // 'red', 'black', 'draw', or null if ongoing
  final int totalMoves;

  const SavedGame({
    required this.id,
    required this.name,
    required this.initialFen,
    required this.moves,
    required this.savedAt,
    this.description,
    this.winner,
    required this.totalMoves,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initialFen': initialFen,
      'moves': moves,
      'savedAt': savedAt.toIso8601String(),
      'description': description,
      'winner': winner,
      'totalMoves': totalMoves,
    };
  }

  // Create from JSON
  factory SavedGame.fromJson(Map<String, dynamic> json) {
    return SavedGame(
      id: json['id'] as String,
      name: json['name'] as String,
      initialFen: json['initialFen'] as String,
      moves: List<String>.from(json['moves'] as List),
      savedAt: DateTime.parse(json['savedAt'] as String),
      description: json['description'] as String?,
      winner: json['winner'] as String?,
      totalMoves: json['totalMoves'] as int,
    );
  }

  // Create a copy with updated fields
  SavedGame copyWith({
    String? id,
    String? name,
    String? initialFen,
    List<String>? moves,
    DateTime? savedAt,
    String? description,
    String? winner,
    int? totalMoves,
  }) {
    return SavedGame(
      id: id ?? this.id,
      name: name ?? this.name,
      initialFen: initialFen ?? this.initialFen,
      moves: moves ?? this.moves,
      savedAt: savedAt ?? this.savedAt,
      description: description ?? this.description,
      winner: winner ?? this.winner,
      totalMoves: totalMoves ?? this.totalMoves,
    );
  }

  // Get game duration (if we had start time)
  String get gameSummary {
    final moveCount = moves.length;
    final result = winner != null
        ? (winner == 'draw' ? 'Hòa' : '${winner == 'red' ? 'Đỏ' : 'Đen'} thắng')
        : 'Đang chơi';

    return '$moveCount nước đi - $result';
  }

  // Get formatted save date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(savedAt);

    if (difference.inDays == 0) {
      return 'Hôm nay ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hôm qua ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${savedAt.day}/${savedAt.month}/${savedAt.year}';
    }
  }
}
