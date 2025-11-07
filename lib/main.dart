import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pikafish_engine.dart';
import 'features/board/board_controller.dart';
import 'features/board/best_moves_panel.dart';
import 'features/board/board_view.dart';
import 'features/settings/engine_settings_dialog.dart';
import 'features/settings/settings_provider.dart';
import 'widgets/side_selection_dialog.dart';
import 'widgets/game_notification.dart';
import 'core/logger.dart';
import 'services/saved_games_service.dart';

// Provider for the initialized engine
final engineProvider = StateProvider<PikafishEngine?>((ref) => null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await AppLogger.ensureInitialized();

  runApp(const ProviderScope(child: XiangqiApp()));
}

class XiangqiApp extends StatelessWidget {
  const XiangqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xiangqi Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const XiangqiHomePage(),
    );
  }
}

class XiangqiHomePage extends ConsumerStatefulWidget {
  const XiangqiHomePage({super.key});

  @override
  ConsumerState<XiangqiHomePage> createState() => _XiangqiHomePageState();
}

class _XiangqiHomePageState extends ConsumerState<XiangqiHomePage> {
  final PikafishEngine _engine = PikafishEngine();
  bool _engineInitialized = false;
  String _output = 'Engine output will appear here...';
  bool _isLoading = false;
  String _currentGameMode = 'normal'; // Track current game mode
  bool _showBestMoves = true; // Show/hide best moves and arrows

