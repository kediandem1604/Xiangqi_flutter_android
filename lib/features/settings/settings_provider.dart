import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MultiPV setting (1-3)
final multipvProvider = StateProvider<int>((ref) => 1);

/// Think time (seconds)
final thinkTimeSecProvider = StateProvider<int>((ref) => 10);

/// Search depth
final depthProvider = StateProvider<int>((ref) => 8);
