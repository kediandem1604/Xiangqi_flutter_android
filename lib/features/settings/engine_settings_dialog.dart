import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../board/board_controller.dart';
import '../../main.dart';

class EngineSettingsDialog extends ConsumerStatefulWidget {
  const EngineSettingsDialog({super.key});

  @override
  ConsumerState<EngineSettingsDialog> createState() =>
      _EngineSettingsDialogState();
}

class _EngineSettingsDialogState extends ConsumerState<EngineSettingsDialog> {
  late double _multiPv;
  late double _thinkSec;
  late double _depth;

  @override
  void initState() {
    super.initState();
    _multiPv = ref.read(multipvProvider).toDouble();
    _thinkSec = ref.read(thinkTimeSecProvider).toDouble();
    _depth = ref.read(depthProvider).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cài đặt Engine'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Số lượng bestmove: ${_multiPv.toInt()}'),
          Slider(
            value: _multiPv,
            min: 1,
            max: 3,
            divisions: 2,
            label: _multiPv.toInt().toString(),
            onChanged: (v) => setState(() => _multiPv = v),
          ),
          const SizedBox(height: 8),
          Text('Thời gian suy nghĩ: ${_thinkSec.toInt()}s'),
          Slider(
            value: _thinkSec,
            min: 1,
            max: 60,
            divisions: 59,
            label: _thinkSec.toInt().toString(),
            onChanged: (v) => setState(() => _thinkSec = v),
          ),
          const SizedBox(height: 8),
          Text('Độ sâu phân tích: ${_depth.toInt()}'),
          Slider(
            value: _depth,
            min: 1,
            max: 30,
            divisions: 29,
            label: _depth.toInt().toString(),
            onChanged: (v) => setState(() => _depth = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () async {
            ref.read(multipvProvider.notifier).state = _multiPv.toInt();
            ref.read(thinkTimeSecProvider.notifier).state = _thinkSec.toInt();
            ref.read(depthProvider.notifier).state = _depth.toInt();
            Navigator.pop(context);

            // Update BoardController settings
            final boardCtrl = ref.read(boardControllerProvider.notifier);
            boardCtrl.setSettings(_depth.toInt(), _multiPv.toInt());

            // Re-run analysis with new settings
            // Get the initialized engine from main.dart
            final engine = ref.read(engineProvider);
            if (engine != null) {
              // Get current board state
              final currentState = ref.read(boardControllerProvider);
              await boardCtrl.analyzeTopMoves(
                engine: engine,
                fen: boardCtrl.isFromStartpos() ? 'startpos' : currentState.setupFen!,
                depth: _depth.toInt(),
                numMoves: _multiPv.toInt(),
                moves: boardCtrl.currentMoves(),
              );
            }
          },
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}
