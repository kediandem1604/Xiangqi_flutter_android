import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_controller.dart';
import '../../core/fen.dart';

// Hàm chung để tránh lệch map giữa quân tĩnh và animation
String? pieceAssetFromSymbol(String s) {
  switch (s) {
    case 'r':
      return 'assets/pieces/xiangqi/black_rook.svg';
    case 'h':
      return 'assets/pieces/xiangqi/black_knight.svg';
    case 'e':
      return 'assets/pieces/xiangqi/black_bishop.svg';
    case 'a':
      return 'assets/pieces/xiangqi/black_advisor.svg';
    case 'k':
      return 'assets/pieces/xiangqi/black_king.svg';
    case 'c':
      return 'assets/pieces/xiangqi/black_cannon.svg';
    case 'p':
      return 'assets/pieces/xiangqi/black_pawn.svg';
    case 'R':
      return 'assets/pieces/xiangqi/red_rook.svg';
    case 'H':
      return 'assets/pieces/xiangqi/red_knight.svg';
    case 'E':
      return 'assets/pieces/xiangqi/red_bishop.svg';
    case 'A':
      return 'assets/pieces/xiangqi/red_advisor.svg';
    case 'K':
      return 'assets/pieces/xiangqi/red_king.svg';
    case 'C':
      return 'assets/pieces/xiangqi/red_cannon.svg';
    case 'P':
      return 'assets/pieces/xiangqi/red_pawn.svg';
  }
  return null;
}

class BoardView extends ConsumerStatefulWidget {
  final List<ArrowData> arrows; // list of arrow from->to in board coordinates
  final bool showStartPosition;
  final bool isLocked; // khóa bàn cờ khi ván đã kết thúc

  const BoardView({
    super.key,
    this.arrows = const [],
    this.showStartPosition = true,
    this.isLocked = false,
  });

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView>
    with SingleTickerProviderStateMixin {
  static const _boardAsset = 'assets/boards/xiangqi_gmchess_wood.svg';

  bool _boardReady = false; // nền bàn cờ đã cache xong?
  bool _piecesReady = false; // quân cờ đã cache xong?

  // (tuỳ chọn) mượt hơn: opacity cho overlay (mũi tên, chấm…)
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80), // giảm từ 120ms
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Delay nhỏ để đảm bảo SVG được render trước
    Future.delayed(const Duration(milliseconds: 30), () {
      // giảm từ 50ms
      if (mounted) setState(() => _boardReady = true);
    });

