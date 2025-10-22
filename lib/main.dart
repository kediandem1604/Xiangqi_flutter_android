import 'package:flutter/material.dart';
import 'pikafish_engine.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pikafish Engine Test',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PikafishEngine _engine = PikafishEngine();
  bool _engineInitialized = false;
  String _output = 'Engine output will appear here...';
  bool _isLoading = false;

  @override
  void dispose() {
    _engine.close();
    super.dispose();
  }

  void _updateOutput(String newOutput) {
    setState(() {
      _output = newOutput;
    });
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  Future<void> _initializeEngine() async {
    try {
      _setLoading(true);
      _updateOutput('Initializing Pikafish engine...\n');
      _updateOutput('Debug: Starting initialization process...\n');

      _updateOutput('Debug: About to call _engine.initialize()...\n');
      await _engine.initialize();
      _updateOutput('Debug: _engine.initialize() completed successfully\n');

      _engineInitialized = true;

      String result = 'Pikafish Engine initialized successfully!\n';
      result += 'Status: Ready for commands\n';
      _updateOutput(result);

      _showSnackBar('Engine initialized successfully');
    } catch (e) {
      _updateOutput('Engine initialization failed: $e\n');
      _updateOutput('Error type: ${e.runtimeType}\n');
      if (e is Exception) {
        _updateOutput('Exception details: ${e.toString()}\n');
      }
      _showSnackBar('Engine initialization failed');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _runTest() async {
    if (!_engineInitialized) {
      _showSnackBar('Please initialize engine first');
      return;
    }

    try {
      _setLoading(true);
      _updateOutput('Running comprehensive engine test...\n');

      String result = '=== Pikafish Engine Test ===\n\n';

      // Test 1: UCI command
      result += '1. UCI Test:\n';
      await _engine.sendCommand('uci');
      result += 'UCI command sent\n\n';

      // Test 2: Ready test
      result += '2. Ready Test:\n';
      await _engine.sendCommand('isready');
      result += 'IsReady command sent\n\n';

      // Test 3: Position test
      result += '3. Position Test:\n';
      await _engine.sendCommand('position startpos');
      result += 'Position set to starting position\n\n';

      // Test 4: Real search test
      result += '4. Real Search Test:\n';
      String bestMove = await _engine.getBestMove('startpos', 1);
      result += 'Search result: $bestMove\n\n';

      // Test 5: Deeper search
      result += '5. Deeper Search Test:\n';
      String deeperMove = await _engine.getBestMove('startpos', 3);
      result += 'Deeper search result: $deeperMove\n\n';

      result += '=== All tests completed successfully! ===\n';
      result += 'Engine is working and returning real best moves!';

      _updateOutput(result);
      _showSnackBar('Test completed successfully');
    } catch (e) {
      _updateOutput('Test failed: $e');
      _showSnackBar('Test failed');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _getBestMove() async {
    if (!_engineInitialized) {
      _showSnackBar('Please initialize engine first');
      return;
    }

    try {
      _setLoading(true);
      _updateOutput('Getting best move...\n');
      String bestMove = await _engine.getBestMove('startpos', 1);
      _updateOutput('Best move: $bestMove');
      _showSnackBar('Best move: $bestMove');
    } catch (e) {
      _updateOutput('Error getting best move: $e');
      _showSnackBar('Error getting best move');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _getTopMoves() async {
    if (!_engineInitialized) {
      _showSnackBar('Please initialize engine first');
      return;
    }

    try {
      _setLoading(true);
      _updateOutput('Getting top 3 moves...\n');
      String topMoves = await _engine.getTopMoves('startpos', 5, 3);

      String result = '=== Top 3 Moves Analysis ===\n\n';
      result += 'Position: Starting position\n';
      result += 'Depth: 5\n';
      result += 'MultiPV: 3\n\n';
      result += 'Analysis Results:\n';
      result += '$topMoves\n\n';
      result += '=== Analysis Complete ===';

      _updateOutput(result);
      _showSnackBar('Top 3 moves analysis completed');
    } catch (e) {
      _updateOutput('Error getting top moves: $e');
      _showSnackBar('Error getting top moves');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testPosition(String positionName, String fen) async {
    if (!_engineInitialized) {
      _showSnackBar('Please initialize engine first');
      return;
    }

    try {
      _setLoading(true);
      _updateOutput('Testing $positionName...\n');

      String result = '=== $positionName Analysis ===\n\n';
      result += 'FEN: $fen\n\n';

      // Get best move
      result += '1. Best Move Analysis:\n';
      String bestMove = await _engine.getBestMove(fen, 5);
      result += 'Best move: $bestMove\n\n';

      // Get top 3 moves
      result += '2. Top 3 Moves Analysis:\n';
      String topMoves = await _engine.getTopMoves(fen, 5, 3);
      result += '$topMoves\n\n';

      result += '=== Analysis Complete ===';

      _updateOutput(result);
      _showSnackBar('$positionName analysis completed');
    } catch (e) {
      _updateOutput('Error testing $positionName: $e');
      _showSnackBar('Error testing $positionName');
    } finally {
      _setLoading(false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          child: Text(text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pikafish Engine Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pikafish Engine Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _buildButton('Initialize Engine', _initializeEngine),
            _buildButton('Run Full Test', _runTest),
            _buildButton('Get Best Move', _getBestMove),
            _buildButton('Get Top 3 Moves', _getTopMoves),
            _buildButton(
              'Test Opening Position',
              () => _testPosition(
                'Opening Position',
                PikafishEngine.startingPosition,
              ),
            ),
            _buildButton(
              'Test Mid-game Position',
              () => _testPosition(
                'Mid-game Position',
                PikafishEngine.midgamePosition,
              ),
            ),
            _buildButton(
              'Test Endgame Position',
              () => _testPosition(
                'Endgame Position',
                PikafishEngine.endgamePosition,
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Engine Output:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _output,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
