import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/saved_game.dart';
import '../core/logger.dart';

class SavedGamesService {
  static const String _fileName = 'saved_games.json';
  static SavedGamesService? _instance;

  SavedGamesService._();

  static SavedGamesService get instance {
    _instance ??= SavedGamesService._();
    return _instance!;
  }

  // Get the file path for saved games
  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  // Load all saved games
  Future<List<SavedGame>> loadSavedGames() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        AppLogger().log('No saved games file found, returning empty list');
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);

      final savedGames = jsonList
          .map((json) => SavedGame.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by save date (newest first)
      savedGames.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      AppLogger().log('Loaded ${savedGames.length} saved games');
      return savedGames;
    } catch (e) {
      AppLogger().error('Failed to load saved games', e);
      return [];
    }
  }

  // Save a game
  Future<bool> saveGame(SavedGame game) async {
    try {
      final savedGames = await loadSavedGames();

      // Check if game with same ID already exists
      final existingIndex = savedGames.indexWhere((g) => g.id == game.id);
      if (existingIndex != -1) {
        // Update existing game
        savedGames[existingIndex] = game;
        AppLogger().log('Updated existing saved game: ${game.name}');
      } else {
        // Add new game
        savedGames.add(game);
        AppLogger().log('Added new saved game: ${game.name}');
      }

      // Save to file
      final filePath = await _getFilePath();
      final file = File(filePath);
      final jsonString = json.encode(
        savedGames.map((g) => g.toJson()).toList(),
      );
      await file.writeAsString(jsonString);

      AppLogger().log('Successfully saved ${savedGames.length} games to file');
      return true;
    } catch (e) {
      AppLogger().error('Failed to save game: ${game.name}', e);
      return false;
    }
  }

  // Delete a game
  Future<bool> deleteGame(String gameId) async {
    try {
      final savedGames = await loadSavedGames();
      final initialCount = savedGames.length;

      savedGames.removeWhere((game) => game.id == gameId);

      if (savedGames.length == initialCount) {
        AppLogger().log('Game with ID $gameId not found');
        return false;
      }

      // Save updated list
      final filePath = await _getFilePath();
      final file = File(filePath);
      final jsonString = json.encode(
        savedGames.map((g) => g.toJson()).toList(),
      );
      await file.writeAsString(jsonString);

      AppLogger().log('Successfully deleted game with ID: $gameId');
      return true;
    } catch (e) {
      AppLogger().error('Failed to delete game with ID: $gameId', e);
      return false;
    }
  }

  // Get a specific game by ID
  Future<SavedGame?> getGame(String gameId) async {
    try {
      final savedGames = await loadSavedGames();
      return savedGames.firstWhere(
        (game) => game.id == gameId,
        orElse: () => throw StateError('Game not found'),
      );
    } catch (e) {
      AppLogger().log('Game with ID $gameId not found');
      return null;
    }
  }

  // Check if a game name already exists
  Future<bool> isGameNameExists(String name, {String? excludeId}) async {
    try {
      final savedGames = await loadSavedGames();
      return savedGames.any(
        (game) =>
            game.name.toLowerCase() == name.toLowerCase() &&
            (excludeId == null || game.id != excludeId),
      );
    } catch (e) {
      AppLogger().error('Failed to check game name existence', e);
      return false;
    }
  }

  // Generate a unique game name
  Future<String> generateUniqueGameName(String baseName) async {
    String name = baseName;
    int counter = 1;

    while (await isGameNameExists(name)) {
      name = '$baseName ($counter)';
      counter++;
    }

    return name;
  }

  // Get game statistics
  Future<Map<String, int>> getGameStats() async {
    try {
      final savedGames = await loadSavedGames();

      int totalGames = savedGames.length;
      int redWins = savedGames.where((g) => g.winner == 'red').length;
      int blackWins = savedGames.where((g) => g.winner == 'black').length;
      int draws = savedGames.where((g) => g.winner == 'draw').length;
      int ongoing = savedGames.where((g) => g.winner == null).length;

      return {
        'total': totalGames,
        'redWins': redWins,
        'blackWins': blackWins,
        'draws': draws,
        'ongoing': ongoing,
      };
    } catch (e) {
      AppLogger().error('Failed to get game stats', e);
      return {
        'total': 0,
        'redWins': 0,
        'blackWins': 0,
        'draws': 0,
        'ongoing': 0,
      };
    }
  }
}
