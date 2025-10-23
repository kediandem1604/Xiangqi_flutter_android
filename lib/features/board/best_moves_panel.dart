import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_controller.dart';

class BestMovesPanel extends ConsumerWidget {
  const BestMovesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Moves',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (state.error != null) ...[
            Text(state.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          if (state.analyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading engine...'),
                  ],
                ),
              ),
            )
          else if (state.bestLines.isEmpty)
            const Text('No analysis available')
          else
            // Hiển thị số panel theo MultiPV được cài đặt
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.bestLines.length,
                itemBuilder: (context, index) {
                  final line = state.bestLines[index];
                  return _buildBestLineCard(line);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBestLineCard(BestLine line) {
    // Tính độ trong suốt dựa trên điểm số
    double opacity = _getScoreOpacity(line.scoreCp);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withOpacity(opacity), // Áp dụng độ trong suốt
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PV ${line.index}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black.withOpacity(
                      opacity,
                    ), // Áp dụng độ trong suốt cho text
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(line.scoreCp),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    line.scoreString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Depth: ${line.depth}',
              style: TextStyle(color: Colors.black.withOpacity(opacity)),
            ),
            const SizedBox(height: 4),
            Text(
              'Moves: ${line.pv.join(' ')}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black.withOpacity(opacity),
              ),
            ),
            if (line.firstMove.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'First move: ',
                    style: TextStyle(color: Colors.black.withOpacity(opacity)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100]?.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      line.firstMove,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int scoreCp) {
    // Màu sắc dựa trên điểm số với độ nhạt khác nhau
    if (scoreCp > 200) return Colors.green[800]!; // Rất tốt - đậm
    if (scoreCp > 100) return Colors.green[600]!; // Tốt - vừa
    if (scoreCp > 50) return Colors.green[400]!; // Khá tốt - nhạt
    if (scoreCp > 0) return Colors.green[300]!; // Hơi tốt - rất nhạt
    if (scoreCp > -50) return Colors.orange[300]!; // Cân bằng - nhạt
    if (scoreCp > -100) return Colors.orange[500]!; // Hơi xấu - vừa
    if (scoreCp > -200) return Colors.red[400]!; // Xấu - nhạt
    return Colors.red[600]!; // Rất xấu - đậm
  }

  double _getScoreOpacity(int scoreCp) {
    // Tính độ trong suốt dựa trên điểm số (điểm cao = đậm hơn)
    if (scoreCp > 200) return 1.0; // Rất tốt - không trong suốt
    if (scoreCp > 100) return 0.9; // Tốt - hơi trong suốt
    if (scoreCp > 50) return 0.8; // Khá tốt - trong suốt vừa
    if (scoreCp > 0) return 0.7; // Hơi tốt - khá trong suốt
    if (scoreCp > -50) return 0.6; // Cân bằng - trong suốt nhiều
    if (scoreCp > -100) return 0.5; // Hơi xấu - rất trong suốt
    if (scoreCp > -200) return 0.4; // Xấu - cực kỳ trong suốt
    return 0.3; // Rất xấu - gần như trong suốt hoàn toàn
  }
}