  @override
  void initState() {
    super.initState();
    // Initialize board controller
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final boardController = ref.read(boardControllerProvider.notifier);
      await boardController.init();

      // Show side selection dialog
      _showSideSelectionAndInit();
    });
  }

  Future<void> _showSideSelectionAndInit() async {
    final side = await showSideSelectionDialog(context);
    if (side != null) {
      // Set board orientation based on side selection
      final controller = ref.read(boardControllerProvider.notifier);
      if (side == PlayerSide.black) {
        // If user selected Black, put Black at bottom (Red at top)
        await controller.setRedAtBottom(false);
      } else {
        // If user selected Red, put Red at bottom
        await controller.setRedAtBottom(true);
      }
      await _initializeEngine();
    }
  }

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

  Future<void> _runAutomaticAnalysis() async {
    try {
      _updateOutput('Running automatic analysis...\n');
      final boardCtrl = ref.read(boardControllerProvider.notifier);
      await boardCtrl.analyzeTopMoves(
        engine: _engine,
        fen: PikafishEngine.startingPosition,
        depth: 8,
      );
      _updateOutput('Analysis completed!\n');
    } catch (e) {
      _updateOutput('Analysis failed: $e\n');
    }
  }

  Future<void> _initializeEngine() async {
    try {
      _setLoading(true);
      _updateOutput('Initializing Pikafish engine...\n');
      _updateOutput('Debug: Starting initialization process...\n');

      _updateOutput('Debug: About to call _engine.initialize()...\n');
      await _engine.initialize();
      _updateOutput('Debug: _engine.initialize() completed successfully\n');

      // Lưu engine vào provider
      ref.read(engineProvider.notifier).state = _engine;

      // Set engine và settings cho BoardController
      final boardController = ref.read(boardControllerProvider.notifier);
      boardController.setEngine(_engine);
      // Sử dụng default settings
      boardController.setSettings(8, 1);

      String result = 'Pikafish Engine initialized successfully!\n';
      result += 'Status: Ready for commands\n';
      _updateOutput(result);

      _showSnackBar('Engine initialized successfully');

      // Tự động phân tích best moves sau khi khởi tạo engine
      await _runAutomaticAnalysis();

      // Chỉ hiển thị giao diện sau khi có kết quả phân tích
      _engineInitialized = true;
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xiangqi Engine'),
        backgroundColor: Colors.orange[200],
        actions: [
          // Auto-execute best move
          Consumer(
            builder: (context, ref, _) {
              final st = ref.watch(boardControllerProvider);
              final controller = ref.read(boardControllerProvider.notifier);
              return IconButton(
                icon: const Icon(Icons.bolt),
                onPressed: () async {
                  await controller.executeBestMove();
                },
                tooltip: 'Tự động đi nước cờ tốt nhất',
                color: st.bestLines.isNotEmpty ? Colors.blue : Colors.grey,
              );
            },
          ),
          // Toggle best moves visibility
          IconButton(
            icon: Icon(
              _showBestMoves ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _showBestMoves = !_showBestMoves;
              });
            },
            tooltip: _showBestMoves ? 'Ẩn Best Moves' : 'Hiện Best Moves',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Header với màu nâu đậm
              Container(
                width: double.infinity,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFF7A5C4D), // Màu nâu đậm như trong ảnh
                ),
                child: const Center(
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Menu items với màu nền nhạt và vạch kẻ
              Expanded(
                child: Container(
                  color: const Color(0xFFFDF7F2), // Màu nền nhạt như trong ảnh
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
                      // Nhóm 1: Chế độ chơi
                      _buildMenuItem(
                        icon: Icons.sports_esports,
                        title: 'Chế độ chơi bình thường',
                        isHighlighted: _currentGameMode == 'normal',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _currentGameMode = 'normal';
                          });
                          final boardController = ref.read(
                            boardControllerProvider.notifier,
                          );
                          boardController.stopVsEngineMode();
                          _showSnackBar('Chuyển sang chế độ chơi bình thường');
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.smart_toy,
                        title: 'Đánh với máy',
                        subtitle: 'Chọn cấp độ khó',
                        isHighlighted: _currentGameMode == 'vs_engine',
                        onTap: () {
                          Navigator.pop(context);
                          _showDifficultyDialog();
                        },
                      ),
                      _buildDivider(),

                      // Nhóm 2: Cài đặt
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: 'Cài đặt engine',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => const EngineSettingsDialog(),
                  );
                },
              ),
                      _buildMenuItem(
                        icon: Icons.grid_view,
                        title: 'Setup Board',
                        onTap: () {
                          Navigator.pop(context);
                          final boardController = ref.read(
                            boardControllerProvider.notifier,
                          );
                          boardController.enterSetupMode();
                        },
                      ),
                      _buildDivider(),

                      // Nhóm 3: Lưu trữ
                      _buildMenuItem(
                        icon: Icons.save_alt,
                        title: 'Lưu ván cờ',
                        onTap: () {
                          Navigator.pop(context);
                          _showSaveGameDialog();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.history,
                        title: 'Ván đã lưu',
                        onTap: () {
                          Navigator.pop(context);
                          _showSavedGamesDialog();
                        },
                      ),
                      _buildDivider(),

                      // Nhóm 4: Hệ thống
                      _buildMenuItem(
                        icon: Icons.bug_report,
                        title: 'Log lỗi',
                        onTap: () {
                          Navigator.pop(context);
                          _showLogsDialog();
                        },
                      ),
                      _buildDivider(),

                      // About
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: GameNotificationOverlay(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // Engine status
            if (_engineInitialized)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final boardState = ref.watch(boardControllerProvider);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Engine: Pikafish'),
                          if (boardState.isVsEngineMode)
                            Text(
                              'Mode: VS Engine (${boardState.vsEngineDifficulty})',
                            ),
                          if (boardState.isInCheck)
                            Text(
                              '⚠️ CHECK!',
                              style: TextStyle(color: Colors.red),
                            ),
                          if (boardState.isCheckmate)
                            Text(
                              '🏆 CHECKMATE!',
                              style: TextStyle(color: Colors.red),
                            ),
                          if (boardState.gameWinner != null)
                            Text(
                              'Winner: ${boardState.gameWinner}',
                              style: TextStyle(color: Colors.green),
                            ),
                        ],
                      );
                    },
                  ),
              ),
            const SizedBox(height: 16),

              // Board view
            if (_engineInitialized) ...[
              Consumer(
                builder: (context, ref, _) {
                  final st = ref.watch(boardControllerProvider);
                  return Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                        child: Stack(
                          children: [
                            BoardView(
                              arrows: _showBestMoves ? st.arrows : const [],
                              isLocked: st.boardLocked,
                            ),

                            // XÍCH PHỦ BÀN CỜ KHI BỊ KHÓA
                            if (st.boardLocked)
                              const Positioned.fill(
                                child: _LockChainsOverlay(),
                              ),
                          ],
                        ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

                // Move history and controls - only show when not in setup mode
              Consumer(
                builder: (context, ref, _) {
                  final st = ref.watch(boardControllerProvider);
                  final ctrl = ref.read(boardControllerProvider.notifier);

                    // Hide move history and controls when in setup mode
                    if (st.isSetupMode) {
                      return const SizedBox.shrink();
                    }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              'Move History: ${st.moves.take(st.pointer).join(' ')}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                              onPressed: st.canBack ? ctrl.back : null,
                            child: const Text('Back'),
                          ),
                          OutlinedButton(
                              onPressed: () async {
                                await ctrl.resetWithCallback(() {
                                  // Reset UI settings to default
                                  ref.read(multipvProvider.notifier).state = 1;
                                  ref
                                          .read(thinkTimeSecProvider.notifier)
                                          .state =
                                      10;
                                  ref.read(depthProvider.notifier).state = 8;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: st.boardLocked
                                    ? const Color(0xFFFFE082)
                                    : null,
                                side: st.boardLocked
                                    ? const BorderSide(
                                        color: Color(0xFFFFA000),
                                        width: 2,
                                      )
                                    : null,
                                foregroundColor: st.boardLocked
                                    ? Colors.brown[800]
                                    : null,
                                elevation: st.boardLocked ? 2 : 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (st.boardLocked) ...[
                                    const Icon(Icons.refresh),
                                    const SizedBox(width: 6),
                                  ],
                                  const Text('Reset'),
                                ],
                              ),
                          ),
                          OutlinedButton(
                              onPressed: st.canNext ? ctrl.next : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 16),

              // Best moves panel - only show when not in setup mode
              Consumer(
                builder: (context, ref, _) {
                  final st = ref.watch(boardControllerProvider);

                  // Hide best moves panel when in setup mode
                  if (st.isSetupMode) {
                    return const SizedBox.shrink();
                  }

                  if (_engineInitialized && _showBestMoves) {
                    return SizedBox(height: 220, child: BestMovesPanel());
                  }
                  return const SizedBox.shrink();
                },
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn cấp độ khó'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chọn cấp độ khó cho máy:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.star_border, color: Colors.green),
              title: const Text('Dễ'),
              subtitle: const Text(
                'Máy đi ngẫu nhiên, thỉnh thoảng theo bestmove thấp',
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentGameMode = 'vs_engine';
                });
                final boardController = ref.read(
                  boardControllerProvider.notifier,
                );
                boardController.startVsEngineMode('easy');
                _showSnackBar('Bắt đầu chế độ đánh với máy - Cấp độ: Dễ');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_half, color: Colors.orange),
              title: const Text('Trung bình'),
              subtitle: const Text('Máy đi theo bestmove có điểm thấp hơn'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentGameMode = 'vs_engine';
                });
                final boardController = ref.read(
                  boardControllerProvider.notifier,
                );
                boardController.startVsEngineMode('medium');
                _showSnackBar(
                  'Bắt đầu chế độ đánh với máy - Cấp độ: Trung bình',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.red),
              title: const Text('Khó'),
              subtitle: const Text('Máy đi theo bestmove tốt nhất'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentGameMode = 'vs_engine';
                });
                final boardController = ref.read(
                  boardControllerProvider.notifier,
                );
                boardController.startVsEngineMode('hard');
                _showSnackBar('Bắt đầu chế độ đánh với máy - Cấp độ: Khó');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showSaveGameDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lưu ván cờ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Tên ván cờ'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Mô tả (tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final boardController = ref.read(
                  boardControllerProvider.notifier,
                );
                final success = await boardController.saveCurrentGame(
                  nameController.text,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                );

                Navigator.pop(context);
                _showSnackBar(success ? 'Lưu thành công!' : 'Lưu thất bại!');
              }
            },
            child: Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showSavedGamesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ván đã lưu'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder(
            future: SavedGamesService.instance.loadSavedGames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('Chưa có ván cờ nào được lưu'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final game = snapshot.data![index];
                  return ListTile(
                    title: Text(game.name),
                    subtitle: Text(
                      '${game.totalMoves} nước đi - ${game.formattedDate}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () {
                        Navigator.pop(context);
                        final boardController = ref.read(
                          boardControllerProvider.notifier,
                        );
                        boardController.loadSavedGame(game.id);
                        _showSnackBar('Đã tải ván cờ: ${game.name}');
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log lỗi'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(child: Text(_output)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xiangqi Flutter'),
            Text('Version: 1.0.0'),
            Text('Engine: Pikafish'),
            Text('Protocol: UCI'),
            SizedBox(height: 16),
            Text(
              'Một ứng dụng cờ tướng được phát triển bằng Flutter với tích hợp engine AI mạnh mẽ.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Helper method để tạo menu item với màu sắc như trong ảnh
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isHighlighted
            ? const Color(0xFF7A5C4D) // Màu nâu đậm khi được highlight
            : const Color(0xFF9C6E5B), // Màu icon như trong ảnh
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isHighlighted
              ? const Color(0xFF7A5C4D) // Màu nâu đậm khi được highlight
              : const Color(0xFF9C6E5B), // Màu text chính như trong ảnh
          fontSize: 16,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isHighlighted
                    ? const Color(0xFF7A5C4D) // Màu nâu đậm khi được highlight
                    : const Color(0xFFB28B7A), // Màu subtitle như trong ảnh
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: isHighlighted
          ? const Color(0xFFF5F0ED) // Màu nền nhạt hơn khi được highlight
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isHighlighted
            ? const BorderSide(color: Color(0xFF7A5C4D), width: 1)
            : BorderSide.none,
      ),
    );
  }

  // Helper method để tạo divider với màu sắc như trong ảnh
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFE0E0E0), // Màu divider nhạt như trong ảnh
      indent: 16,
      endIndent: 16,
    );
  }
}