    // Delay thêm để đảm bảo quân cờ được render trước mũi tên
    Future.delayed(const Duration(milliseconds: 60), () {
      // giảm từ 100ms
      if (mounted) {
        setState(() {
          _piecesReady = true;
          _fadeCtrl.forward(); // bắt đầu fade-in overlay khi quân xong
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boardControllerProvider);
    final controller = ref.read(boardControllerProvider.notifier);

    // Show setup mode UI if in setup mode
    if (state.isSetupMode) {
      return _buildSetupModeUI(state, controller);
    }

    return AspectRatio(
      aspectRatio: 9 / 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const boardAR = 9 / 10;
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final containerAR = w / h;

          late double renderW, renderH, originX, originY;
          if (containerAR > boardAR) {
            // dư ngang (pad trái/phải)
            renderH = h;
            renderW = h * boardAR;
            originX = (w - renderW) / 2;
            originY = 0;
          } else {
            // dư dọc (pad trên/dưới)
            renderW = w;
            renderH = w / boardAR;
            originX = 0;
            originY = (h - renderH) / 2;
          }

          final cellW = renderW / 9.0;
          final cellH = renderH / 10.0;

          return AbsorbPointer(
            absorbing: widget.isLocked,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown[800]!, width: 3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // NỀN: hiển thị khi _boardReady (nhiều máy vẫn hiện ngay vì cache nhanh)
                    if (_boardReady)
                      Positioned(
                        left: originX,
                        top: originY,
                        width: renderW,
                        height: renderH,
                        child: SvgPicture.asset(_boardAsset, fit: BoxFit.fill),
                      )
                    else
                      // placeholder mỏng, tránh blank frame
                      Positioned(
                        left: originX,
                        top: originY,
                        width: renderW,
                        height: renderH,
                        child: const SizedBox.shrink(),
                      ),
                    // MŨI TÊN: xuất hiện SAU quân + (tuỳ chọn) fade-in
                    if (_piecesReady &&
                        widget.arrows.isNotEmpty &&
                        !state.analyzing)
                      FadeTransition(
                        opacity: _fade,
                        child: CustomPaint(
                          painter: _ArrowPainter(
                            arrows: widget.arrows,
                            cellWidth: cellW,
                            cellHeight: cellH,
                            originX: originX,
                            originY: originY,
                            isRedAtBottom: state.isRedAtBottom,
                          ),
                          child: Container(),
                        ),
                      ),
                    // QUÂN CỜ: chỉ hiển thị khi _piecesReady
                    if (_piecesReady && widget.showStartPosition)
                      ..._buildPiecesFromFen(
                        cellW,
                        cellH,
                        state,
                        originX,
                        originY,
                      ),

                    // CHẤM GỢI Ý: sau khi quân sẵn sàng
                    if (_piecesReady)
                      ..._buildPossibleMoveIndicators(
                        state,
                        cellW,
                        cellH,
                        originX,
                        originY,
                      ),

                    // ANIMATION DI CHUYỂN QUÂN: cũng nên chờ _piecesReady
                    if (_piecesReady)
                      _buildMoveAnimation(
                        state,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        ref,
                        cellW,
                        cellH,
                        originX,
                        originY,
                      ),
                    // Gesture detector for piece interaction
                    GestureDetector(
                      onTapDown: (details) => _onBoardTap(
                        details.localPosition,
                        state,
                        controller,
                        cellW,
                        cellH,
                        originX,
                        originY,
                        renderW,
                        renderH,
                      ),
                      child: Container(color: Colors.transparent),
                    ),

                    // Overlay khóa bàn cờ
                    if (widget.isLocked)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.25),
                          child: const Center(child: _ChainLock()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onBoardTap(
    Offset local,
    BoardState state,
    BoardController controller,
    double cellW,
    double cellH,
    double originX,
    double originY,
    double renderW,
    double renderH,
  ) {
    // Trừ origin và clamp theo renderW/renderH
    final dx = (local.dx - originX).clamp(0.0, renderW - 0.01);
    final dy = (local.dy - originY).clamp(0.0, renderH - 0.01);

    final file = (dx / cellW).floor().clamp(0, 8);
    final displayRank = (dy / cellH).floor().clamp(0, 9);

    // Convert display rank to actual rank based on isRedAtBottom
    final rank = state.isRedAtBottom
        ? displayRank // Red at bottom: display rank = actual rank
        : 9 - displayRank; // Black at bottom: flip the rank

    debugPrint('Board tapped at file: $file, rank: $rank');
    controller.onBoardTap(file, rank);
  }

  // Build possible move indicators (small dots)
  List<Widget> _buildPossibleMoveIndicators(
    BoardState state,
    double cellW,
    double cellH,
    double originX,
    double originY,
  ) {
    final indicatorSize = (cellW * 0.3).clamp(10.0, 20.0);

    return state.possibleMoves.map((move) {
      // Calculate display position based on isRedAtBottom
      final displayX = move.dx;
      final displayY = state.isRedAtBottom ? move.dy : 9 - move.dy;

      return Positioned(
        left: originX + displayX * cellW + (cellW - indicatorSize) / 2,
        top: originY + displayY * cellH + (cellH - indicatorSize) / 2,
        child: Container(
          width: indicatorSize,
          height: indicatorSize,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
  }

  // Build move animation
  Widget _buildMoveAnimation(
    BoardState state,
    Size boardSize,
    WidgetRef ref,
    double cellW,
    double cellH,
    double originX,
    double originY,
  ) {
    final anim = state.pendingAnimation;
    if (anim == null) return const SizedBox.shrink();

    final pieceSize = (cellW * 0.8).clamp(30.0, 60.0);

    // Calculate display positions based on isRedAtBottom
    final fromDisplayRank = state.isRedAtBottom
        ? anim.fromRank
        : 9 - anim.fromRank;
    final toDisplayRank = state.isRedAtBottom ? anim.toRank : 9 - anim.toRank;

    final start = Offset(
      originX + anim.fromFile * cellW + (cellW - pieceSize) / 2,
      originY + fromDisplayRank * cellH + (cellH - pieceSize) / 2,
    );
    final end = Offset(
      originX + anim.toFile * cellW + (cellW - pieceSize) / 2,
      originY + toDisplayRank * cellH + (cellH - pieceSize) / 2,
    );

    return _AnimatedPiece(
      key: ValueKey('anim-${anim.moveUci}-${state.pointer}'),
      asset: _getPieceAsset(anim.piece),
      size: pieceSize,
      start: start,
      end: end,
      onCompleted: () {
        // Animation completed callback
        final controller = ref.read(boardControllerProvider.notifier);
        final state = ref.read(boardControllerProvider);

        if (state.pendingAnimation?.isEngineMove == true) {
          controller.commitEngineAnimatedMove();
        } else {
          controller.commitAnimatedMove();
        }
      },
    );
  }

  // Get piece asset path - dùng chung cho cả quân tĩnh và animation
  String? _getPieceAsset(String piece) {
    return pieceAssetFromSymbol(piece);
  }
}

class _AnimatedPiece extends StatefulWidget {
  final String? asset;
  final double size;
  final Offset start;
  final Offset end;
  final VoidCallback onCompleted;

  const _AnimatedPiece({
    super.key,
    required this.asset,
    required this.size,
    required this.start,
    required this.end,
    required this.onCompleted,
  });

  @override
  State<_AnimatedPiece> createState() => _AnimatedPieceState();
}

class _AnimatedPieceState extends State<_AnimatedPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _position = Tween<Offset>(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pos = _position.value;
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Opacity(
              opacity: _opacity.value,
              child: SvgPicture.asset(
                widget.asset!,
                key: ValueKey(
                  'anim-svg-${widget.asset}-${widget.start}-${widget.end}',
                ),
                width: widget.size,
                height: widget.size,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final List<ArrowData> arrows;
  final double cellWidth;
  final double cellHeight;
  final double originX;
  final double originY;
  final bool isRedAtBottom;

  const _ArrowPainter({
    required this.arrows,
    required this.cellWidth,
    required this.cellHeight,
    required this.originX,
    required this.originY,
    required this.isRedAtBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw arrows with colors based on score
    for (int i = 0; i < arrows.length; i++) {
      final arrowData = arrows[i];
      final paint = Paint()
        ..color = _getArrowColor(arrowData.scoreCp)
        ..strokeWidth = _getArrowWidth(arrowData.scoreCp)
        ..style = PaintingStyle.stroke;

      // Tính opacity dựa trên thứ tự nước đi (arrowIndex)
      final opacity = _getArrowOpacity(arrowData.scoreCp, i);
      paint.color = paint.color.withOpacity(opacity);

      // Convert board coordinates to pixel coordinates (center of cells)
      // Calculate display positions based on isRedAtBottom
      final fromDisplayY = isRedAtBottom
          ? arrowData.from.dy
          : 9 - arrowData.from.dy;
      final toDisplayY = isRedAtBottom ? arrowData.to.dy : 9 - arrowData.to.dy;

      final start = Offset(
        originX + arrowData.from.dx * cellWidth + cellWidth / 2,
        originY + fromDisplayY * cellHeight + cellHeight / 2,
      );
      final end = Offset(
        originX + arrowData.to.dx * cellWidth + cellWidth / 2,
        originY + toDisplayY * cellHeight + cellHeight / 2,
      );

      canvas.drawLine(start, end, paint);

      // Draw arrowhead
      final angle = (end - start).direction;
      final arrowLength = 15.0;
      final arrowAngle = 0.5;

      final arrowHead1 = Offset(
        end.dx - arrowLength * cos(angle - arrowAngle),
        end.dy - arrowLength * sin(angle - arrowAngle),
      );
      final arrowHead2 = Offset(
        end.dx - arrowLength * cos(angle + arrowAngle),
        end.dy - arrowLength * sin(angle + arrowAngle),
      );

      canvas.drawLine(end, arrowHead1, paint);
      canvas.drawLine(end, arrowHead2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.originX != originX ||
        oldDelegate.originY != originY ||
        oldDelegate.isRedAtBottom != isRedAtBottom;
  }

  Color _getArrowColor(int scoreCp) {
    // Tất cả mũi tên đều cùng màu xanh dương
    return Colors.blueAccent;
  }

  double _getArrowOpacity(int scoreCp, int arrowIndex) {
    // Chỉ áp dụng độ nhạt cho 2-3 nước đi tốt nhất
    // Nước đi đầu tiên (tốt nhất) = đậm nhất
    // Nước đi thứ 2, 3 = nhạt dần rõ ràng hơn
    if (arrowIndex == 0) return 1.0; // Nước đi tốt nhất - không trong suốt
    if (arrowIndex == 1) return 0.5; // Nước đi thứ 2 - khá trong suốt
    if (arrowIndex == 2) return 0.3; // Nước đi thứ 3 - rất trong suốt
    return 0.1; // Các nước đi khác - gần như trong suốt hoàn toàn
  }

  double _getArrowWidth(int scoreCp) {
    // Độ dày cố định cho tất cả mũi tên
    return 3.0;
  }
}

// Build pieces from FEN with proper board orientation
List<Widget> _buildPiecesFromFen(
  double cellW,
  double cellH,
  BoardState state,
  double originX,
  double originY,
) {
  final board = FenParser.parseBoard(state.fen);
  final widgets = <Widget>[];

  for (int rank = 0; rank < 10; rank++) {
    for (int file = 0; file < 9; file++) {
      final piece = board[rank][file];
      if (piece.isNotEmpty) {
        // During animation, hide the piece at source and any captured piece at destination
        if (state.pendingAnimation != null) {
          if ((file == state.pendingAnimation!.fromFile &&
                  rank == state.pendingAnimation!.fromRank) ||
              (file == state.pendingAnimation!.toFile &&
                  rank == state.pendingAnimation!.toRank)) {
            continue;
          }
        }

        // Calculate display position based on isRedAtBottom
        final displayRank = state.isRedAtBottom ? rank : 9 - rank;
        final displayFile = file;

        final isSelected =
            state.selectedFile == file && state.selectedRank == rank;
        final pieceSize = (cellW * 0.8).clamp(30.0, 60.0);

        // Get piece asset using common function
        final pieceAsset = pieceAssetFromSymbol(piece);

        if (pieceAsset != null) {
          widgets.add(
            Positioned(
              key: ValueKey('piece-$file-$rank-$piece-${state.pointer}'),
              left: originX + displayFile * cellW + (cellW - pieceSize) / 2,
              top: originY + displayRank * cellH + (cellH - pieceSize) / 2,
              child: RepaintBoundary(
                // tránh "ghosting" 1 frame
                child: Container(
                  width: pieceSize,
                  height: pieceSize,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: Colors.yellow.withOpacity(0.5),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Center(
                    child: SvgPicture.asset(
                      pieceAsset,
                      key: ValueKey('svg-$file-$rank-$piece-${state.pointer}'),
                      width: pieceSize * 0.9,
                      height: pieceSize * 0.9,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
  }

  return widgets;
}

// Setup mode UI
Widget _buildSetupModeUI(BoardState state, BoardController controller) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPad = 12.0; // trùng với padding của ScrollView
      final usableW = constraints.maxWidth - horizontalPad * 2;
      final boardH = usableW * 10 / 9;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header controls - chỉ có Start Game và Exit Setup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: controller.startGameFromSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[800],
                    ),
                    child: const Text('Start Game'),
                  ),
                  ElevatedButton(
                    onPressed: controller.exitSetupMode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[800],
                    ),
                    child: const Text('Exit Setup'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hàng TRÊN: nếu red ở dưới thì trên là đen; nếu black ở dưới thì trên là đỏ
            SizedBox(
              height: 100,
              child: _buildSetupPiecesRow(
                state,
                controller,
                !state.isRedAtBottom, // isRed cho hàng TRÊN
              ),
            ),

            const SizedBox(height: 16),

            // Board: luôn đúng theo usableW, canh giữa
            Align(
              alignment: Alignment.center,
              child: _SetupBoard(
                state: state,
                controller: controller,
                size: Size(usableW, boardH),
                isRedAtBottom: state.isRedAtBottom,
              ),
            ),

            const SizedBox(height: 16),

            // Hàng DƯỚI: bên đang ở dưới bàn
            SizedBox(
              height: 100,
              child: _buildSetupPiecesRow(
                state,
                controller,
                state.isRedAtBottom, // isRed cho hàng DƯỚI
              ),
            ),

            const SizedBox(height: 16),

            // Controls: Back, Reset, Next
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: controller.canUndoSetupMove()
                        ? controller.undoSetupMove
                        : null,
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: controller.resetSetupBoard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[800],
                    ),
                    child: const Text('Reset'),
                  ),
                  ElevatedButton(
                    onPressed: controller.canRedoSetupMove()
                        ? controller.redoSetupMove
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildSetupPiecesRow(
  BoardState state,
  BoardController controller,
  bool isRed,
) {
  final pieces = isRed
      ? ['R', 'H', 'E', 'A', 'K', 'C', 'P']
      : ['r', 'h', 'e', 'a', 'k', 'c', 'p'];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: pieces.map((piece) {
        final count = state.setupPieces[piece] ?? 0;
        final isSelected = state.selectedSetupPiece == piece;
        final canSelect = count > 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Draggable<String>(
            data: piece,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () {
              print('Draggable onDragStarted: $piece');
            },
            onDragEnd: (details) {
              print(
                'Draggable onDragEnd: $piece, wasAccepted: ${details.wasAccepted}',
              );
            },
            feedback: _pieceFeedback(piece),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _pieceTile(piece, isSelected, count, canSelect),
            ),
            child: GestureDetector(
              onTap: canSelect
                  ? () => controller.selectSetupPiece(piece)
                  : null,
              child: _pieceTile(piece, isSelected, count, canSelect),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Widget _pieceTile(String piece, bool isSelected, int count, bool canSelect) {
  return Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: isSelected ? Colors.yellow.withOpacity(0.5) : Colors.grey[200],
      border: Border.all(
        color: isSelected ? Colors.orange : Colors.grey,
        width: isSelected ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Stack(
      children: [
        Center(
          child: SvgPicture.asset(
            pieceAssetFromSymbol(piece)!,
            width: 35,
            height: 35,
          ),
        ),
        if (count > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _pieceFeedback(String piece) {
  const box = 46.0; // đúng với SizedBox(46)
  return Material(
    type: MaterialType.transparency,
    child: Transform.translate(
      offset: const Offset(-box / 2, -box / 2), // 👈 kéo tâm về đúng con trỏ
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: SvgPicture.asset(
            pieceAssetFromSymbol(piece)!,
            width: 42,
            height: 42,
          ),
        ),
      ),
    ),
  );
}

class _SetupBoard extends StatelessWidget {
  final BoardState state;
  final BoardController controller;
  final Size size;
  final bool isRedAtBottom;

  _SetupBoard({
    required this.state,
    required this.controller,
    required this.size,
    required this.isRedAtBottom,
  });

  final GlobalKey _boardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        key: _boardKey,
        children: [
          // nền SVG phủ kín
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/boards/xiangqi_gmchess_wood.svg',
              fit: BoxFit.fill,
            ),
          ),
          // overlay (quân + drag target + tap)
          _buildSetupBoardOverlay(
            state,
            controller,
            size,
            _boardKey,
            isRedAtBottom,
          ),
        ],
      ),
    );
  }
}

Widget _buildSetupBoardOverlay(
  BoardState state,
  BoardController controller,
  Size boardSize,
  GlobalKey boardKey,
  bool isRedAtBottom,
) {
  final board = FenParser.parseBoard(state.fen);
  final cellW = boardSize.width / 9;
  final cellH = boardSize.height / 10;
  final pieceSize = (cellW < cellH ? cellW : cellH) * 0.8;

  return Stack(
    children: [
      // 1) Vẽ quân đang có (dưới)
      for (int r = 0; r < 10; r++)
        for (int f = 0; f < 9; f++)
          if (board[r][f].isNotEmpty)
            Positioned(
              left: f * cellW + (cellW - pieceSize) / 2,
              top:
                  (isRedAtBottom ? r : 9 - r) * cellH + (cellH - pieceSize) / 2,
              // ✨ Cho quân trên bàn cũng có thể kéo lại
              child: Draggable<String>(
                data: board[r][f],
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  type: MaterialType.transparency,
                  child: Transform.translate(
                    offset: Offset(
                      -(pieceSize * 1.2) / 2,
                      -(pieceSize * 1.2) / 2,
                    ), // 👈
                    child: SizedBox(
                      width: pieceSize * 1.2,
                      height: pieceSize * 1.2,
                      child: Center(
                        child: SvgPicture.asset(
                          pieceAssetFromSymbol(board[r][f])!,
                          width: pieceSize * 1.2,
                          height: pieceSize * 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.35,
                  child: SizedBox(
                    width: pieceSize,
                    height: pieceSize,
                    child: SvgPicture.asset(
                      pieceAssetFromSymbol(board[r][f])!,
                      width: pieceSize * 0.9,
                      height: pieceSize * 0.9,
                    ),
                  ),
                ),
                child: GestureDetector(
                  onTap: () => controller.removePieceFromBoard(f, r),
                  child: SizedBox(
                    width: pieceSize,
                    height: pieceSize,
                    child: Center(
                      child: SvgPicture.asset(
                        pieceAssetFromSymbol(board[r][f])!,
                        width: pieceSize * 0.9,
                        height: pieceSize * 0.9,
                      ),
                    ),
                  ),
                ),
              ),
            ),

      // 2) Tap để đặt nhanh (giữ nguyên)
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final dx = d.localPosition.dx.clamp(0.0, boardSize.width - 0.01);
            final dy = d.localPosition.dy.clamp(0.0, boardSize.height - 0.01);
            final displayFile = (dx / cellW).floor().clamp(0, 8);
            final displayRank = (dy / cellH).floor().clamp(0, 9);
            final file = displayFile;
            final rank = isRedAtBottom ? displayRank : 9 - displayRank;
            if (state.selectedSetupPiece != null) {
              // Nếu có quân ở ô đích thì xoá trước
              final bd = FenParser.parseBoard(state.fen);
              if (bd[rank][file].isNotEmpty) {
                controller.removePieceFromBoard(file, rank);
              }
              controller.placePieceOnBoard(file, rank);
            }
          },
        ),
      ),

      // 3) ✨ DragTarget đặt CUỐI CÙNG (trên cùng) - chỉ nhận drag, không nhận tap
      Positioned.fill(
        child: DragTarget<String>(
          hitTestBehavior:
              HitTestBehavior.translucent, // Thay đổi để không che tap
          builder: (_, __, ___) => const SizedBox.expand(),
          onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
          onAcceptWithDetails: (details) {
            final box =
                boardKey.currentContext!.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.offset);

            // Bảo vệ
            if (cellW <= 0 || cellH <= 0) return;

            final dx = local.dx.clamp(0.0, boardSize.width - 0.01);
            final dy = local.dy.clamp(0.0, boardSize.height - 0.01);
            final displayFile = (dx / cellW).floor().clamp(0, 8);
            final displayRank = (dy / cellH).floor().clamp(0, 9);
            final file = displayFile;
            final rank = isRedAtBottom ? displayRank : 9 - displayRank;

            // Nếu có quân ở ô đích thì xoá trước
            final bd = FenParser.parseBoard(state.fen);
            if (bd[rank][file].isNotEmpty) {
              controller.removePieceFromBoard(file, rank);
            }

            controller.selectSetupPiece(details.data);
            controller.placePieceOnBoard(file, rank);
          },
        ),
      ),
    ],
  );
}

/// Widget hiển thị icon xích khóa bàn cờ
class _ChainLock extends StatelessWidget {
  const _ChainLock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.link, size: 56, color: Colors.white),
        Icon(Icons.lock, size: 64, color: Colors.white),
        SizedBox(height: 8),
        Text(
          'Bàn cờ đã khóa',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}