class _LockChainsOverlay extends StatefulWidget {
  const _LockChainsOverlay();

  @override
  State<_LockChainsOverlay> createState() => _LockChainsOverlayState();
}

class _LockChainsOverlayState extends State<_LockChainsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AbsorbPointer(
        // chặn tương tác
        child: Stack(
          children: [
            // Lớp mờ
            Container(color: Colors.black.withOpacity(0.25)),

            // Hai dây xích chéo + ổ khóa giữa
            Positioned.fill(child: CustomPaint(painter: _ChainsPainter())),

            // Ổ khóa to giữa
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, size: 56, color: Colors.white),
              ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChainsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Hai đường chéo như dây xích
    final path1 = Path()
      ..moveTo(-size.width * 0.1, size.height * 0.1)
      ..lineTo(size.width * 1.1, size.height * 0.9);

    final path2 = Path()
      ..moveTo(size.width * 1.1, size.height * 0.1)
      ..lineTo(-size.width * 0.1, size.height * 0.9);

    // Vẽ "mắt xích": các đoạn ngắn đứt quãng cho cảm giác xích
    _drawChain(canvas, path1, paint);
    _drawChain(canvas, path2, paint);
  }

  void _drawChain(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics().first;
    const linkLen = 32.0;
    const gap = 12.0;
    double dist = 0;

    bool flip = false;
    while (dist < metrics.length) {
      final seg = metrics.extractPath(
        dist,
        (dist + linkLen).clamp(0, metrics.length),
      );
      canvas.drawPath(seg, paint..strokeWidth = flip ? 9 : 10);
      dist += linkLen + gap;
      flip = !flip;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
